extends "res://scripts/game_manager.gd"

# ====== CHAOTIC MODE SETTINGS ======
var event_interval: float = 10.0  # Events every 10 seconds (starts counting after previous event ends)
var event_timer: float = 0.0
var event_counting: bool = true  # Whether we're counting towards next event

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
var rushtime_drop_interval: float = 1  # Drop a ball every 0.5 seconds

# Lights out overlay
var lights_out_overlay: ColorRect = null
var flashlight_circle: ColorRect = null

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
var event_timer_label: Label = null  # Shows countdown to next event

func _ready():
	super._ready()  # Call parent _ready()
	
	print("CHAOTIC MODE INITIALIZED!")
	
	# Setup chaotic UI
	setup_chaotic_ui()
	
	# Setup lights out overlay (hidden by default)
	setup_lights_out()

func setup_chaotic_ui():
	# Create powerup UI container
	powerup_container = HBoxContainer.new()
	powerup_container.z_index = 250
	add_child(powerup_container)
	powerup_container.position = Vector2(400, 50)
	powerup_container.add_theme_constant_override("separation", 20)  # Add spacing between buttons
	
	# Create powerup buttons
	create_powerup_button("Q - 2X Points", "double_points")
	create_powerup_button("W - Shuffle", "shuffle")
	create_powerup_button("E - Extra Life", "extra_life")
	
	# Create event notification label
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
	
	# Create event timer label (countdown to next event)
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
	# Create a CanvasLayer for the lights out overlay (so it's above everything including leaderboard)
	var lights_out_layer = CanvasLayer.new()
	lights_out_layer.layer = 999  # Very high layer to be above leaderboard CanvasLayer
	add_child(lights_out_layer)
	
	# Create dark overlay in the high-layer CanvasLayer
	lights_out_overlay = ColorRect.new()
	lights_out_overlay.color = Color(0, 0, 0, 0.95)
	lights_out_overlay.size = get_viewport_rect().size
	lights_out_overlay.visible = false
	lights_out_layer.add_child(lights_out_overlay)

func _process(delta):
	super._process(delta)  # Call parent _process()
	
	if game_over:
		return
	
	# Update event timer (only when event_counting is true)
	if event_counting:
		event_timer += delta
		if event_timer >= event_interval:
			event_timer = 0.0
			event_counting = false  # Stop counting until event finishes
			trigger_random_event()
		else:
			# Update timer display
			var time_left = event_interval - event_timer
			event_timer_label.text = "Next Event: " + str(int(ceil(time_left))) + "s"
	else:
		event_timer_label.text = "Event Active!"
	
	# Update active effects
	update_rushtime(delta)
	update_zero_gravity(delta)
	update_lights_out(delta)
	update_double_points(delta)
	update_extra_life(delta)
	
	# Update powerup cooldowns
	for powerup in powerup_cooldowns.keys():
		if powerup_cooldowns[powerup] > 0:
			powerup_cooldowns[powerup] -= delta

func _input(event):
	super._input(event)  # Call parent _input()
	
	if game_over:
		return
	
	# Powerup activation keys
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
	print("RUSHTIME STARTED!")

func update_rushtime(delta: float):
	if not is_rushtime_active:
		return
	
	rushtime_timer -= delta
	rushtime_drop_timer -= delta
	
	# Auto-drop balls
	if rushtime_drop_timer <= 0:
		rushtime_drop_timer = rushtime_drop_interval
		drop_clown()  # Call parent drop function
	
	if rushtime_timer <= 0:
		is_rushtime_active = false
		event_counting = true  # Start counting to next event
		print("RUSHTIME ENDED")

func start_zero_gravity():
	is_zero_gravity_active = true
	zero_gravity_timer = zero_gravity_duration
	
	# Set gravity to near-zero for all existing balls AND give them slight upward push
	for child in get_children():
		if child is ClownBall:
			child.gravity_scale = 0.1
			child.apply_central_impulse(Vector2(0, -100))  # Small upward push
	
	# Modify global gravity
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, 100.0)
	
	print("ZERO GRAVITY STARTED!")

func update_zero_gravity(delta: float):
	if not is_zero_gravity_active:
		return
	
	zero_gravity_timer -= delta
	
	if zero_gravity_timer <= 0:
		is_zero_gravity_active = false
		event_counting = true  # Start counting to next event
		
		# Restore gravity for all balls
		for child in get_children():
			if child is ClownBall:
				child.gravity_scale = 1.0
		
		# Restore global gravity
		PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, original_gravity)
		
		print("ZERO GRAVITY ENDED")

func start_lights_out():
	is_lights_out_active = true
	lights_out_timer = lights_out_duration
	lights_out_overlay.visible = true
	print("LIGHTS OUT STARTED!")

func update_lights_out(delta: float):
	if not is_lights_out_active:
		return
	
	lights_out_timer -= delta
	
	# TODO: Add flashlight effect that follows mouse
	
	if lights_out_timer <= 0:
		is_lights_out_active = false
		lights_out_overlay.visible = false
		event_counting = true  # Start counting to next event
		print("LIGHTS OUT ENDED")

# ========== POWERUPS ==========

func activate_powerup(powerup_name: String):
	# Check if already used
	if powerup_used[powerup_name]:
		print("Powerup already used: ", powerup_name)
		return
	
	if powerup_cooldowns[powerup_name] > 0:
		print("Powerup on cooldown: ", powerup_name)
		return
	
	print("Activating powerup: ", powerup_name)
	powerup_used[powerup_name] = true
	
	# Darken the powerup button
	darken_powerup_button(powerup_name)
	
	match powerup_name:
		"double_points":
			start_double_points()
		"shuffle":
			do_shuffle()
		"extra_life":
			start_extra_life()

func darken_powerup_button(powerup_name: String):
	# Find and darken the corresponding button
	for child in powerup_container.get_children():
		if child is ColorRect:
			var label = child.get_child(0)
			if label and label.get_meta("powerup_name") == powerup_name:
				child.color = Color(0.1, 0.1, 0.15, 0.5)  # Much darker
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Gray text
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
	
	# Update preview
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

# Override merge_clowns to apply double points
func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)
	
	# Play pop sound for this merge
	var merge_sound_index = clown1.clown_type
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()
	
	# Add score (with double points if active)
	var points = ClownBallScript.CLOWNS[new_type].score
	if is_double_points_active:
		points *= 2
		print("DOUBLE POINTS APPLIED!")
	
	score += points
	score_changed.emit(score)
	
	# Update score label
	if score_label:
		score_label.text = str(score)
	
	# Remove old clowns
	clown1.queue_free()
	clown2.queue_free()
	
	# Small delay before creating new clown
	await get_tree().create_timer(0.05).timeout
	
	# Create new merged clown
	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(new_type)
	new_clown.global_position = merge_pos
	new_clown.freeze = false
	
	# Apply zero gravity if active
	if is_zero_gravity_active:
		new_clown.gravity_scale = 0.1
	
	# Add some upward impulse for effect
	await get_tree().create_timer(0.01).timeout
	new_clown.apply_central_impulse(Vector2(0, -200))

# Override drop_clown to apply zero gravity to new balls
func drop_clown():
	if not preview_clown or not can_drop or game_over:
		return
	
	can_drop = false
	
	# Play click sound
	if click_sound:
		click_sound.play()
	
	var drop_x = preview_clown.global_position.x
	var drop_type = current_clown_type
	
	# Remove preview
	preview_clown.queue_free()
	preview_clown = null
	
	# Create physics-enabled clown
	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(drop_type)
	new_clown.global_position = Vector2(drop_x, drop_y)
	new_clown.freeze = false  # Enable physics
	
	# Apply zero gravity if active
	if is_zero_gravity_active:
		new_clown.gravity_scale = 0.1
		# Give it a tiny upward float when dropped during zero gravity
		await get_tree().create_timer(0.01).timeout
		new_clown.apply_central_impulse(Vector2(0, -50))
	
	# TEST MODE: Cycle through all clowns in order
	if test_mode:
		test_clown_index += 1
		if test_clown_index >= ClownBallScript.CLOWNS.size():
			test_clown_index = 0
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		# NORMAL MODE
		current_clown_type = next_clown_type
		next_clown_type = randi() % min(5, current_clown_type + 2)
	
	update_next_preview()
	
	# Spawn new preview after delay
	await get_tree().create_timer(0.5).timeout
	if not game_over:
		can_drop = true
		spawn_preview()

# Override check_danger_zone to account for extra life
func check_danger_zone(delta: float):
	if is_extra_life_active:
		# Extra life active - don't trigger game over
		return
	
	# Call parent function
	super.check_danger_zone(delta)
