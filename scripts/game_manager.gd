extends Node2D

# Theme manager
var theme_manager = preload("res://scripts/theme_manager.gd").new()

# Preload scenes and script
const ClownBallScene = preload("res://scenes/clown_ball.tscn")
const ClownBallScript = preload("res://scripts/clown_ball.gd")

# ====== EASY POSITIONING & SIZING CONTROLS ======
# Adjust these values to move and resize elements!

# SCORE BALLOON (Top Left)
var score_balloon_x: float = 220        # Left-right position
var score_balloon_y: float = 170        # Up-down position
var score_balloon_scale: float = 1.5    # Size multiplier

# NEXT BALLOON (Top Right)
var next_balloon_x_offset: float = 210  # Distance from right edge
var next_balloon_y: float = 190         # Up-down position
var next_balloon_scale: float = 1.7     # Size multiplier

# CLOWN CYCLE (Bottom Right decoration)
var clown_cycle_x_offset: float = 220   # Distance from container right edge
var clown_cycle_y_offset: float = 200   # Distance from bottom
var clown_cycle_scale: float = 0.7      # Size multiplier

# BOX CONTAINER - VISUAL ONLY
var box_visual_scale: float = 1.3       # Scale for box/square appearance ONLY (doesn't affect collisions)
var box_vertical_offset: float = 50    # Move container DOWN (positive = down, negative = up)
var box_visual_offset_y: float = 37    # ADDED: Move ONLY the visual sprites down (doesn't affect collisions)

# BOX CONTAINER - COLLISION WALLS
var box_collision_scale: float = 0.95   # 0.95 = 95% of viewport height (for collision boundaries)
var wall_horizontal_padding: float = 28.0  # ADDED: Extra padding to move walls inward (higher = walls closer together)

# VAN
var van_y_offset: float = 40            # Distance above drop point
var van_scale: float = 0.87             # Size multiplier

# ================================================

# Game state
var score: int = 0
var game_over: bool = false
var can_drop: bool = true
var current_clown_type: int = 0
var next_clown_type: int = 0

# DEBUG MODE - Set to true to visualize hitboxes
var debug_hitboxes: bool = false

# TEST MODE - drops all clowns in order
var test_mode: bool = false
var test_clown_index: int = 0

# Preview clown
var preview_clown = null
var van_sprite: Sprite2D = null
var background_sprite: Sprite2D = null
var clown_cycle_sprite: Sprite2D = null
var box_square_sprite: Sprite2D = null  # The inner square that appears on top

# UI Elements
var score_balloon: Sprite2D = null
var score_label: Label = null
var next_balloon: Sprite2D = null
var next_clown_sprite: Sprite2D = null

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
	
	# Enable debug draw for physics if debug mode is on
	if debug_hitboxes:
		print("🔍 DEBUG MODE: Hitbox visualization ENABLED")
		get_tree().debug_collisions_hint = true
	
	# Get the actual viewport size
	var viewport_size = get_viewport_rect().size
	
	# Calculate center based on viewport WITH VERTICAL OFFSET
	container_center_x = viewport_size.x / 2.0
	container_center_y = (viewport_size.y / 2.0) + box_vertical_offset  # MOVED DOWN
	
	# Add background first (behind everything)
	background_sprite = Sprite2D.new()
	background_sprite.texture = load("res://assets/images/gameplay_background.png")
	background_sprite.z_index = -100
	add_child(background_sprite)
	background_sprite.position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)  # Background stays centered
	# Scale background to cover entire viewport
	var bg_scale_x = viewport_size.x / background_sprite.texture.get_width()
	var bg_scale_y = viewport_size.y / background_sprite.texture.get_height()
	var bg_scale = max(bg_scale_x, bg_scale_y)  # Use max to cover entire screen
	background_sprite.scale = Vector2(bg_scale, bg_scale)
	
	# Update Container sprite position and scale to match viewport
	var container = $Container
	container.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)  # Apply visual offset
	container.z_index = 0  # Behind the square
	
	# THEME: Use themed box texture for container (back layer)
	container.texture = theme_manager.get_box_texture()
	
	# Calculate collision scale (for gameplay boundaries)
	# Original container image is 1024x1536
	var original_width = 1024.0
	var original_height = 1536.0
	var target_height = viewport_size.y * box_collision_scale
	var container_scale = target_height / original_height
	
	# Calculate visual scale (for box appearance only)
	var visual_scale = container_scale * box_visual_scale
	
	# Apply VISUAL scale to the box sprite
	container.scale = Vector2(visual_scale, visual_scale)
	
	# Add the SQUARE overlay on top (so clowns appear behind it)
	box_square_sprite = Sprite2D.new()
	box_square_sprite.texture = theme_manager.get_box_square_texture()
	box_square_sprite.z_index = 150  # Above clowns (clowns are z_index 0-100)
	add_child(box_square_sprite)
	box_square_sprite.position = Vector2(container_center_x, container_center_y + box_visual_offset_y)  # Apply visual offset
	box_square_sprite.scale = Vector2(visual_scale, visual_scale)  # Same visual scale as box
	print("🎨 Box square overlay added on top")
	
	# Calculate scaled dimensions FOR COLLISIONS (using collision scale, not visual scale)
	var scaled_width = original_width * container_scale
	var scaled_height = original_height * container_scale
	var container_half_width = scaled_width / 2.0
	var container_half_height = scaled_height / 2.0
	
	# Wall thickness and padding
	var wall_thickness = 40.0 * container_scale  # Scale wall thickness with container
	var side_padding = 25.0 * container_scale
	var top_padding = 180.0 * container_scale  # MOVED DOWN MORE to show van + ball fully
	
	# Calculate boundaries (all use offset center)
	# Apply extra horizontal padding to match wall positions
	play_area_left = container_center_x - container_half_width + side_padding + (wall_horizontal_padding * container_scale)
	play_area_right = container_center_x + container_half_width - side_padding - (wall_horizontal_padding * container_scale)
	drop_y = container_center_y - container_half_height + top_padding
	danger_y = drop_y + 120
	
	# Get wall bodies - they're under Walls node
	var left_wall_collision = $Walls/StaticBody2D/LeftWall
	var floor_collision = $Walls/StaticBody2D2/Floor
	var right_wall_collision = $Walls/StaticBody2D3/RightWall
	
	# Create and configure wall shapes (all use offset center)
	# Left Wall
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(wall_thickness, scaled_height)
	left_wall_collision.shape = left_shape
	left_wall_collision.position = Vector2(
		container_center_x - container_half_width + wall_thickness/2 + (wall_horizontal_padding * container_scale),
		container_center_y
	)
	
	# Right Wall  
	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(wall_thickness, scaled_height)
	right_wall_collision.shape = right_shape
	right_wall_collision.position = Vector2(
		container_center_x + container_half_width - wall_thickness/2 - (wall_horizontal_padding * container_scale),
		container_center_y
	)
	
	# Floor - position it at the visual bottom of the container
	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(scaled_width - (side_padding * 2), wall_thickness)
	floor_collision.shape = floor_shape
	# The container visual bottom needs to account for the thick wooden base
	var container_floor_offset = 200.0 * container_scale
	floor_collision.position = Vector2(
		container_center_x,
		container_center_y + container_half_height - container_floor_offset
	)
	
	print("=== Game Setup ===")
	print("Viewport size: ", viewport_size)
	print("Container center: (", container_center_x, ", ", container_center_y, ")")
	print("Container vertical offset: ", box_vertical_offset)
	print("Container scale: ", container_scale)
	print("Container size: ", scaled_width, " x ", scaled_height)
	print("Play area X: ", play_area_left, " to ", play_area_right)
	print("Drop Y: ", drop_y)
	print("Danger Y: ", danger_y)
	
	# Setup audio players
	setup_audio()
	
	# TEST MODE: Start with first clown
	if test_mode:
		print("=== TEST MODE: Dropping all clowns in order ===")
		current_clown_type = test_clown_index
		next_clown_type = (test_clown_index + 1) % ClownBallScript.CLOWNS.size()
	else:
		# NORMAL MODE
		current_clown_type = randi() % 5
		next_clown_type = randi() % 5
	
	# Setup UI elements (score and next preview balloons)
	setup_ui_balloons(viewport_size, container_scale)
	
	update_next_preview()
	
	# Create van sprite
	van_sprite = Sprite2D.new()
	van_sprite.texture = load("res://assets/images/van.png")
	van_sprite.scale = Vector2(van_scale, van_scale) * container_scale
	van_sprite.z_index = 100
	add_child(van_sprite)
	# Position van above the drop point using configurable offset
	van_sprite.global_position = Vector2(container_center_x, drop_y - van_y_offset)
	
	# Add clown cycle decoration
	add_clown_cycle_decoration(viewport_size, container_scale)
	
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

func setup_ui_balloons(viewport_size: Vector2, container_scale: float):
	# THEME: Get themed balloon texture
	var balloon_texture = theme_manager.get_balloon_texture()
	
	# === SCORE BALLOON (Top Left) ===
	score_balloon = Sprite2D.new()
	score_balloon.texture = balloon_texture
	score_balloon.z_index = 200
	add_child(score_balloon)
	
	# Position using configurable variables
	var final_score_scale = score_balloon_scale * container_scale
	score_balloon.scale = Vector2(final_score_scale, final_score_scale)
	score_balloon.position = Vector2(score_balloon_x, score_balloon_y)
	
	# Add score label
	score_label = Label.new()
	score_balloon.add_child(score_label)
	score_label.add_theme_font_size_override("font_size", int(48 / final_score_scale))
	score_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))  # Dark brown
	score_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	score_label.add_theme_constant_override("outline_size", int(2 / final_score_scale))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.position = Vector2(-80 / final_score_scale, -50 / final_score_scale)
	score_label.size = Vector2(160 / final_score_scale, 80 / final_score_scale)
	score_label.text = "0"
	
	print("🎈 Score balloon added at: ", score_balloon.position)
	
	# === NEXT CLOWN BALLOON (Top Right) ===
	next_balloon = Sprite2D.new()
	next_balloon.texture = balloon_texture
	next_balloon.z_index = 200
	add_child(next_balloon)
	
	# Position using configurable variables
	var final_next_scale = next_balloon_scale * container_scale
	next_balloon.scale = Vector2(final_next_scale, final_next_scale)
	next_balloon.position = Vector2(viewport_size.x - next_balloon_x_offset, next_balloon_y)
	
	# Add "NEXT" label
	var next_label = Label.new()
	next_balloon.add_child(next_label)
	next_label.add_theme_font_size_override("font_size", int(32 / final_next_scale))
	next_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	next_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	next_label.add_theme_constant_override("outline_size", int(2 / final_next_scale))
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.position = Vector2(-60 / final_next_scale, -80 / final_next_scale)
	next_label.size = Vector2(120 / final_next_scale, 40 / final_next_scale)
	next_label.text = "NEXT"
	
	# Add next clown sprite (will be updated in update_next_preview)
	next_clown_sprite = Sprite2D.new()
	next_balloon.add_child(next_clown_sprite)
	next_clown_sprite.z_index = 1
	next_clown_sprite.position = Vector2(0, 10 / final_next_scale)
	
	print("🎈 Next balloon added at: ", next_balloon.position)

func add_clown_cycle_decoration(viewport_size: Vector2, container_scale: float):
	# THEME: Add the decorative clown cycle on the bottom right
	clown_cycle_sprite = Sprite2D.new()
	clown_cycle_sprite.texture = theme_manager.get_clown_cycle_texture()
	clown_cycle_sprite.z_index = 5  # Above background, below game elements
	add_child(clown_cycle_sprite)
	
	# Position using configurable variables
	var cycle_x = play_area_right + clown_cycle_x_offset
	var cycle_y = viewport_size.y - clown_cycle_y_offset
	
	clown_cycle_sprite.global_position = Vector2(cycle_x, cycle_y)
	
	# Scale using configurable variable
	clown_cycle_sprite.scale = Vector2(clown_cycle_scale, clown_cycle_scale) * container_scale
	
	print("🎡 Clown cycle decoration added at: ", clown_cycle_sprite.global_position)

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
	
	# Position preview ball BELOW the van (at the actual drop point)
	var start_y = drop_y
	
	# Create preview ball
	preview_clown = ClownBallScene.instantiate()
	add_child(preview_clown)  # Add to tree FIRST
	preview_clown.setup(current_clown_type)  # Then setup
	preview_clown.freeze = true  # No physics yet
	preview_clown.modulate.a = 0.9  # Slightly transparent
	preview_clown.z_index = 50  # Below van (van is z_index 100)
	preview_clown.global_position = Vector2(start_x, start_y)

func update_next_preview():
	if next_clown_sprite:
		var next_clown_data = ClownBallScript.CLOWNS[next_clown_type]
		next_clown_sprite.texture = load(next_clown_data.image)
		
		# Scale the next clown to fit nicely in the balloon
		var balloon_scale = next_balloon.scale.x if next_balloon else 1.0
		var target_size = 60.0 / balloon_scale  # Target size in balloon space
		var clown_texture_size = next_clown_sprite.texture.get_width()
		var scale_factor = target_size / clown_texture_size
		next_clown_sprite.scale = Vector2(scale_factor, scale_factor)
		
		print("🎪 Next clown updated: ", next_clown_data.name)

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

func merge_clowns(clown1, clown2, merge_pos: Vector2, new_type: int):
	print("Merging! Type: ", new_type)
	
	# Play pop sound for this merge
	var merge_sound_index = clown1.clown_type
	if merge_sound_index < pop_sounds.size():
		pop_sounds[merge_sound_index].play()
	
	# Add score
	var points = ClownBallScript.CLOWNS[new_type].score
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
					
					# Game over after 1 second in danger zone
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
