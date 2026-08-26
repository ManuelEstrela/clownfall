extends Node

# ====== SETTINGS DATA ======
# These are the actual values that control the game

# Audio Settings
var master_volume: float = 1.0  # 0.0 to 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var mute_when_tabbed: bool = false

# Visual Settings
var screen_mode: int = 0  # 0 = Windowed, 1 = Fullscreen, 2 = Borderless
var vsync_enabled: bool = true
var fps_cap: int = 60  # 30, 60, 120, or 0 (unlimited)
var colorblind_mode: int = 0  # 0 = None, 1 = Protanopia, 2 = Deuteranopia, 3 = Tritanopia

# Gameplay Settings
var drop_assist_enabled: bool = false
var drop_key: int = KEY_SPACE  # Default: Space
var powerup_key_1: int = KEY_Q  # Default: Q
var powerup_key_2: int = KEY_W  # Default: W
var powerup_key_3: int = KEY_E  # Default: E

# Statistics (read-only, tracked by game)
var best_score: int = 0
var total_runs: int = 0
var total_clowns_dropped: int = 0
var highest_tier_created: int = 0  # 0-10 (Tessa to Kirk)
# Lifetime playtime, in seconds. Only the COMPLETED sessions are stored —
# the one currently running is added on top by get_time_played_seconds()
# below. Keeping them apart means the running session can be folded in
# repeatedly without ever double-counting.
var time_played_seconds: float = 0.0
# When this session started, on the monotonic clock. Time.get_ticks_msec()
# is used rather than wall time so changing the system clock, or crossing a
# daylight-saving boundary, can't corrupt the total.
var _session_start_msec: int = 0

# ====== THEMES & STARS ======
# Stars are NOT stored as an earned total — they're derived from the
# collection counters (see get_total_stars_earned). That means the earned
# figure can only ever go up, so spending has to be tracked separately and
# subtracted. Deriving rather than storing also means the two screens can
# never disagree about how many you've earned.
var stars_spent: int = 0

const THEME_IDS := ["purple", "blue", "pink", "red", "yellow", "green"]
const DEFAULT_THEME := "purple"

var unlocked_themes: Array = [DEFAULT_THEME]
var current_theme: String = DEFAULT_THEME

# Audio buses
var master_bus: int = AudioServer.get_bus_index("Master")
var music_bus: int = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else 0
var sfx_bus: int = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else 0

# Colorblind overlay
var colorblind_overlay: ColorRect = null

# Signals for when settings change
signal settings_changed
signal audio_changed
signal visual_changed

# Without this, a session ends without ever being written and the whole
# playtime is lost unless the player happened to open the statistics tab.
# NOTIFICATION_WM_CLOSE_REQUEST covers the window's X; NOTIFICATION_PREDELETE
# covers the autoload being torn down on a normal quit.
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		commit_time_played()

func _ready():
	setup_custom_cursor()
	load_settings()
	apply_all_settings()
	# load_settings() has just restored the stored total, so the session
	# clock starts from here.
	_session_start_msec = Time.get_ticks_msec()


func setup_custom_cursor():
	var default_cursor = load("res://assets/images/cursor/cursor_default.png")
	var hover_cursor = load("res://assets/images/cursor/cursor_hover.png")
	
	if default_cursor:
		var img = default_cursor.get_image()
		img.resize(56, 56, Image.INTERPOLATE_LANCZOS)
		var scaled = ImageTexture.create_from_image(img)
		Input.set_custom_mouse_cursor(scaled, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(scaled, Input.CURSOR_IBEAM)
	
	if hover_cursor:
		var img = hover_cursor.get_image()
		img.resize(56, 56, Image.INTERPOLATE_LANCZOS)
		var scaled = ImageTexture.create_from_image(img)
		Input.set_custom_mouse_cursor(scaled, Input.CURSOR_POINTING_HAND)

static func set_hover_cursor(control: Control):
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# ====== APPLY SETTINGS ======

func apply_all_settings():
	apply_audio_settings()
	apply_visual_settings()
	settings_changed.emit()

func apply_audio_settings():
	# Convert 0.0-1.0 to decibels (-80 to 0)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	if music_bus > 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	if sfx_bus > 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
	
	audio_changed.emit()

func apply_visual_settings():
	# Screen mode - FIXED!
	match screen_mode:
		0:  # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			print("✅ Screen mode: Windowed")
		1:  # Fullscreen (exclusive fullscreen - fastest)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			print("✅ Screen mode: Fullscreen")
		2:  # Borderless (fullscreen window - easier alt-tab)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			print("✅ Screen mode: Borderless")
	
	# VSync
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		print("✅ VSync: ENABLED (smoother, locks to monitor refresh rate)")
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("✅ VSync: DISABLED (may tear, unlimited FPS)")
	
	# FPS Cap
	if fps_cap == 0:
		Engine.max_fps = 0  # Unlimited
		print("✅ FPS Cap: UNLIMITED")
	else:
		Engine.max_fps = fps_cap
		print("✅ FPS Cap:", fps_cap)
	
	# Apply colorblind filter
	apply_colorblind_filter()
	
	visual_changed.emit()

func apply_colorblind_filter():
	# Remove old overlay if it exists
	if colorblind_overlay:
		colorblind_overlay.queue_free()
		colorblind_overlay = null
	
	if colorblind_mode == 0:
		# No colorblind mode
		print("✅ Colorblind mode: NONE (normal colors)")
		return
	
	# Create a fullscreen ColorRect with a shader
	var root = get_tree().root
	
	colorblind_overlay = ColorRect.new()
	colorblind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse
	colorblind_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	colorblind_overlay.color = Color(1, 1, 1, 0)  # TRANSPARENT - shader will handle the colors
	
	# Create shader
	var shader_code = """
shader_type canvas_item;

uniform int colorblind_type = 0; // 0=None, 1=Protanopia, 2=Deuteranopia, 3=Tritanopia

void fragment() {
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	if (colorblind_type == 1) {
		// Protanopia (red-blind) - confusion between red/green
		float r = 0.56667 * color.r + 0.43333 * color.g;
		float g = 0.55833 * color.r + 0.44167 * color.g;
		float b = 0.24167 * color.g + 0.75833 * color.b;
		color = vec4(r, g, b, color.a);
	}
	else if (colorblind_type == 2) {
		// Deuteranopia (green-blind) - confusion between red/green
		float r = 0.625 * color.r + 0.375 * color.g;
		float g = 0.7 * color.r + 0.3 * color.g;
		float b = 0.3 * color.g + 0.7 * color.b;
		color = vec4(r, g, b, color.a);
	}
	else if (colorblind_type == 3) {
		// Tritanopia (blue-blind) - confusion between blue/green
		float r = 0.95 * color.r + 0.05 * color.g;
		float g = 0.43333 * color.g + 0.56667 * color.b;
		float b = 0.475 * color.g + 0.525 * color.b;
		color = vec4(r, g, b, color.a);
	}
	
	COLOR = color;
}
"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("colorblind_type", colorblind_mode)
	
	colorblind_overlay.material = material
	
	# Add to root as top-level node
	root.add_child(colorblind_overlay)
	colorblind_overlay.set_owner(root)
	
	# Make sure it's on top
	root.move_child(colorblind_overlay, root.get_child_count() - 1)
	
	match colorblind_mode:
		1: print("✅ Colorblind mode: PROTANOPIA (red-blind)")
		2: print("✅ Colorblind mode: DEUTERANOPIA (green-blind)")
		3: print("✅ Colorblind mode: TRITANOPIA (blue-blind)")

# ====== SETTERS ======

func set_master_volume(value: float):
	master_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()

func set_music_volume(value: float):
	music_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()

func set_sfx_volume(value: float):
	sfx_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()

func set_mute_when_tabbed(value: bool):
	mute_when_tabbed = value

func set_screen_mode(mode: int):
	screen_mode = clamp(mode, 0, 2)
	apply_visual_settings()

func set_vsync(enabled: bool):
	vsync_enabled = enabled
	apply_visual_settings()

func set_fps_cap(cap: int):
	fps_cap = cap
	apply_visual_settings()

func set_colorblind_mode(mode: int):
	colorblind_mode = clamp(mode, 0, 3)
	apply_colorblind_filter()

func set_drop_assist(enabled: bool):
	drop_assist_enabled = enabled

func set_drop_key(key: int):
	drop_key = key

func set_powerup_key(slot: int, key: int):
	match slot:
		1: powerup_key_1 = key
		2: powerup_key_2 = key
		3: powerup_key_3 = key

# ====== STATISTICS ======

func update_best_score(score: int):
	if score > best_score:
		best_score = score
		save_settings()

func increment_total_runs():
	total_runs += 1
	save_settings()

func add_clowns_dropped(count: int):
	total_clowns_dropped += count
	save_settings()

func update_highest_tier(tier: int):
	if tier > highest_tier_created:
		highest_tier_created = tier
		save_settings()

# Currency earned == every star the collection has ever awarded.
#
# This is DERIVED from the collection counters rather than accumulated into
# total_currency_earned, for the same reason get_total_stars_earned() is:
# an accumulator is a second source of truth that can drift from what the
# collection screen shows, and nothing ever incremented this one anyway.
func get_total_currency_earned() -> int:
	return get_total_stars_earned()

# Kept so any existing caller still compiles. The figure is derived now, so
# this no longer needs to do anything.
func add_currency(_amount: int):
	pass

func add_time_played(seconds: float):
	time_played_seconds += seconds
	save_settings()

# Seconds elapsed in the session currently running.
func get_session_seconds() -> float:
	return float(Time.get_ticks_msec() - _session_start_msec) / 1000.0

# Lifetime total, including the session in progress. This is what the
# statistics screen should read — time_played_seconds on its own is always
# one session behind.
func get_time_played_seconds() -> float:
	return time_played_seconds + get_session_seconds()

# Folds the running session into the stored total and restarts the session
# clock. Called when the settings screen opens, so the number on display is
# current, and on quit so the session isn't lost.
func commit_time_played():
	var elapsed = get_session_seconds()
	if elapsed <= 0.0:
		return
	time_played_seconds += elapsed
	_session_start_msec = Time.get_ticks_msec()
	save_settings()
	save_settings()

# ── Per-clown merge tracking ───────────────────────────────────
# merges_per_clown[i] = how many times clown type i has been created via merge
var merges_per_clown: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
# drops_per_clown[i] = how many times clown type i has been dropped from the van.
# Used for the smallest clown (Tessa), who can never be produced by a merge and
# would otherwise always show 0 progress on the collection screen.
var drops_per_clown: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

func add_clown_merge(clown_type: int):
	if clown_type >= 0 and clown_type < merges_per_clown.size():
		merges_per_clown[clown_type] += 1
		save_settings()

func add_clown_drop(clown_type: int):
	if clown_type >= 0 and clown_type < drops_per_clown.size():
		drops_per_clown[clown_type] += 1
		save_settings()

# ====== STARS ======
#
# Earned stars are computed from the collection counters rather than stored,
# so this can never drift out of sync with what the collection screen shows.
# Tessa is counted by DROPS (she can't be produced by a merge); everyone else
# by merges — same rule the collection screen uses.
func get_total_stars_earned() -> int:
	var total := 0
	for i in range(merges_per_clown.size()):
		var count = drops_per_clown[i] if i == 0 else merges_per_clown[i]
		total += ClownCollectionData.get_stars_earned(i, count)
	return total

func get_available_stars() -> int:
	return maxi(0, get_total_stars_earned() - stars_spent)

func spend_stars(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_available_stars() < amount:
		return false
	stars_spent += amount
	save_settings()
	return true

# ====== THEMES ======

func is_theme_unlocked(theme_id: String) -> bool:
	return unlocked_themes.has(theme_id)

func get_locked_themes() -> Array:
	var locked: Array = []
	for id in THEME_IDS:
		if not unlocked_themes.has(id):
			locked.append(id)
	return locked

func unlock_theme(theme_id: String) -> bool:
	if not THEME_IDS.has(theme_id) or unlocked_themes.has(theme_id):
		return false
	unlocked_themes.append(theme_id)
	save_settings()
	return true

func set_current_theme(theme_id: String):
	if not unlocked_themes.has(theme_id):
		return
	current_theme = theme_id
	save_settings()

# Unlocked themes in THEME_IDS order, so cycling is stable rather than
# following whatever order they happened to be unlocked in.
func get_unlocked_themes_ordered() -> Array:
	var ordered: Array = []
	for id in THEME_IDS:
		if unlocked_themes.has(id):
			ordered.append(id)
	return ordered

# step of -1 or +1, wrapping at both ends. Returns the new theme id.
func cycle_theme(step: int) -> String:
	var ordered = get_unlocked_themes_ordered()
	if ordered.size() <= 1:
		return current_theme
	var index = ordered.find(current_theme)
	if index == -1:
		index = 0
	index = wrapi(index + step, 0, ordered.size())
	set_current_theme(ordered[index])
	return current_theme

# ── DEBUG ─────────────────────────────────────────────────────
# Wipes theme unlocks and refunds every star spent, so the shop can be
# tested from scratch. Deliberately leaves merge/drop counters alone —
# those are the earned progress and shouldn't be thrown away to test a
# purchase flow. Called from the shop screen's debug hotkey.
func debug_reset_themes():
	unlocked_themes = [DEFAULT_THEME]
	current_theme = DEFAULT_THEME
	stars_spent = 0
	save_settings()
	print("🧪 Theme unlocks reset, stars refunded")

# ====== SAVE/LOAD ======

func save_settings():
	var save_data = {
		# Audio
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"mute_when_tabbed": mute_when_tabbed,
		
		# Visual
		"screen_mode": screen_mode,
		"vsync_enabled": vsync_enabled,
		"fps_cap": fps_cap,
		"colorblind_mode": colorblind_mode,
		
		# Gameplay
		"drop_assist_enabled": drop_assist_enabled,
		"drop_key": drop_key,
		"powerup_key_1": powerup_key_1,
		"powerup_key_2": powerup_key_2,
		"powerup_key_3": powerup_key_3,
		
		# Statistics
		"best_score": best_score,
		"total_runs": total_runs,
		"total_clowns_dropped": total_clowns_dropped,
		"highest_tier_created": highest_tier_created,
		"time_played_seconds": time_played_seconds,
		"merges_per_clown": merges_per_clown,
		"drops_per_clown": drops_per_clown,

		# Themes & shop
		"stars_spent": stars_spent,
		"unlocked_themes": unlocked_themes,
		"current_theme": current_theme
	}
	
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("💾 Settings saved")
	else:
		print("❌ Failed to save settings")

func load_settings():
	if not FileAccess.file_exists("user://settings.save"):
		print("No save file found, using defaults")
		return
	
	var file = FileAccess.open("user://settings.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		# Audio
		master_volume = save_data.get("master_volume", 1.0)
		music_volume = save_data.get("music_volume", 1.0)
		sfx_volume = save_data.get("sfx_volume", 1.0)
		mute_when_tabbed = save_data.get("mute_when_tabbed", false)
		
		# Visual
		screen_mode = save_data.get("screen_mode", 0)
		vsync_enabled = save_data.get("vsync_enabled", true)
		fps_cap = save_data.get("fps_cap", 60)
		colorblind_mode = save_data.get("colorblind_mode", 0)
		
		# Gameplay
		drop_assist_enabled = save_data.get("drop_assist_enabled", false)
		drop_key = save_data.get("drop_key", KEY_SPACE)
		powerup_key_1 = save_data.get("powerup_key_1", KEY_Q)
		powerup_key_2 = save_data.get("powerup_key_2", KEY_W)
		powerup_key_3 = save_data.get("powerup_key_3", KEY_E)
		
		# Statistics
		best_score = save_data.get("best_score", 0)
		total_runs = save_data.get("total_runs", 0)
		total_clowns_dropped = save_data.get("total_clowns_dropped", 0)
		highest_tier_created = save_data.get("highest_tier_created", 0)
		time_played_seconds = save_data.get("time_played_seconds", 0.0)
		merges_per_clown = save_data.get("merges_per_clown", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		drops_per_clown = save_data.get("drops_per_clown", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

		# Themes & shop
		stars_spent = save_data.get("stars_spent", 0)
		unlocked_themes = save_data.get("unlocked_themes", [DEFAULT_THEME])
		current_theme = save_data.get("current_theme", DEFAULT_THEME)
		# A save from before themes existed, or a hand-edited one, could leave
		# the active theme locked or unknown — fall back rather than trying to
		# load textures for a colour that has no assets.
		if not unlocked_themes.has(current_theme) or not THEME_IDS.has(current_theme):
			current_theme = DEFAULT_THEME
		if not unlocked_themes.has(DEFAULT_THEME):
			unlocked_themes.append(DEFAULT_THEME)
		
		print("✅ Settings loaded")
	else:
		print("❌ Failed to load settings")

# ====== UTILITY ======

func get_key_name(key: int) -> String:
	return OS.get_keycode_string(key)

func get_colorblind_mode_name() -> String:
	match colorblind_mode:
		0: return "None"
		1: return "Protanopia"
		2: return "Deuteranopia"
		3: return "Tritanopia"
	return "None"

func get_screen_mode_name() -> String:
	match screen_mode:
		0: return "Windowed"
		1: return "Fullscreen"
		2: return "Borderless"
	return "Windowed"

func get_fps_cap_name() -> String:
	if fps_cap == 0:
		return "Unlimited"
	return str(fps_cap)

func format_time_played() -> String:
	# Reads the live total, not the stored field — otherwise the current
	# session never shows and a first-time player always sees "0h 0m".
	var total = get_time_played_seconds()
	var hours = int(total / 3600.0)
	var minutes = int((total - hours * 3600) / 60.0)
	# Under an hour, minutes alone reads better than "0h 7m"; under a
	# minute, seconds, so a fresh install doesn't look broken.
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm" % minutes
	return "%ds" % int(total)
