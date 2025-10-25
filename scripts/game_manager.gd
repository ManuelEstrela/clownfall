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

# TEST MODE - drops all clowns in order
var test_mode: bool = false
var test_clown_index: int = 0

# Preview clown
var preview_clown = null
var van_sprite: Sprite2D = null
var background_sprite: Sprite2D = null

# Audio players
var click_sound: AudioStreamPlayer = null
var pop_sounds: Array[AudioStreamPlayer] = []

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
	
	# Add background first (behind everything)
	background_sprite = Sprite2D.new()
	background_sprite.texture = load("res://assets/images/gameplay_background.png")
	background_sprite.z_index = -100
	add_child(background_sprite)
	background_sprite.position = Vector2(container_center_x, container_center_y)
	# Scale background to cover entire viewport
	var bg_scale_x = viewport_size.x / background_sprite.texture.get_width()
	var bg_scale_y = viewport_size.y / background_sprite.texture.get_height()
	var bg_scale = max(bg_scale_x, bg_scale_y)  # Use max to cover entire screen
	background_sprite.scale = Vector2(bg_scale, bg_scale)
	
	# Update Container sprite position and scale to match viewport
	var container = $Container
	container.position = Vector2(container_center_x, container_center_y)
	container.z_index = 0  # Make sure container is above background
	
	# Scale container to fit viewport height (with some padding)
	# Original container image is 1024x1536
	var original_width = 1024.0
	var original_height = 1536.0
	var target_height = viewport_size.y * 0.95  # Use 95% of viewport height
	var container_scale = target_height / original_height
	container.scale = Vector2(container_scale, container_scale)
	
	# Calculate scaled dimensions
	var scaled_width = original_width * container_scale
	var scaled_height = original_height * container_scale
	var container_half_width = scaled_width / 2.0
	var container_half_height = scaled_height / 2.0
	
	# Wall thickness and padding
	var wall_thickness = 40.0 * container_scale  # Scale wall thickness with container
	var side_padding = 25.0 * container_scale
	var top_padding = 120.0 * container_scale  # Moved down from 80
	
	# Calculate boundaries
	play_area_left = container_center_x - container_half_width + side_padding
	play_area_right = container_center_x + container_half_width - side_padding
	drop_y = container_center_y - container_half_height + top_padding
	danger_y = drop_y + 120
	
	# Get wall bodies - they're under Walls node
	var left_wall_collision = $Walls/StaticBody2D/LeftWall
	var floor_collision = $Walls/StaticBody2D2/Floor
	var right_wall_collision = $Walls/StaticBody2D3/RightWall
	
	# Create and configure wall shapes
	# Left Wall
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(wall_thickness, scaled_height)
	left_wall_collision.shape = left_shape
	left_wall_collision.position = Vector2(
		container_center_x - container_half_width + wall_thickness/2,
		container_center_y
	)
	
	# Right Wall  
	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(wall_thickness, scaled_height)
	right_wall_collision.shape = right_shape
	right_wall_collision.position = Vector2(
		container_center_x + container_half_width - wall_thickness/2,
		container_center_y
	)
	
	# Floor - position it at the visual bottom of the container
	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(scaled_width - (side_padding * 2), wall_thickness)
	floor_collision.shape = floor_shape
	# The container visual bottom needs to account for the thick wooden base
	# Looking at the container image, the play area ends around 100-120px from the bottom
	var container_floor_offset = 200.0 * container_scale
	floor_collision.position = Vector2(
		container_center_x,
		container_center_y + container_half_height - container_floor_offset
	)
	
	print("=== Game Setup ===")
	print("Viewport size: ", viewport_size)
	print("Container center: (", container_center_x, ", ", container_center_y, ")")
	print("Container scale: ", container_scale)
	print("Container size: ", scaled_width, " x ", scaled_height)
	print("Play area X: ", play_area_left, " to ", play_area_right)
	print("Drop Y: ", drop_y)
	print("Danger Y: ", danger_y)
	print("Left wall X: ", left_wall_collision.position.x)
	print("Right wall X: ", right_wall_collision.position.x)
	print("Floor Y: ", floor_collision.position.y)
	
	# Setup audio players
	setup_audio()
	
	# TEST MODE: Start with first clown
	if test_mode:
		print("=== TEST MODE: Dropping all clowns in order ===")
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		# NORMAL MODE (commented out for testing)
		# Initialize clown types randomly
		current_clown_type = randi() % 5
		next_clown_type = randi() % 5
	
	update_next_preview()
	
	# Create van sprite
	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(0.87, 0.87) * container_scale  # Scale van with container
	van_sprite.z_index = 100
	add_child(van_sprite)
	van_sprite.global_position = Vector2(container_center_x, drop_y - 41)
	
	# Spawn preview clown after van is created
	spawn_preview()

func setup_audio():
	# Create click sound player
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/assets_click.ogg")
	click_sound.volume_db = 0
	add_child(click_sound)
	
	# Create pop sound players (one for each merge type)
	for i in range(11):  # 11 clowns means 10 possible merges (0-9)
		var pop_player = AudioStreamPlayer.new()
		pop_player.stream = load("res://assets/sounds/assets_pop" + str(i) + ".mp3")
		pop_player.volume_db = 0
		add_child(pop_player)
		pop_sounds.append(pop_player)
	
	print("Audio setup complete!")

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
	preview_clown.modulate.a = 0.9  # Slightly transparent
	preview_clown.global_position = Vector2(start_x, start_y)

func update_next_preview():
	# TODO: Update the UI next clown preview
	# This will connect to your GameUI scene later
	pass

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
	
	# TEST MODE: Cycle through all clowns in order
	if test_mode:
		test_clown_index += 1
		if test_clown_index >= ClownBallScript.CLOWNS.size():
			test_clown_index = 0  # Loop back to first clown
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		# NORMAL MODE (commented out for testing)
		# Update clown types randomly
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
	
	# Play pop sound for this merge (clown type that was merged)
	var merge_sound_index = clown1.clown_type  # The type that merged (0-9)
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()
	
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
			# Check if ball is above the danger line
			if child.global_position.y < danger_y:
				# Check if ball has settled (low velocity)
				if child.linear_velocity.length() < 50:
					if not child.has_meta("danger_timer"):
						child.set_meta("danger_timer", 0.0)
					
					var timer = child.get_meta("danger_timer") + delta
					child.set_meta("danger_timer", timer)
					
					# Game over after only 1 second in danger zone
					if timer > 1.0:
						trigger_game_over()
						return
			else:
				# Reset timer if ball drops below danger line
				if child.has_meta("danger_timer"):
					child.set_meta("danger_timer", 0.0)

func trigger_game_over():
	if game_over:
		return
		
	game_over = true
	can_drop = false
	
	print("Game Over! Final Score: ", score)
	
	# ⭐ Upload score to Steam
	var steam = get_node_or_null("/root/SteamManager")
	if steam and steam.is_on_steam:
		print("📤 Uploading score to Steam leaderboard...")
		steam.upload_score(score)
	else:
		print("⚠️ Steam not available, score not uploaded")
	
	# Remove preview clown and van
	if preview_clown:
		preview_clown.queue_free()
		preview_clown = null
	if van_sprite:
		van_sprite.queue_free()
		van_sprite = null
	
	# Freeze all clown balls
	for child in get_children():
		if child is ClownBall:
			child.freeze = true
	
	# Emit game over signal
	game_over_triggered.emit(score)
	
	# Restart after 3 seconds
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
