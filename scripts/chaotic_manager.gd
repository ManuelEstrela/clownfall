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
var powerup_container: HBoxContainer = null
var event_label: Label = null
var event_timer_label: Label = null

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
	# [Rest of the UI setup code remains the same]
	powerup_container = HBoxContainer.new()
	powerup_container.z_index = 250
	add_child(powerup_container)
	powerup_container.position = Vector2(400, 50)
	powerup_container.add_theme_constant_override("separation", 20)
	
	create_powerup_button("Q - 2X Points", "double_points")
	create_powerup_button("W - Shuffle", "shuffle")
	create_powerup_button("E - Extra Life", "extra_life")
	
	event_label = Label.new()
	event_label.z_index = 250
	add_child(event_label)
	event_label.add_theme_font_size_override("font_size", 32)
	event_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	event_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	event_label.add_theme_constant_override("outline_size", 4)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.position = Vector2(640 - 200, 300)
	event_label.size = Vector2(400, 50)
	event_label.visible = false
	
	event_timer_label = Label.new()
	event_timer_label.z_index = 250
	add_child(event_timer_label)
	event_timer_label.add_theme_font_size_override("font_size", 20)
	event_timer_label.add_theme_color_override("font_color", Color(1, 1, 0))
	event_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	event_timer_label.add_theme_constant_override("outline_size", 3)
	event_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_timer_label.position = Vector2(640 - 150, 10)
	event_timer_label.size = Vector2(300, 30)
	event_timer_label.text = "Next Event: 10s"

func create_powerup_button(label_text: String, powerup_name: String):
	var button_bg = ColorRect.new()
	button_bg.size = Vector2(150, 60)
	button_bg.color = Color(0.2, 0.2, 0.3, 0.9)
	powerup_container.add_child(button_bg)
	
	var label = Label.new()
	button_bg.add_child(label)
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.position = Vector2(10, 20)
	label.set_meta("powerup_name", powerup_name)
	label.set_meta("button_bg", button_bg)

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
	
	if event_counting:
		event_timer += delta
		if event_timer >= event_interval:
			event_timer = 0.0
			event_counting = false
			trigger_random_event()
		else:
			var time_left = event_interval - event_timer
			event_timer_label.text = "Next Event: " + str(int(ceil(time_left))) + "s"
	else:
		event_timer_label.text = "Event Active!"
	
	update_rushtime(delta)
	update_zero_gravity(delta)
	update_lights_out(delta)
	update_double_points(delta)
	update_extra_life(delta)
	
	for powerup in powerup_cooldowns.keys():
		if powerup_cooldowns[powerup] > 0:
			powerup_cooldowns[powerup] -= delta

func _input(event):
	super._input(event)
	
	if game_over:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				activate_powerup("double_points")
			KEY_W:
				activate_powerup("shuffle")
			KEY_E:
				activate_powerup("extra_life")

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

func show_event_notification(text: String):
	event_label.text = text
	event_label.visible = true
	
	var tween = create_tween()
	tween.tween_property(event_label, "modulate:a", 0.0, 2.0).set_delay(2.0)
	tween.tween_callback(func(): event_label.visible = false)
	tween.tween_property(event_label, "modulate:a", 1.0, 0.0)

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
	for child in powerup_container.get_children():
		if child is ColorRect:
			var label = child.get_child(0)
			if label and label.get_meta("powerup_name") == powerup_name:
				child.color = Color(0.1, 0.1, 0.15, 0.5)
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				print("Darkened powerup button: ", powerup_name)

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
	print("EXTRA LIFE ACTIVATED!")

func update_extra_life(delta: float):
	if not is_extra_life_active:
		return
	
	extra_life_timer -= delta
	
	if extra_life_timer <= 0:
		is_extra_life_active = false
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
	
	if score_label:
		score_label.text = str(score)
	
	clown1.queue_free()
	clown2.queue_free()
	
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

func check_danger_zone(delta: float):
	if is_extra_life_active:
		return
	
	super.check_danger_zone(delta)
