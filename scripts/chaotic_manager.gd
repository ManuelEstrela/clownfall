extends "res://scripts/game_manager.gd"

# ====== CHAOTIC MODE SETTINGS ======
var event_interval: float = 10.0
var event_timer: float = 0.0
var event_counting: bool = true

# Event durations
var rushtime_duration: float = 7.0
var zero_gravity_duration: float = 10.0
var lights_out_duration: float = 8.0

# Powerup durations
var double_points_duration: float = 15.0
var extra_life_duration: float = 30.0

# Current active effects
var is_rushtime_active: bool = false
var is_zero_gravity_active: bool = false
var is_lights_out_active: bool = false
var is_double_points_active: bool = false
var is_extra_life_active: bool = false

# Effect timers
var rushtime_timer: float = 0.0
var zero_gravity_timer: float = 0.0
var lights_out_timer: float = 0.0
var double_points_timer: float = 0.0
var extra_life_timer: float = 0.0

# Rushtime variables
var rushtime_drop_timer: float = 0.0
var rushtime_drop_interval: float = 1

# Lights out overlay
var lights_out_overlay: ColorRect = null
var flashlight_circle: ColorRect = null
var spotlight_pos: Vector2 = Vector2(0.5, 0.5)
var spotlight_target: Vector2 = Vector2(0.5, 0.5)
var spotlight_move_timer: float = 0.0
var spotlight_move_interval: float = 0.8

# Original gravity
var original_gravity: float = 1200.0

# Powerup cooldowns
var powerup_cooldowns: Dictionary = {
	"double_points": 0.0,
	"shuffle": 0.0,
	"extra_life": 0.0
}
var powerup_used: Dictionary = {
	"double_points": false,
	"shuffle": false,
	"extra_life": false
}
var powerup_cooldown_duration: float = 20.0

# UI for powerups and events
# The keycaps sit where the leaderboard used to, mirroring how the Police
# Jail took over that slot in classic mode.
var keycap_root: Control = null
var keycaps: Dictionary = {}          # powerup name -> Keycap
var event_timer_label: Label = null
# Keybinds are re-read every frame and compared, so changing one in the
# settings menu updates the caps without needing a restart.
var displayed_keys: Dictionary = {}

# ── KEYCAP LAYOUT ─────────────────────────────────────────────
# Pyramid: one on top, two below. Centred on where the leaderboard sat.
const KEYCAP_CENTER_X := 215.0
const KEYCAP_TOP_Y := 300.0
const KEYCAP_SIZE := Vector2(112.0, 112.0)
const KEYCAP_GAP := Vector2(18.0, 14.0)
# Slot order: 1 = top, 2 = bottom-left, 3 = bottom-right.
const POWERUP_SLOTS := [
	{"name": "double_points", "label": "2X POINTS", "slot": 1},
	{"name": "shuffle",       "label": "SHUFFLE",   "slot": 2},
	{"name": "extra_life",    "label": "EXTRA LIFE","slot": 3},
]
# Drop a PNG at this path per powerup and it replaces the drawn icon.
const POWERUP_ICON_DIR := "res://assets/images/powerups/"

# ====== CHAOS SOUND EFFECTS ======
var gravity_event_sound: AudioStreamPlayer = null
var lightsout_event_sound: AudioStreamPlayer = null
var lightsout_start_sound: AudioStreamPlayer = null
var rushtime_event_sound: AudioStreamPlayer = null

func _ready():
	super._ready()
	
	print("CHAOTIC MODE INITIALIZED!")
	
	# Setup chaos sounds
	setup_chaos_sounds()
	
	# The keycap panel takes the leaderboard's place, same as the jail does
	# in classic mode.
	hide_leaderboard()

	# Setup chaotic UI
	setup_chaotic_ui()
	
	# Setup lights out overlay (hidden by default)
	setup_lights_out()

func setup_chaos_sounds():
	# Gravity event sound (loops during zero gravity)
	gravity_event_sound = AudioStreamPlayer.new()
	gravity_event_sound.stream = load("res://assets/sounds/chaos/chaos_gravity_event.mp3")
	gravity_event_sound.volume_db = 0
	gravity_event_sound.bus = "SFX"
	add_child(gravity_event_sound)
	
	# Lights out event sound (loops during lights out)
	lightsout_event_sound = AudioStreamPlayer.new()
	lightsout_event_sound.stream = load("res://assets/sounds/chaos/chaos_lightsout_event.mp3")
	lightsout_event_sound.volume_db = 0
	lightsout_event_sound.bus = "SFX"
	add_child(lightsout_event_sound)
	
	# Lights out start sound (plays once when event starts)
	lightsout_start_sound = AudioStreamPlayer.new()
	lightsout_start_sound.stream = load("res://assets/sounds/chaos/chaos_lightsout_start.mp3")
	lightsout_start_sound.volume_db = 0
	lightsout_start_sound.bus = "SFX"
	add_child(lightsout_start_sound)
	
	# Rushtime event sound (loops during rushtime)
	rushtime_event_sound = AudioStreamPlayer.new()
	rushtime_event_sound.stream = load("res://assets/sounds/chaos/chaos_rushtime_event.mp3")
	rushtime_event_sound.volume_db = 0
	rushtime_event_sound.bus = "SFX"
	add_child(rushtime_event_sound)
	
	print("✅ Chaos sounds loaded!")

func setup_chaotic_ui():
	var settings = get_node_or_null("/root/SettingsManager")

	keycap_root = Control.new()
	keycap_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keycap_root.z_index = 250
	add_child(keycap_root)

	# Pyramid positions, worked out from the centre so the whole cluster
	# moves together if KEYCAP_CENTER_X changes.
	var half = KEYCAP_SIZE / 2.0
	var positions = [
		Vector2(KEYCAP_CENTER_X - half.x, KEYCAP_TOP_Y),
		Vector2(KEYCAP_CENTER_X - KEYCAP_SIZE.x - KEYCAP_GAP.x / 2.0,
			KEYCAP_TOP_Y + KEYCAP_SIZE.y + KEYCAP_GAP.y),
		Vector2(KEYCAP_CENTER_X + KEYCAP_GAP.x / 2.0,
			KEYCAP_TOP_Y + KEYCAP_SIZE.y + KEYCAP_GAP.y),
	]

	for i in range(POWERUP_SLOTS.size()):
		var info = POWERUP_SLOTS[i]
		var cap = Keycap.new()
		cap.size = KEYCAP_SIZE
		cap.position = positions[i]
		cap.powerup_name = info.name
		cap.icon_texture = _load_powerup_icon(info.name)
		cap.key_text = _key_name_for_slot(settings, info.slot)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keycap_root.add_child(cap)
		keycaps[info.name] = cap
		displayed_keys[info.name] = _key_for_slot(settings, info.slot)

	# Timer sits under the caps. Doubles as the event name while one runs,
	# which is why the old centre-screen announcement is gone.
	event_timer_label = Label.new()
	event_timer_label.z_index = 250
	add_child(event_timer_label)
	var font = load("res://assets/fonts/Clownfall-Regular.ttf")
	if font:
		event_timer_label.add_theme_font_override("font", font)
	event_timer_label.add_theme_font_size_override("font_size", 24)
	event_timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	event_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	event_timer_label.add_theme_constant_override("outline_size", 5)
	event_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_timer_label.position = Vector2(KEYCAP_CENTER_X - 200,
		KEYCAP_TOP_Y + KEYCAP_SIZE.y * 2.0 + KEYCAP_GAP.y + 22.0)
	event_timer_label.size = Vector2(400, 30)
	event_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_timer_label.text = "NEXT EVENT IN: %ds" % int(event_interval)

func _load_powerup_icon(powerup_name: String) -> Texture2D:
	var path = POWERUP_ICON_DIR + powerup_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _key_for_slot(settings, slot: int) -> int:
	if settings == null:
		return [KEY_Q, KEY_W, KEY_E][slot - 1]
	match slot:
		1: return settings.powerup_key_1
		2: return settings.powerup_key_2
		_: return settings.powerup_key_3

func _key_name_for_slot(settings, slot: int) -> String:
	var key = _key_for_slot(settings, slot)
	if settings and settings.has_method("get_key_name"):
		return settings.get_key_name(key)
	return OS.get_keycode_string(key)

# Keeps the caps in step with the settings menu. Cheap: three integer
# comparisons, and it only touches a cap when a bind actually changed.
func refresh_keycap_binds():
	var settings = get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	for info in POWERUP_SLOTS:
		var current = _key_for_slot(settings, info.slot)
		if displayed_keys.get(info.name, -1) != current:
			displayed_keys[info.name] = current
			var cap = keycaps.get(info.name)
			if cap:
				cap.key_text = _key_name_for_slot(settings, info.slot)
				cap.queue_redraw()

func setup_lights_out():
	# [Lights out setup code remains the same...]
	var lights_out_layer = CanvasLayer.new()
	lights_out_layer.layer = 999
	add_child(lights_out_layer)
	
	lights_out_overlay = ColorRect.new()
	lights_out_overlay.color = Color(0, 0, 0, 0.98)
	lights_out_overlay.size = get_viewport_rect().size
	lights_out_overlay.visible = false
	lights_out_layer.add_child(lights_out_overlay)
	
	flashlight_circle = ColorRect.new()
	flashlight_circle.size = get_viewport_rect().size
	flashlight_circle.visible = false
	
	var shader_code = """
shader_type canvas_item;

uniform vec2 spotlight_pos = vec2(0.5, 0.5);
uniform float spotlight_radius = 150.0;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel_pos = FRAGCOORD.xy;
	vec2 spotlight_pixel = spotlight_pos * screen_size;
	
	float dist = distance(pixel_pos, spotlight_pixel);
	float spotlight = smoothstep(spotlight_radius + 50.0, spotlight_radius - 20.0, dist);
	
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - spotlight);
}
"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	
	flashlight_circle.material = material
	lights_out_layer.add_child(flashlight_circle)

func _process(delta):
	super._process(delta)
	
	if game_over:
		return
	
	refresh_keycap_binds()
	refresh_keycap_states()

	if event_counting:
		event_timer += delta
		if event_timer >= event_interval:
			event_timer = 0.0
			event_counting = false
			trigger_random_event()
		else:
			var time_left = event_interval - event_timer
			event_timer_label.text = "NEXT EVENT IN: %ds" % int(ceil(time_left))
			event_timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		# While an event runs the timer slot shows its name instead — this
		# replaces the old centre-screen announcement.
		event_timer_label.text = active_event_name()
		event_timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	
	update_rushtime(delta)
	update_zero_gravity(delta)
	update_lights_out(delta)
	update_double_points(delta)
	update_extra_life(delta)
	
	for powerup in powerup_cooldowns.keys():
		if powerup_cooldowns[powerup] > 0:
			powerup_cooldowns[powerup] -= delta

# Derived from the active flags rather than stored when the event fires, so
# it can never disagree with what's actually running.
func active_event_name() -> String:
	if is_rushtime_active:
		return "RUSHTIME!"
	if is_zero_gravity_active:
		return "ZERO GRAVITY!"
	if is_lights_out_active:
		return "LIGHTS OUT!"
	return "EVENT ACTIVE!"

func refresh_keycap_states():
	for info in POWERUP_SLOTS:
		var cap = keycaps.get(info.name)
		if cap == null:
			continue
		var spent: bool = powerup_used.get(info.name, false)
		var cooling: bool = powerup_cooldowns.get(info.name, 0.0) > 0.0
		var now_available = not spent and not cooling
		if cap.available != now_available:
			cap.available = now_available
			cap.queue_redraw()

func _input(event):
	super._input(event)
	
	if game_over:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Binds come from the settings menu now, not hardcoded QWE.
		var settings = get_node_or_null("/root/SettingsManager")
		for info in POWERUP_SLOTS:
			if event.keycode == _key_for_slot(settings, info.slot):
				activate_powerup(info.name)
				return

func trigger_random_event():
	var events = ["rushtime", "zero_gravity", "lights_out"]
	var chosen_event = events[randi() % events.size()]
	
	print("Event triggered: ", chosen_event)
	show_event_notification(chosen_event.to_upper() + "!")
	
	match chosen_event:
		"rushtime":
			start_rushtime()
		"zero_gravity":
			start_zero_gravity()
		"lights_out":
			start_lights_out()

# The centre-screen announcement is gone — the event's name appears in the
# timer slot under the keycaps for as long as it's actually running, which
# is more useful than a banner that fades after two seconds. Kept as a
# function so the existing call site doesn't need to change; a quick pulse
# on the label draws the eye when an event starts.
func show_event_notification(text: String):
	print("Event: ", text)
	if event_timer_label == null:
		return
	var tween = create_tween()
	tween.tween_property(event_timer_label, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(event_timer_label, "scale", Vector2.ONE, 0.22)

# ========== EVENTS ==========

func start_rushtime():
	is_rushtime_active = true
	rushtime_timer = rushtime_duration
	rushtime_drop_timer = 0.0
	
	# Play rushtime sound (looping)
	if rushtime_event_sound:
		rushtime_event_sound.play()
	
	print("RUSHTIME STARTED!")

func update_rushtime(delta: float):
	if not is_rushtime_active:
		return
	
	rushtime_timer -= delta
	rushtime_drop_timer -= delta
	
	if rushtime_drop_timer <= 0:
		rushtime_drop_timer = rushtime_drop_interval
		drop_clown()
	
	if rushtime_timer <= 0:
		is_rushtime_active = false
		event_counting = true
		
		# Stop rushtime sound
		if rushtime_event_sound:
			rushtime_event_sound.stop()
		
		print("RUSHTIME ENDED")

func start_zero_gravity():
	is_zero_gravity_active = true
	zero_gravity_timer = zero_gravity_duration
	
	for child in get_children():
		if child is ClownBall:
			child.gravity_scale = 0.1
			child.apply_central_impulse(Vector2(0, -30))
	
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, 100.0)
	
	# Play gravity sound (looping)
	if gravity_event_sound:
		gravity_event_sound.play()
	
	print("ZERO GRAVITY STARTED!")

func update_zero_gravity(delta: float):
	if not is_zero_gravity_active:
		return
	
	zero_gravity_timer -= delta
	
	if zero_gravity_timer <= 0:
		is_zero_gravity_active = false
		event_counting = true
		
		for child in get_children():
			if child is ClownBall:
				child.gravity_scale = 1.0
		
		PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, original_gravity)
		
		# Stop gravity sound
		if gravity_event_sound:
			gravity_event_sound.stop()
		
		print("ZERO GRAVITY ENDED")

func start_lights_out():
	is_lights_out_active = true
	lights_out_timer = lights_out_duration
	lights_out_overlay.visible = true
	flashlight_circle.visible = true
	
	spotlight_pos = Vector2(0.5, 0.5)
	spotlight_target = Vector2(0.5, 0.5)
	spotlight_move_timer = 0.0
	
	# Play start sound (one-shot)
	if lightsout_start_sound:
		lightsout_start_sound.play()
	
	# Play looping event sound
	if lightsout_event_sound:
		lightsout_event_sound.play()
	
	print("LIGHTS OUT STARTED!")

func update_lights_out(delta: float):
	if not is_lights_out_active:
		return
	
	lights_out_timer -= delta
	spotlight_move_timer -= delta
	
	if spotlight_move_timer <= 0:
		spotlight_move_timer = spotlight_move_interval
		spotlight_target = Vector2(
			randf_range(0.3, 0.7),
			randf_range(0.2, 0.8)
		)
	
	var move_speed = 3.5
	spotlight_pos = spotlight_pos.lerp(spotlight_target, delta * move_speed)
	
	if flashlight_circle and flashlight_circle.material:
		flashlight_circle.material.set_shader_parameter("spotlight_pos", spotlight_pos)
	
	if lights_out_timer <= 0:
		is_lights_out_active = false
		lights_out_overlay.visible = false
		flashlight_circle.visible = false
		event_counting = true
		
		# Stop lights out sound
		if lightsout_event_sound:
			lightsout_event_sound.stop()
		
		print("LIGHTS OUT ENDED")

# ========== POWERUPS ==========

func activate_powerup(powerup_name: String):
	if powerup_used[powerup_name]:
		print("Powerup already used: ", powerup_name)
		return
	
	if powerup_cooldowns[powerup_name] > 0:
		print("Powerup on cooldown: ", powerup_name)
		return
	
	print("Activating powerup: ", powerup_name)
	powerup_used[powerup_name] = true
	
	darken_powerup_button(powerup_name)
	
	match powerup_name:
		"double_points":
			start_double_points()
		"shuffle":
			do_shuffle()
		"extra_life":
			start_extra_life()

func darken_powerup_button(powerup_name: String):
	var cap = keycaps.get(powerup_name)
	if cap:
		cap.available = false
		cap.queue_redraw()
		# Quick press-down so using a powerup registers even when your eyes
		# are on the container.
		var tween = create_tween()
		tween.tween_property(cap, "position:y", cap.position.y + 5.0, 0.06)
		tween.tween_property(cap, "position:y", cap.position.y, 0.12)
		print("Powerup used: ", powerup_name)

func start_double_points():
	is_double_points_active = true
	double_points_timer = double_points_duration
	print("DOUBLE POINTS ACTIVATED!")

func update_double_points(delta: float):
	if not is_double_points_active:
		return
	
	double_points_timer -= delta
	
	if double_points_timer <= 0:
		is_double_points_active = false
		print("DOUBLE POINTS ENDED")

func do_shuffle():
	var temp = current_clown_type
	current_clown_type = next_clown_type
	next_clown_type = temp
	
	if preview_clown:
		preview_clown.queue_free()
		spawn_preview()
	
	update_next_preview()
	print("SHUFFLE ACTIVATED!")

func start_extra_life():
	is_extra_life_active = true
	extra_life_timer = extra_life_duration
	# Recolour the limit line so it's obvious the rule is suspended.
	if danger_line:
		danger_line.line_color = Color(0.35, 0.95, 0.45)
	print("EXTRA LIFE ACTIVATED!")

func update_extra_life(delta: float):
	if not is_extra_life_active:
		return
	
	extra_life_timer -= delta
	
	if extra_life_timer <= 0:
		is_extra_life_active = false
		if danger_line:
			danger_line.line_color = danger_line_color
		print("EXTRA LIFE ENDED")

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)
	
	var merge_sound_index = clown1.clown_type
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()
	
	var points = ClownBallScript.CLOWNS[new_type].score
	if is_double_points_active:
		points *= 2
		print("DOUBLE POINTS APPLIED!")
	
	score += points
	score_changed.emit(score)
	run_peak_tier = maxi(run_peak_tier, new_type)
	
	if score_label:
		score_label.text = str(score)
	
	# Track this merge so the collection screen updates (Tessa is drop-tracked
	# separately in drop_clown; every other clown counts merges here).
	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.update_highest_tier(new_type)
		settings.add_clown_merge(new_type)
	
	clown1.queue_free()
	clown2.queue_free()
	
	# Defined in game_manager.gd. Needed here explicitly because this
	# override reimplements merge_clowns rather than calling super.
	spawn_merge_sparkles(merge_pos, new_type)
	
	await get_tree().create_timer(0.05).timeout
	
	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(new_type)
	new_clown.global_position = merge_pos
	new_clown.freeze = false
	
	if is_zero_gravity_active:
		new_clown.gravity_scale = 0.1
	
	if not is_zero_gravity_active:
		await get_tree().create_timer(0.01).timeout
		new_clown.apply_central_impulse(Vector2(0, -200))

func drop_clown():
	if not preview_clown or not can_drop or game_over:
		return
	
	can_drop = false
	
	if click_sound:
		click_sound.play()
	
	var drop_x = preview_clown.global_position.x
	var drop_type = current_clown_type
	
	preview_clown.queue_free()
	preview_clown = null
	
	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(drop_type)
	new_clown.global_position = Vector2(drop_x, drop_y)
	new_clown.freeze = false
	
	# Record the drop per clown type (used for Tessa's collection progress)
	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.add_clowns_dropped(1)
		settings.add_clown_drop(drop_type)
	
	if is_zero_gravity_active:
		new_clown.gravity_scale = 0.1
		await get_tree().create_timer(0.01).timeout
		new_clown.apply_central_impulse(Vector2(0, 400))
	
	if test_mode:
		test_clown_index += 1
		if test_clown_index >= ClownBallScript.CLOWNS.size():
			test_clown_index = 0
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		current_clown_type = next_clown_type
		next_clown_type = randi() % min(5, current_clown_type + 2)
	
	update_next_preview()
	
	await get_tree().create_timer(0.5).timeout
	if not game_over:
		can_drop = true
		spawn_preview()

# Extra Life no longer skips the check entirely. It used to return early,
# which froze the danger timers — clowns could pile past the line and sit
# there, then end the run the instant the powerup expired. Now the check
# runs as normal and handle_danger_breach() below intercepts the result.
func check_danger_zone(delta: float):
	super.check_danger_zone(delta)

# Called by GameManager when a clown has held above the limit long enough
# to be fatal. While Extra Life is up, the clown bursts and the run carries
# on; otherwise this falls through to the normal game over.
func handle_danger_breach(clown) -> bool:
	if not is_extra_life_active:
		return false
	pop_clown_at_limit(clown)
	return true

func pop_clown_at_limit(clown):
	if not is_instance_valid(clown):
		return

	var burst = PopBurst.new()
	burst.position = clown.global_position
	burst.burst_radius = clown.merge_radius * 2.4
	burst.burst_color = Color(1.0, 0.45, 0.35)
	burst.z_index = 300
	add_child(burst)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "progress", 1.0, 0.35)
	tween.tween_callback(burst.queue_free)

	if clown.clown_type < pop_sounds.size():
		pop_sounds[clown.clown_type].play()

	# Reuses the jail's safe-removal path: it clears can_merge / is_merging
	# before freeing, so a neighbour can't grab the dying clown as a merge
	# partner in the frames before it actually leaves the tree.
	remove_clown(clown)

	print("💥 Extra Life burst: ", ClownBallScript.CLOWNS[clown.clown_type].name)

# ══════════════════════════════════════════════════════════════════════
#  KEYCAP
#
#  A drawn keyboard cap: powerup icon on the upper face, keybind on the
#  lower strip. Placeholders only — drop a PNG at
#  res://assets/images/powerups/<powerup_name>.png and it replaces the
#  drawn icon with no code change.
# ══════════════════════════════════════════════════════════════════════
class Keycap extends Control:
	var powerup_name: String = ""
	var key_text: String = ""
	var icon_texture: Texture2D = null
	var available: bool = true

	func _draw():
		# Dimmed once spent or on cooldown, so state reads at a glance
		# without needing a separate indicator.
		var fade = 1.0 if available else 0.42
		var body = Color(0.09, 0.09, 0.12, 0.96 * fade)
		var face = Color(0.16, 0.16, 0.21, fade)
		var edge = Color(0.75, 0.77, 0.85, fade)
		var key_color = Color(0.95, 0.25, 0.25, fade) if available \
			else Color(0.6, 0.6, 0.65, fade)

		# Cap body with a lip along the bottom to suggest depth
		var lip = size.y * 0.09
		var body_box := StyleBoxFlat.new()
		body_box.bg_color = body
		body_box.set_corner_radius_all(int(size.x * 0.14))
		draw_style_box(body_box, Rect2(Vector2.ZERO, size))

		var face_box := StyleBoxFlat.new()
		face_box.bg_color = face
		face_box.set_corner_radius_all(int(size.x * 0.11))
		draw_style_box(face_box, Rect2(
			Vector2(size.x * 0.07, size.y * 0.06),
			Vector2(size.x * 0.86, size.y * 0.86 - lip)
		))

		# Icon occupies the upper ~62% of the face
		var icon_area = Rect2(
			Vector2(size.x * 0.16, size.y * 0.12),
			Vector2(size.x * 0.68, size.y * 0.50)
		)
		if icon_texture:
			draw_texture_rect(icon_texture, icon_area, false, Color(1, 1, 1, fade))
		else:
			_draw_placeholder_icon(icon_area, edge, fade)

		# Divider, then the keybind on the lower strip
		var divider_y = size.y * 0.66
		draw_line(Vector2(size.x * 0.18, divider_y),
			Vector2(size.x * 0.82, divider_y), Color(1, 1, 1, 0.16 * fade), 2.0)

		var font = ThemeDB.fallback_font
		var font_size = int(size.y * 0.20)
		var text = key_text.to_upper()
		var text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x
		draw_string(font,
			Vector2((size.x - text_w) / 2.0, size.y * 0.88 - lip * 0.5),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, key_color)

	func _draw_placeholder_icon(area: Rect2, tint: Color, fade: float):
		var c = area.position + area.size / 2.0
		var r = min(area.size.x, area.size.y) * 0.42

		match powerup_name:
			"double_points":
				# Two stacked chevrons pointing up — "more"
				for i in range(2):
					var y = c.y - r * 0.5 + i * r * 0.62
					draw_line(Vector2(c.x - r * 0.7, y + r * 0.3),
						Vector2(c.x, y - r * 0.2), tint, r * 0.22)
					draw_line(Vector2(c.x, y - r * 0.2),
						Vector2(c.x + r * 0.7, y + r * 0.3), tint, r * 0.22)
			"shuffle":
				# Two crossing arrows
				draw_line(c + Vector2(-r, -r * 0.5), c + Vector2(r, r * 0.5), tint, r * 0.20)
				draw_line(c + Vector2(-r, r * 0.5), c + Vector2(r, -r * 0.5), tint, r * 0.20)
				for dir in [-1.0, 1.0]:
					var tip = c + Vector2(r, dir * r * 0.5)
					draw_line(tip, tip + Vector2(-r * 0.34, dir * -r * 0.1), tint, r * 0.18)
					draw_line(tip, tip + Vector2(-r * 0.28, dir * -r * 0.34), tint, r * 0.18)
			_:
				# Heart for extra life, built from two arcs and a point
				var heart := PackedVector2Array()
				var steps := 30
				for i in range(steps + 1):
					var t = TAU * float(i) / float(steps)
					var x = 16.0 * pow(sin(t), 3)
					var y = -(13.0 * cos(t) - 5.0 * cos(2 * t)
						- 2.0 * cos(3 * t) - cos(4 * t))
					heart.append(c + Vector2(x, y) * (r / 16.0))
				draw_colored_polygon(heart, Color(0.95, 0.30, 0.36, fade))


# Expanding ring left behind by a clown that burst on the limit line.
# `progress` is what the tween drives; _process just keeps it redrawing.
class PopBurst extends Node2D:
	var progress: float = 0.0
	var burst_radius: float = 60.0
	var burst_color: Color = Color(1.0, 0.45, 0.35)

	func _process(_delta):
		queue_redraw()

	func _draw():
		var t = clampf(progress, 0.0, 1.0)
		var radius = burst_radius * (0.35 + t * 0.9)
		var alpha = 1.0 - t
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32,
			Color(burst_color.r, burst_color.g, burst_color.b, alpha),
			burst_radius * 0.16 * (1.0 - t * 0.6), true)
		# A few shards flying outward sell it as a burst rather than a ripple.
		for i in range(8):
			var angle = TAU * float(i) / 8.0
			var dir = Vector2(cos(angle), sin(angle))
			draw_line(dir * radius * 0.7, dir * radius * 1.05,
				Color(burst_color.r, burst_color.g, burst_color.b, alpha * 0.9),
				burst_radius * 0.10)
