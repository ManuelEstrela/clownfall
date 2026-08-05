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
var total_currency_earned: int = 0
var time_played_seconds: float = 0.0

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

func _ready():
	setup_custom_cursor()
	load_settings()
	apply_all_settings()


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

func add_currency(amount: int):
	total_currency_earned += amount
	save_settings()

func add_time_played(seconds: float):
	time_played_seconds += seconds
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
		"total_currency_earned": total_currency_earned,
		"time_played_seconds": time_played_seconds,
		"merges_per_clown": merges_per_clown,
		"drops_per_clown": drops_per_clown
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
		total_currency_earned = save_data.get("total_currency_earned", 0)
		time_played_seconds = save_data.get("time_played_seconds", 0.0)
		merges_per_clown = save_data.get("merges_per_clown", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		drops_per_clown = save_data.get("drops_per_clown", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		
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
	var hours = int(time_played_seconds / 3600)
	var minutes = int((time_played_seconds - hours * 3600) / 60)
	return str(hours) + "h " + str(minutes) + "m"
