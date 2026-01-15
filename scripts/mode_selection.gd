extends Control

@onready var background: TextureRect = $Background

# New UI elements
var gamemode_title: TextureRect
var classic_image: TextureRect
var chaos_image: TextureRect
var classic_title: TextureRect
var chaos_title: TextureRect
var start_button: TextureButton

var is_transitioning: bool = false
var selected_mode: String = ""  # Start with no selection
var start_button_base_scale: float = 0.5  # Store original scale for hover

func _ready():
	print("=== Mode Selection Loading (New Design) ===")
	
	# Load background (circus tent)
	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture
		print("✅ Background loaded")
	
	# Setup UI
	setup_ui()
	
	# Don't select any mode by default - both start at normal size
	
	print("=== Mode Selection Ready ===")

func _input(event):
	# ESC key goes back to main menu
	if event.is_action_pressed("ui_cancel") and not is_transitioning:
		print("🏠 ESC pressed - Back to main menu")
		is_transitioning = true
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func setup_ui():
	var viewport_size = get_viewport_rect().size
	
	# === GAMEMODE TITLE (top center) ===
	gamemode_title = TextureRect.new()
	gamemode_title.texture = load("res://assets/images/gamemode_title.png")
	gamemode_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	gamemode_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(gamemode_title)
	
	# Position at top center
	if gamemode_title.texture:
		var title_width = 450
		var title_ratio = gamemode_title.texture.get_height() / float(gamemode_title.texture.get_width())
		var title_height = title_width * title_ratio
		gamemode_title.size = Vector2(title_width, title_height)
		gamemode_title.position = Vector2((viewport_size.x - title_width) / 2, 55)
	
	print("✅ Gamemode title added")
	
	# === CLASSIC MODE (left box) ===
	# Image (character portraits) - CLICKABLE
	classic_image = TextureRect.new()
	classic_image.texture = load("res://assets/images/classic_image.png")
	classic_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_image.size = Vector2(400, 290)
	classic_image.position = Vector2(200, 210)
	classic_image.pivot_offset = classic_image.size / 2
	classic_image.mouse_filter = Control.MOUSE_FILTER_STOP  # Make it clickable
	add_child(classic_image)
	
	# Make image clickable
	classic_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_mode("classic")
	)
	
	# Add hover effects to image
	classic_image.mouse_entered.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, true)
	)
	classic_image.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)
	
	# Title (CLASSIC text below box) - CLICKABLE
	classic_title = TextureRect.new()
	classic_title.texture = load("res://assets/images/classic_title.png")
	classic_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	classic_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_title.mouse_filter = Control.MOUSE_FILTER_STOP  # Make it clickable
	add_child(classic_title)
	
	if classic_title.texture:
		var classic_title_width = 240  # Smaller
		var classic_title_ratio = classic_title.texture.get_height() / float(classic_title.texture.get_width())
		var classic_title_height = classic_title_width * classic_title_ratio
		classic_title.size = Vector2(classic_title_width, classic_title_height)
		classic_title.position = Vector2(270, 495)  # More up
		classic_title.pivot_offset = classic_title.size / 2
	
	# Make title clickable
	classic_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_mode("classic")
	)
	
	# Add hover effects to title
	classic_title.mouse_entered.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, true)
	)
	classic_title.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)
	
	print("✅ Classic mode added")
	
	# === CHAOS MODE (right box) ===
	# Image (character portraits) - CLICKABLE
	chaos_image = TextureRect.new()
	chaos_image.texture = load("res://assets/images/chaos_image.png")
	chaos_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chaos_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_image.size = Vector2(400, 290)
	chaos_image.position = Vector2(680, 210)
	chaos_image.pivot_offset = chaos_image.size / 2
	chaos_image.mouse_filter = Control.MOUSE_FILTER_STOP  # Make it clickable
	add_child(chaos_image)
	
	# Make image clickable
	chaos_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_mode("chaos")
	)
	
	# Add hover effects to image
	chaos_image.mouse_entered.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_image.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)
	
	# Title (CHAOS text below box) - CLICKABLE
	chaos_title = TextureRect.new()
	chaos_title.texture = load("res://assets/images/chaos_title.png")
	chaos_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	chaos_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_title.mouse_filter = Control.MOUSE_FILTER_STOP  # Make it clickable
	add_child(chaos_title)
	
	if chaos_title.texture:
		var chaos_title_width = 220  # Smaller
		var chaos_title_ratio = chaos_title.texture.get_height() / float(chaos_title.texture.get_width())
		var chaos_title_height = chaos_title_width * chaos_title_ratio
		chaos_title.size = Vector2(chaos_title_width, chaos_title_height)
		chaos_title.position = Vector2(780, 489)  # More up
		chaos_title.pivot_offset = chaos_title.size / 2
	
	# Make title clickable
	chaos_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_mode("chaos")
	)
	
	# Add hover effects to title
	chaos_title.mouse_entered.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_title.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)
	
	print("✅ Chaos mode added")
	
	# === START BUTTON (bottom center) ===
	start_button = TextureButton.new()
	start_button.texture_normal = load("res://assets/images/button_start.png")
	add_child(start_button)
	
	if start_button.texture_normal:
		var button_scale = 0.5  # CHANGE THIS: 0.4 = 40% size, 0.6 = 60%, 1.0 = 100%
		start_button_base_scale = button_scale  # Store for hover animation
		var texture_width = start_button.texture_normal.get_width()
		var texture_height = start_button.texture_normal.get_height()
		var scaled_width = texture_width * button_scale
		var scaled_height = texture_height * button_scale
		
		start_button.custom_minimum_size = Vector2(texture_width, texture_height)
		start_button.scale = Vector2(button_scale, button_scale)
		start_button.position = Vector2((viewport_size.x - scaled_width) / 2 - 152, 540)
		start_button.pivot_offset = Vector2(texture_width / 2, texture_height / 2)
	
	start_button.pressed.connect(_on_start_pressed)
	
	# Hover effect for start button
	start_button.mouse_entered.connect(func(): animate_button_hover(start_button, true))
	start_button.mouse_exited.connect(func(): animate_button_hover(start_button, false))
	
	print("✅ Start button added")

func select_mode(mode: String):
	# Reset both modes to normal first (if nothing selected yet)
	if selected_mode == "":
		classic_image.scale = Vector2(1.0, 1.0)
		classic_title.scale = Vector2(1.0, 1.0)
		chaos_image.scale = Vector2(1.0, 1.0)
		chaos_title.scale = Vector2(1.0, 1.0)
	
	selected_mode = mode
	
	if mode == "classic":
		# Highlight classic, shrink chaos
		animate_selection(classic_image, classic_title, true)
		animate_selection(chaos_image, chaos_title, false)
		print("🎪 Classic mode selected")
	else:
		# Highlight chaos, shrink classic
		animate_selection(chaos_image, chaos_title, true)
		animate_selection(classic_image, classic_title, false)
		print("🎪 Chaos mode selected")

func animate_hover(image: TextureRect, title: TextureRect, is_hovering: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	if is_hovering:
		# Slight scale up on hover
		tween.tween_property(image, "scale", Vector2(1.05, 1.05), 0.2)
		tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		# Back to normal
		tween.tween_property(image, "scale", Vector2(1.0, 1.0), 0.2)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.2)

func animate_selection(image: TextureRect, title: TextureRect, is_selected: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	if is_selected:
		# Scale up when selected
		tween.tween_property(image, "scale", Vector2(1.1, 1.1), 0.3)
		tween.tween_property(title, "scale", Vector2(1.1, 1.1), 0.3)
	else:
		# Scale down when not selected
		tween.tween_property(image, "scale", Vector2(0.9, 0.9), 0.3)
		tween.tween_property(title, "scale", Vector2(0.9, 0.9), 0.3)

func animate_button_hover(button: TextureButton, is_hovering: bool):
	# Use stored base scale, NOT current scale
	var target_scale = Vector2(start_button_base_scale * 1.15, start_button_base_scale * 1.15) if is_hovering else Vector2(start_button_base_scale, start_button_base_scale)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", target_scale, 0.2)

func _on_start_pressed():
	if is_transitioning:
		return
	
	# Don't start if no mode selected
	if selected_mode == "":
		print("⚠️ Please select a game mode first!")
		return
	
	print("▶️ Starting game in mode:", selected_mode)
	is_transitioning = true
	
	# Disable start button
	start_button.disabled = true
	
	fade_out_and_start_game()

func fade_out_and_start_game():
	var fade_duration = 0.5
	
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = get_viewport_rect().size
	fade_overlay.z_index = 1000
	add_child(fade_overlay)
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, fade_duration)
	
	await tween.finished
	
	print("🎮 Loading game scene with mode:", selected_mode)
	
	# Load the appropriate game scene
	if selected_mode == "chaos":
		get_tree().change_scene_to_file("res://scenes/game_world_chaotic.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_world_normal.tscn")
