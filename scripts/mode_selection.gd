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
var selected_mode: String = ""
var start_button_base_scale: float = 0.5

# Sound effects
var button_hover_sound: AudioStreamPlayer = null
var button_click_sound: AudioStreamPlayer = null
var start_game_sound: AudioStreamPlayer = null

func _ready():
	print("=== Mode Selection Loading (New Design) ===")
	
	# Load background
	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture
		print("✅ Background loaded")
	
	# Setup sounds
	setup_sounds()
	
	# Setup UI
	setup_ui()
	
	print("=== Mode Selection Ready ===")

func setup_sounds():
	# Hover sound
	button_hover_sound = AudioStreamPlayer.new()
	button_hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	button_hover_sound.volume_db = -5
	button_hover_sound.bus = "SFX"
	add_child(button_hover_sound)
	
	# Click sound
	button_click_sound = AudioStreamPlayer.new()
	button_click_sound.stream = load("res://assets/sounds/button_click.mp3")
	button_click_sound.volume_db = 0
	button_click_sound.bus = "SFX"
	add_child(button_click_sound)
	
	# Start game sound
	start_game_sound = AudioStreamPlayer.new()
	start_game_sound.stream = load("res://assets/sounds/start_game.mp3")
	start_game_sound.volume_db = 0
	start_game_sound.bus = "SFX"
	add_child(start_game_sound)
	
	print("✅ Mode selection sounds loaded!")

func _input(event):
	if event.is_action_pressed("ui_cancel") and not is_transitioning:
		print("🏠 ESC pressed - Back to main menu")
		is_transitioning = true
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func setup_ui():
	var viewport_size = get_viewport_rect().size
	
	# === GAMEMODE TITLE ===
	gamemode_title = TextureRect.new()
	gamemode_title.texture = load("res://assets/images/gamemode_title.png")
	gamemode_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	gamemode_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(gamemode_title)
	
	if gamemode_title.texture:
		var title_width = 450
		var title_ratio = gamemode_title.texture.get_height() / float(gamemode_title.texture.get_width())
		var title_height = title_width * title_ratio
		gamemode_title.size = Vector2(title_width, title_height)
		gamemode_title.position = Vector2((viewport_size.x - title_width) / 2, 55)
	
	print("✅ Gamemode title added")
	
	# === CLASSIC MODE ===
	classic_image = TextureRect.new()
	classic_image.texture = load("res://assets/images/classic_image.png")
	classic_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_image.size = Vector2(400, 290)
	classic_image.position = Vector2(200, 210)
	classic_image.pivot_offset = classic_image.size / 2
	classic_image.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(classic_image)
	
	classic_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("classic")
	)
	
	classic_image.mouse_entered.connect(func():
		if selected_mode != "classic":
			button_hover_sound.play()
			animate_hover(classic_image, classic_title, true)
	)
	classic_image.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)
	
	classic_title = TextureRect.new()
	classic_title.texture = load("res://assets/images/classic_title.png")
	classic_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	classic_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_title.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(classic_title)
	
	if classic_title.texture:
		var classic_title_width = 240
		var classic_title_ratio = classic_title.texture.get_height() / float(classic_title.texture.get_width())
		var classic_title_height = classic_title_width * classic_title_ratio
		classic_title.size = Vector2(classic_title_width, classic_title_height)
		classic_title.position = Vector2(270, 495)
		classic_title.pivot_offset = classic_title.size / 2
	
	classic_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("classic")
	)
	
	classic_title.mouse_entered.connect(func():
		if selected_mode != "classic":
			button_hover_sound.play()
			animate_hover(classic_image, classic_title, true)
	)
	classic_title.mouse_exited.connect(func():
		if selected_mode != "classic":
			animate_hover(classic_image, classic_title, false)
	)
	
	print("✅ Classic mode added")
	
	# === CHAOS MODE ===
	chaos_image = TextureRect.new()
	chaos_image.texture = load("res://assets/images/chaos_image.png")
	chaos_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chaos_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_image.size = Vector2(400, 290)
	chaos_image.position = Vector2(680, 210)
	chaos_image.pivot_offset = chaos_image.size / 2
	chaos_image.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chaos_image)
	
	chaos_image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("chaos")
	)
	
	chaos_image.mouse_entered.connect(func():
		if selected_mode != "chaos":
			button_hover_sound.play()
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_image.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)
	
	chaos_title = TextureRect.new()
	chaos_title.texture = load("res://assets/images/chaos_title.png")
	chaos_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	chaos_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chaos_title.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chaos_title)
	
	if chaos_title.texture:
		var chaos_title_width = 220
		var chaos_title_ratio = chaos_title.texture.get_height() / float(chaos_title.texture.get_width())
		var chaos_title_height = chaos_title_width * chaos_title_ratio
		chaos_title.size = Vector2(chaos_title_width, chaos_title_height)
		chaos_title.position = Vector2(780, 489)
		chaos_title.pivot_offset = chaos_title.size / 2
	
	chaos_title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button_click_sound.play()
			select_mode("chaos")
	)
	
	chaos_title.mouse_entered.connect(func():
		if selected_mode != "chaos":
			button_hover_sound.play()
			animate_hover(chaos_image, chaos_title, true)
	)
	chaos_title.mouse_exited.connect(func():
		if selected_mode != "chaos":
			animate_hover(chaos_image, chaos_title, false)
	)
	
	print("✅ Chaos mode added")
	
	# === START BUTTON ===
	start_button = TextureButton.new()
	start_button.texture_normal = load("res://assets/images/button_start.png")
	add_child(start_button)
	
	if start_button.texture_normal:
		var button_scale = 0.5
		start_button_base_scale = button_scale
		var texture_width = start_button.texture_normal.get_width()
		var texture_height = start_button.texture_normal.get_height()
		var scaled_width = texture_width * button_scale
		var scaled_height = texture_height * button_scale
		
		start_button.custom_minimum_size = Vector2(texture_width, texture_height)
		start_button.scale = Vector2(button_scale, button_scale)
		start_button.position = Vector2((viewport_size.x - scaled_width) / 2, 540)
		start_button.pivot_offset = Vector2(texture_width / 2, texture_height / 2)
	
	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(func(): 
		button_hover_sound.play()
		animate_button_hover(start_button, true)
	)
	start_button.mouse_exited.connect(func(): animate_button_hover(start_button, false))
	
	print("✅ Start button added")

func select_mode(mode: String):
	if selected_mode == "":
		classic_image.scale = Vector2(1.0, 1.0)
		classic_title.scale = Vector2(1.0, 1.0)
		chaos_image.scale = Vector2(1.0, 1.0)
		chaos_title.scale = Vector2(1.0, 1.0)
	
	selected_mode = mode
	
	if mode == "classic":
		animate_selection(classic_image, classic_title, true)
		animate_selection(chaos_image, chaos_title, false)
		print("🎪 Classic mode selected")
	else:
		animate_selection(chaos_image, chaos_title, true)
		animate_selection(classic_image, classic_title, false)
		print("🎪 Chaos mode selected")

func animate_hover(image: TextureRect, title: TextureRect, is_hovering: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	if is_hovering:
		tween.tween_property(image, "scale", Vector2(1.05, 1.05), 0.2)
		tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		tween.tween_property(image, "scale", Vector2(1.0, 1.0), 0.2)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.2)

func animate_selection(image: TextureRect, title: TextureRect, is_selected: bool):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	if is_selected:
		tween.tween_property(image, "scale", Vector2(1.1, 1.1), 0.3)
		tween.tween_property(title, "scale", Vector2(1.1, 1.1), 0.3)
	else:
		tween.tween_property(image, "scale", Vector2(0.9, 0.9), 0.3)
		tween.tween_property(title, "scale", Vector2(0.9, 0.9), 0.3)

func animate_button_hover(button: TextureButton, is_hovering: bool):
	var target_scale = Vector2(start_button_base_scale * 1.15, start_button_base_scale * 1.15) if is_hovering else Vector2(start_button_base_scale, start_button_base_scale)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", target_scale, 0.2)

func _on_start_pressed():
	if is_transitioning:
		return
	
	if selected_mode == "":
		print("⚠️ Please select a game mode first!")
		return
	
	# Play button click AND start game sound
	button_click_sound.play()
	start_game_sound.play()
	
	print("▶️ Starting game in mode:", selected_mode)
	is_transitioning = true
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
	
	if selected_mode == "chaos":
		get_tree().change_scene_to_file("res://scenes/game_world_chaotic.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_world_normal.tscn")
