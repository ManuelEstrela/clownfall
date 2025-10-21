extends Node2D

# Preload scenes and script
const ClownBallScene = preload("res://scenes/clown_ball.tscn")
const ClownBallScript = preload("res://scripts/clown_ball.gd")

# Game state
var score: int = 0
var game_over: bool = false
var can_drop: bool = true
var current_clown_type: int = 0
var next_clown_type: int = 0

# Preview clown
var preview_clown = null
var van_sprite: Sprite2D = null

# Boundaries (calculated dynamically)
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
	
	# Calculate play area based on container position
	container_center_x = 960.0  # center of 1920
	container_center_y = 540.0  # center of 1080
	
	# IMPORTANT: Adjust these based on your Container's actual scale!
	# If Container scale is 0.4: use 204.8 and 307.2
	# If Container scale is 0.5: use 256 and 384
	# Check Inspector → Transform → Scale when Container is selected
	var container_half_width = 409.6  # ADJUST THIS based on container scale
	var container_half_height = 614.4  # ADJUST THIS based on container scale
	var wall_thickness = 20.0
	
	# Calculate boundaries with some padding
	play_area_left = container_center_x - container_half_width + wall_thickness + 10
	play_area_right = container_center_x + container_half_width - wall_thickness - 10
	drop_y = container_center_y - container_half_height + 80
	danger_y = container_center_y - container_half_height + 100
	
	# Initialize clown types
	current_clown_type = randi() % 5
	next_clown_type = randi() % 5
	update_next_preview()
	
	# Create van sprite first
	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(0.8, 0.8)
	van_sprite.z_index = 100
	add_child(van_sprite)
	van_sprite.global_position = Vector2(container_center_x, drop_y - 28)
	
	# Spawn preview clown after van is created
	spawn_preview()

func _input(event):
	if game_over or not can_drop:
		return
	
	# Mouse movement
	if event is InputEventMouseMotion:
		if preview_clown and van_sprite:
			var mouse_x = get_viewport().get_mouse_position().x
			var clamped_x = clampf(mouse_x, play_area_left, play_area_right)
			
			# Update both van and preview position
			van_sprite.global_position.x = clamped_x
			preview_clown.global_position.x = clamped_x
	
	# Click to drop
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drop_clown()

func spawn_preview():
	if game_over:
		return
	
	var clown = ClownBallScript.CLOWNS[current_clown_type]
	
	# Get current van X position
	var start_x = container_center_x
	if van_sprite:
		start_x = van_sprite.global_position.x
	
	var start_y = drop_y
	
	# Create preview ball
	preview_clown = ClownBallScene.instantiate()
	add_child(preview_clown)  # Add to tree FIRST
	preview_clown.setup(current_clown_type)  # Then setup
	preview_clown.freeze = true  # No physics yet
	preview_clown.modulate.a = 0.8  # Slightly transparent
	preview_clown.global_position = Vector2(start_x, start_y)

func update_next_preview():
	# TODO: Update the UI next clown preview
	# This will connect to your GameUI scene later
	pass

func drop_clown():
	if not preview_clown or not can_drop or game_over:
		return
	
	can_drop = false
	
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
	
	# Update clown types
	current_clown_type = next_clown_type
	next_clown_type = randi() % min(5, current_clown_type + 2)  # Spawn up to 2 tiers ahead
	update_next_preview()
	
	# Spawn new preview after delay
	await get_tree().create_timer(0.3).timeout
	if not game_over:
		can_drop = true
		spawn_preview()

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	# Add score
	score += ClownBallScript.CLOWNS[new_type].score
	score_changed.emit(score)
	
	# Remove old clowns
	clown1.queue_free()
	clown2.queue_free()
	
	# Create new merged clown
	var new_clown = ClownBallScene.instantiate()
	add_child(new_clown)
	new_clown.setup(new_type)
	new_clown.global_position = merge_pos
	new_clown.freeze = false
	new_clown.apply_central_impulse(Vector2(0, -300))  # Bounce up

func _process(delta):
	if game_over:
		return
	
	# Check for game over
	check_danger_zone(delta)

func check_danger_zone(delta: float):
	for child in get_children():
		if child is RigidBody2D and child.has_method("setup"):  # It's a clown ball
			if not child.freeze:
				if child.global_position.y < danger_y and child.linear_velocity.length() < 10:
					if not child.has_meta("danger_timer"):
						child.set_meta("danger_timer", 0.0)
					var timer = child.get_meta("danger_timer") + delta
					child.set_meta("danger_timer", timer)
					if timer > 2.0:  # 2 seconds in danger = game over
						trigger_game_over()
						return
				else:
					child.set_meta("danger_timer", 0.0)

func trigger_game_over():
	game_over = true
	can_drop = false
	if preview_clown:
		preview_clown.queue_free()
		preview_clown = null
	if van_sprite:
		van_sprite.queue_free()
		van_sprite = null
	game_over_triggered.emit(score)
