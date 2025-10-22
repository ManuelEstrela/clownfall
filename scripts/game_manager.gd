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
	
	# Get the actual viewport size
	var viewport_size = get_viewport_rect().size
	
	# Calculate center based on viewport
	container_center_x = viewport_size.x / 2.0
	container_center_y = viewport_size.y / 2.0
	
	# Update Container sprite position and scale to match viewport
	var container = $Container
	container.position = Vector2(container_center_x, container_center_y)
	
	# Scale container to fit viewport height (with some padding)
	# Original container image is 1024x1536
	var original_height = 1536.0
	var target_height = viewport_size.y * 0.85  # Use 85% of viewport height
	var container_scale = target_height / original_height
	container.scale = Vector2(container_scale, container_scale)
	
	# Calculate scaled dimensions
	var container_half_width = (1024.0 * container_scale) / 2.0
	var container_half_height = (1536.0 * container_scale) / 2.0
	var wall_thickness = 20.0
	
	# Calculate boundaries with some padding
	play_area_left = container_center_x - container_half_width + wall_thickness + 20
	play_area_right = container_center_x + container_half_width - wall_thickness - 20
	drop_y = container_center_y - container_half_height + 100
	danger_y = container_center_y - container_half_height + 120
	
	# Update wall positions to match container
	# Your scene has 3 separate StaticBody2D nodes
	var left_wall_body = $Walls/StaticBody2D
	var right_wall_body = $Walls/StaticBody2D2
	var floor_body = $Walls/StaticBody2D3
	
	# Position the StaticBody2D nodes relative to container center
	left_wall_body.position = Vector2(container_center_x - container_half_width + 19.5, container_center_y + 121)
	right_wall_body.position = Vector2(container_center_x + container_half_width - 17.5, container_center_y + 124)
	floor_body.position = Vector2(container_center_x + 7, container_center_y + container_half_height + 35)
	
	print("Viewport size: ", viewport_size)
	print("Container center: ", container_center_x, ", ", container_center_y)
	print("Play area: ", play_area_left, " to ", play_area_right)
	print("Drop Y: ", drop_y)
	
	# Initialize clown types
	current_clown_type = randi() % 5
	next_clown_type = randi() % 5
	update_next_preview()
	
	# Create van sprite first
	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(0.6, 0.6)
	van_sprite.z_index = 100
	add_child(van_sprite)
	van_sprite.global_position = Vector2(container_center_x, drop_y - 44)
	
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
	await get_tree().create_timer(0.5).timeout
	if not game_over:
		can_drop = true
		spawn_preview()

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)
	
	# Add score
	var points = ClownBallScript.CLOWNS[new_type].score
	score += points
	score_changed.emit(score)
	
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
	
	# Add some upward impulse for effect
	await get_tree().create_timer(0.01).timeout
	new_clown.apply_central_impulse(Vector2(0, -200))

func _process(delta):
	if game_over:
		return
	
	# Check for game over
	check_danger_zone(delta)

func check_danger_zone(delta: float):
	for child in get_children():
		if child is ClownBall and not child.freeze:
			# Check if ball is in danger zone and nearly stationary
			if child.global_position.y < danger_y and child.linear_velocity.length() < 20:
				if not child.has_meta("danger_timer"):
					child.set_meta("danger_timer", 0.0)
				
				var timer = child.get_meta("danger_timer") + delta
				child.set_meta("danger_timer", timer)
				
				if timer > 3.0:  # 3 seconds in danger = game over
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
	print("Game Over! Final Score: ", score)
