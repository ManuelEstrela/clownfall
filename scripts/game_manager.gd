extends Node2D
class_name GameManager

# Theme manager
var theme_manager = preload("res://scripts/theme_manager.gd").new()

# Preload scenes and script
const ClownBallScene = preload("res://scenes/clown_ball.tscn")
const ClownBallScript = preload("res://scripts/clown_ball.gd")

# ====== EASY POSITIONING & SIZING CONTROLS ======

# SCORE BALLOON (Top Left)
var score_balloon_x: float = 220
var score_balloon_y: float = 155
var score_balloon_scale: float = 1.4

# NEXT BALLOON (Top Right)
var next_balloon_x_offset: float = 210
var next_balloon_y: float = 190
var next_balloon_scale: float = 1.6

# CLOWN CYCLE (Bottom Right decoration)
var clown_cycle_x_offset: float = 220
var clown_cycle_y_offset: float = 200
var clown_cycle_scale: float = 0.9

# BOX CONTAINER - VISUAL ONLY
var box_visual_scale: float = 1.3
var box_vertical_offset: float = 50
var box_visual_offset_y: float = 37

# BOX CONTAINER - COLLISION WALLS
var box_collision_scale: float = 0.95
var wall_horizontal_padding: float = 28.0

# VAN
var van_y_offset: float = 40
var van_scale: float = 0.87

# ====== BALLOON FLOAT ANIMATION ======
var balloon_float_amount: float = 12.0
var balloon_float_duration: float = 4.2

# ====== CONTROLLER ======
var controller_speed: float = 800.0  # pixels per second — tweak to feel right

# ====== MERGE FEEL ======
# Merged clowns used to always spawn at rotation 0 (bolt upright), which made
# every merge look identical and unnaturally tidy. These control how much the
# new clown inherits its orientation/motion from the two clowns that made it.

# How hard the merged clown pops out. (Was hardcoded as 200.)
var merge_pop_strength: float = 200.0
# Random tilt added on top of the inherited rotation, in radians.
# 0.0 = child exactly matches its parents' average tilt. 0.25 ≈ ±14°.
# Raise for messier, more chaotic spawns.
var merge_rotation_jitter: float = 0.25
# How much of the parents' spin the child keeps (0 = none, 1 = full).
var merge_spin_inherit: float = 0.5
# Random spin kick on spawn, in radians/sec.
var merge_spin_jitter: float = 2.0
# How much of the parents' linear velocity carries over (0–1).
var merge_velocity_inherit: float = 0.3
# How much the merge axis bends the pop direction away from straight up.
# 0.0 = always straight up (old behaviour). 1.0 = fully perpendicular to the
# axis between the two parents. 0.35 is a subtle, natural lean.
var merge_axis_influence: float = 0.35

# ================================================

# Game state
var score: int = 0
var game_over: bool = false
var can_drop: bool = true
var current_clown_type: int = 0
var next_clown_type: int = 0

var debug_hitboxes: bool = false
var test_mode: bool = false
var test_clown_index: int = 0

# Preview clown
var preview_clown = null
var van_sprite: Sprite2D = null
var background_sprite: Sprite2D = null
var clown_cycle_sprite: Sprite2D = null
var box_square_sprite: Sprite2D = null

# UI Elements
var score_balloon: Sprite2D = null
var score_label: Label = null
var next_balloon: Sprite2D = null
var next_clown_sprite: Sprite2D = null

# Balloon group roots
var score_balloon_root: Node2D = null
var next_balloon_root: Node2D = null

# Audio players
var click_sound: AudioStreamPlayer = null
var game_over_sound: AudioStreamPlayer = null
var pop_sounds: Array[AudioStreamPlayer] = []

# Collision sounds (size-grouped)
var collision_sound_small: AudioStreamPlayer = null
var collision_sound_medium: AudioStreamPlayer = null
var collision_sound_large: AudioStreamPlayer = null

# Boundaries
var play_area_left: float
var play_area_right: float
var drop_y: float
var danger_y: float
var container_center_x: float
var container_center_y: float

# Signals
signal score_changed(new_score: int)
signal game_over_triggered(final_score: int)

func _ready():
	randomize()

	if debug_hitboxes:
		print("🔍 DEBUG MODE: Hitbox visualization ENABLED")
		get_tree().debug_collisions_hint = true

	var viewport_size = get_viewport_rect().size

	container_center_x = viewport_size.x / 2.0
	container_center_y = (viewport_size.y / 2.0) + box_vertical_offset

	# Background
	background_sprite = Sprite2D.new()
	background_sprite.texture = load("res://assets/images/landing_background.png")
	background_sprite.z_index = -100
	add_child(background_sprite)
	background_sprite.position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
	var bg_scale_x = viewport_size.x / background_sprite.texture.get_width()
	var bg_scale_y = viewport_size.y / background_sprite.texture.get_height()
	var bg_scale = max(bg_scale_x, bg_scale_y)
	background_sprite.scale = Vector2(bg_scale, bg_scale)

	# Container sprite
	var container = $Container
	container.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)
	container.z_index = 0
	container.texture = theme_manager.get_box_texture()

	var original_width = 1024.0
	var original_height = 1536.0
	var target_height = viewport_size.y * box_collision_scale
	var container_scale = target_height / original_height
	var visual_scale = container_scale * box_visual_scale
	container.scale = Vector2(visual_scale, visual_scale)

	# Box square overlay
	box_square_sprite = Sprite2D.new()
	box_square_sprite.texture = theme_manager.get_box_square_texture()
	box_square_sprite.z_index = 150
	add_child(box_square_sprite)
	box_square_sprite.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)
	box_square_sprite.scale = Vector2(visual_scale, visual_scale)
	print("🎨 Box square overlay added on top")

	# Collision walls
	var scaled_width = original_width * container_scale
	var scaled_height = original_height * container_scale
	var container_half_width = scaled_width / 2.0
	var container_half_height = scaled_height / 2.0
	var wall_thickness = 40.0 * container_scale
	var side_padding = 25.0 * container_scale
	var top_padding = 180.0 * container_scale

	play_area_left = container_center_x - container_half_width + side_padding + (wall_horizontal_padding * container_scale)
	play_area_right = container_center_x + container_half_width - side_padding - (wall_horizontal_padding * container_scale)
	drop_y = container_center_y - container_half_height + top_padding
	danger_y = drop_y + 120

	var left_wall_collision = $Walls/StaticBody2D/LeftWall
	var floor_collision = $Walls/StaticBody2D2/Floor
	var right_wall_collision = $Walls/StaticBody2D3/RightWall

	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(wall_thickness, scaled_height)
	left_wall_collision.shape = left_shape
	left_wall_collision.position = Vector2(
		container_center_x - container_half_width + wall_thickness/2 + (wall_horizontal_padding * container_scale),
		container_center_y
	)

	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(wall_thickness, scaled_height)
	right_wall_collision.shape = right_shape
	right_wall_collision.position = Vector2(
		container_center_x + container_half_width - wall_thickness/2 - (wall_horizontal_padding * container_scale),
		container_center_y
	)

	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(scaled_width - (side_padding * 2), wall_thickness)
	floor_collision.shape = floor_shape
	var container_floor_offset = 200.0 * container_scale
	floor_collision.position = Vector2(
		container_center_x,
		container_center_y + container_half_height - container_floor_offset
	)

	print("=== Game Setup ===")
	print("Viewport size: ", viewport_size)

	setup_audio()

	if test_mode:
		print("=== TEST MODE: Dropping all clowns in order ===")
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		current_clown_type = randi() % 5
		next_clown_type = randi() % 5

	setup_ui_balloons(viewport_size, container_scale)
	update_next_preview()

	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(van_scale, van_scale) * container_scale
	van_sprite.z_index = 100
	add_child(van_sprite)
	van_sprite.global_position = Vector2(container_center_x, drop_y - van_y_offset)

	add_clown_cycle_decoration(viewport_size, container_scale)
	spawn_preview()

func setup_audio():
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/assets_click.mp3")
	click_sound.volume_db = 0
	click_sound.bus = "SFX"
	add_child(click_sound)

	game_over_sound = AudioStreamPlayer.new()
	game_over_sound.stream = load("res://assets/sounds/game_over.mp3")
	game_over_sound.volume_db = 0
	game_over_sound.bus = "SFX"
	add_child(game_over_sound)

	for i in range(11):
		var pop_player = AudioStreamPlayer.new()
		pop_player.stream = load("res://assets/sounds/assets_pop" + str(i) + ".mp3")
		pop_player.volume_db = 0
		pop_player.bus = "SFX"
		add_child(pop_player)
		pop_sounds.append(pop_player)

	collision_sound_small = AudioStreamPlayer.new()
	collision_sound_small.stream = load("res://assets/sounds/collision/clown_collision_1.wav")
	collision_sound_small.volume_db = 0
	collision_sound_small.bus = "SFX"
	add_child(collision_sound_small)

	collision_sound_medium = AudioStreamPlayer.new()
	collision_sound_medium.stream = load("res://assets/sounds/collision/clown_collision_2.wav")
	collision_sound_medium.volume_db = 0
	collision_sound_medium.bus = "SFX"
	add_child(collision_sound_medium)

	collision_sound_large = AudioStreamPlayer.new()
	collision_sound_large.stream = load("res://assets/sounds/collision/clown_collision_3.wav")
	collision_sound_large.volume_db = 0
	collision_sound_large.bus = "SFX"
	add_child(collision_sound_large)

	print("✅ Audio setup complete (including collision sounds)!")

func setup_ui_balloons(viewport_size: Vector2, container_scale: float):
	var balloon_texture = theme_manager.get_balloon_texture()
	var custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	# ── SCORE GROUP ──────────────────────────────────────────────
	score_balloon_root = Node2D.new()
	score_balloon_root.z_index = 200
	score_balloon_root.position = Vector2(score_balloon_x, score_balloon_y)
	add_child(score_balloon_root)

	score_balloon = Sprite2D.new()
	score_balloon.texture = balloon_texture
	var final_score_scale = score_balloon_scale * container_scale
	score_balloon.scale = Vector2(final_score_scale, final_score_scale)
	score_balloon.position = Vector2.ZERO
	score_balloon_root.add_child(score_balloon)

	score_label = Label.new()
	score_balloon.add_child(score_label)
	if custom_font:
		score_label.add_theme_font_override("font", custom_font)
	score_label.add_theme_font_size_override("font_size", int(48 / final_score_scale))
	score_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	score_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	score_label.add_theme_constant_override("outline_size", int(2 / final_score_scale))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.position = Vector2(-80 / final_score_scale, -50 / final_score_scale)
	score_label.size = Vector2(160 / final_score_scale, 80 / final_score_scale)
	score_label.text = "0"

	# ── NEXT GROUP ───────────────────────────────────────────────
	next_balloon_root = Node2D.new()
	next_balloon_root.z_index = 200
	next_balloon_root.position = Vector2(viewport_size.x - next_balloon_x_offset, next_balloon_y)
	add_child(next_balloon_root)

	next_balloon = Sprite2D.new()
	next_balloon.texture = balloon_texture
	var final_next_scale = next_balloon_scale * container_scale
	next_balloon.scale = Vector2(final_next_scale, final_next_scale)
	next_balloon.position = Vector2.ZERO
	next_balloon_root.add_child(next_balloon)

	var next_label = Label.new()
	next_balloon.add_child(next_label)
	if custom_font:
		next_label.add_theme_font_override("font", custom_font)
	next_label.add_theme_font_size_override("font_size", int(32 / final_next_scale))
	next_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	next_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	next_label.add_theme_constant_override("outline_size", int(2 / final_next_scale))
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.position = Vector2(-60 / final_next_scale, -80 / final_next_scale)
	next_label.size = Vector2(120 / final_next_scale, 40 / final_next_scale)
	next_label.text = "NEXT"

	next_clown_sprite = Sprite2D.new()
	next_balloon.add_child(next_clown_sprite)
	next_clown_sprite.z_index = 1
	next_clown_sprite.position = Vector2(0, 10 / final_next_scale)

	# ── START FLOAT ANIMATIONS ───────────────────────────────────
	_start_balloon_float(score_balloon_root, 0.0)
	_start_balloon_float(next_balloon_root, balloon_float_duration * 0.4)

func _start_balloon_float(root: Node2D, phase_offset: float):
	var rest_y = root.position.y

	var start_tween = func():
		var tween = create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(root, "position:y",
			rest_y - balloon_float_amount,
			balloon_float_duration / 2.0)
		tween.tween_property(root, "position:y",
			rest_y + balloon_float_amount,
			balloon_float_duration / 2.0)

	if phase_offset > 0.0:
		await get_tree().create_timer(phase_offset).timeout
	start_tween.call()

func add_clown_cycle_decoration(viewport_size: Vector2, container_scale: float):
	clown_cycle_sprite = Sprite2D.new()
	clown_cycle_sprite.texture = theme_manager.get_clown_cycle_texture()
	clown_cycle_sprite.z_index = 5
	add_child(clown_cycle_sprite)

	var cycle_x = play_area_right + clown_cycle_x_offset
	var cycle_y = viewport_size.y - clown_cycle_y_offset
	clown_cycle_sprite.global_position = Vector2(cycle_x, cycle_y)
	clown_cycle_sprite.scale = Vector2(clown_cycle_scale, clown_cycle_scale) * container_scale

func _input(event):
	if game_over:
		return

	if event is InputEventMouseMotion:
		if van_sprite:
			var mouse_x = get_viewport().get_mouse_position().x
			var clamped_x = clampf(mouse_x, play_area_left, play_area_right)
			van_sprite.global_position.x = clamped_x
			if preview_clown:
				preview_clown.global_position.x = clamped_x

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drop_clown()

	# Controller drop
	if event.is_action_pressed("drop"):
		drop_clown()

func _process(delta):
	if game_over:
		return
	_handle_controller_input(delta)
	check_danger_zone(delta)

func _handle_controller_input(delta: float):
	if game_over or not van_sprite:
		return

	var stick_x = Input.get_axis("move_left", "move_right")
	if abs(stick_x) > 0.1:
		var new_x = clampf(
			van_sprite.global_position.x + stick_x * controller_speed * delta,
			play_area_left,
			play_area_right
		)
		van_sprite.global_position.x = new_x
		if preview_clown:
			preview_clown.global_position.x = new_x

func spawn_preview():
	if game_over:
		return

	var start_x = container_center_x
	if van_sprite:
		start_x = van_sprite.global_position.x

	preview_clown = ClownBallScene.instantiate()
	add_child(preview_clown)
	preview_clown.setup(current_clown_type)
	preview_clown.freeze = true
	preview_clown.can_merge = false
	preview_clown.modulate.a = 0.9
	preview_clown.z_index = 50
	preview_clown.global_position = Vector2(start_x, drop_y)

func update_next_preview():
	if next_clown_sprite:
		var next_clown_data = ClownBallScript.CLOWNS[next_clown_type]
		next_clown_sprite.texture = load(next_clown_data.image)

		var balloon_scale = next_balloon.scale.x if next_balloon else 1.0
		var target_size = 60.0 / balloon_scale
		var clown_texture_size = next_clown_sprite.texture.get_width()
		var scale_factor = target_size / clown_texture_size
		next_clown_sprite.scale = Vector2(scale_factor, scale_factor)

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
	new_clown.can_merge = true

	set_meta("last_dropped_clown", new_clown)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.add_clowns_dropped(1)
		settings.add_clown_drop(drop_type)

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

# Averages two angles correctly, handling the wrap at ±PI. A naive (a + b) / 2
# would turn 179° and -179° (which are 2° apart) into 0° — snapping the child
# bolt upright, which is exactly the bug we're fixing. angle_difference() takes
# the short way around the circle instead.
func _average_angle(a: float, b: float) -> float:
	return a + angle_difference(a, b) / 2.0

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)

	var merge_sound_index = clown1.clown_type
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()

	var points = ClownBallScript.CLOWNS[new_type].score
	score += points
	score_changed.emit(score)

	if score_label:
		score_label.text = str(score)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.update_highest_tier(new_type)
		settings.add_clown_merge(new_type)

	# ── Capture the parents' orientation/motion BEFORE they're freed ──
	# The new clown inherits the average tilt of the two clowns that made it,
	# so it's born leaning the way they were leaning instead of always snapping
	# upright. We also keep some of their spin and velocity so the merge carries
	# its own momentum, and remember the axis they were sitting along.
	var merge_rotation = _average_angle(clown1.rotation, clown2.rotation)
	var inherited_spin = (clown1.angular_velocity + clown2.angular_velocity) / 2.0
	var inherited_velocity = (clown1.linear_velocity + clown2.linear_velocity) / 2.0
	var merge_axis = (clown2.global_position - clown1.global_position).normalized()

	if has_meta("last_dropped_clown"):
		var last = get_meta("last_dropped_clown")
		if last == clown1 or last == clown2:
			remove_meta("last_dropped_clown")

	clown1.queue_free()
	clown2.queue_free()

	await get_tree().create_timer(0.05).timeout

	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(new_type)
	new_clown.global_position = merge_pos
	new_clown.rotation = merge_rotation + randf_range(-merge_rotation_jitter, merge_rotation_jitter)
	new_clown.freeze = false

	await get_tree().create_timer(0.01).timeout

	# Pop mostly upward, but nudged perpendicular to the merge axis, so a
	# side-by-side merge pops differently than a stacked one.
	var pop_dir = Vector2(0, -1).lerp(
		Vector2(-merge_axis.y, merge_axis.x),
		merge_axis_influence
	).normalized()
	new_clown.apply_central_impulse(
		pop_dir * merge_pop_strength + inherited_velocity * merge_velocity_inherit
	)
	new_clown.angular_velocity = inherited_spin * merge_spin_inherit \
		+ randf_range(-merge_spin_jitter, merge_spin_jitter)

func check_danger_zone(delta: float):
	for child in get_children():
		if child is ClownBall and not child.freeze:
			if child.global_position.y < danger_y:
				if child.linear_velocity.length() < 50:
					if not child.has_meta("danger_timer"):
						child.set_meta("danger_timer", 0.0)
					var timer = child.get_meta("danger_timer") + delta
					child.set_meta("danger_timer", timer)
					if timer > 1.0:
						trigger_game_over()
						return
			else:
				if child.has_meta("danger_timer"):
					child.set_meta("danger_timer", 0.0)

func trigger_game_over():
	if game_over:
		return

	game_over = true
	can_drop = false

	if game_over_sound:
		game_over_sound.play()

	print("Game Over! Final Score: ", score)

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.update_best_score(score)
		settings.increment_total_runs()

	var steam = get_node_or_null("/root/SteamManager")
	if steam and steam.is_on_steam:
		print("📤 Uploading score to Steam leaderboard...")
		steam.upload_score(score)
	else:
		print("⚠️ Steam not available, score not uploaded")

	if preview_clown:
		preview_clown.queue_free()
		preview_clown = null
	if van_sprite:
		van_sprite.queue_free()
		van_sprite = null

	for child in get_children():
		if child is ClownBall:
			child.freeze = true

	game_over_triggered.emit(score)

	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
