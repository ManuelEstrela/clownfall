extends Control

@onready var background: TextureRect = $Background
@onready var game_title: TextureRect = $GameTitle
@onready var play_button: TextureButton = $ButtonContainer/PlayButton
@onready var settings_button: TextureButton = $ButtonContainer/SettingsButton
@onready var exit_button: TextureButton = $ButtonContainer/ExitButton
@onready var button_container = $ButtonContainer
@onready var bgm: AudioStreamPlayer = $AudioStreamPlayer

var is_transitioning: bool = false
var button_base_scale: float = 0.6
var buttons_initialized: bool = false

func _ready():
	print("=== Main Menu Loading ===")
	
	# Load background
	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture
		print("✅ Background loaded")
	else:
		print("⚠️ Background placeholder - using solid color")
		background.modulate = Color(0.2, 0.15, 0.25)
	
	# Load and setup game title
	var title_texture = load("res://assets/images/game_title.png")
	if title_texture:
		game_title.texture = title_texture
		game_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		game_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		print("✅ Game title loaded")
	else:
		print("⚠️ Game title placeholder")
		game_title.modulate = Color(0.8, 0.2, 0.2)
	
	# Position everything
	update_layout()
	
	# Load button textures with proper scaling
	load_button_texture(play_button, "res://assets/images/button_play.png")
	load_button_texture(settings_button, "res://assets/images/button_settings.png")
	load_button_texture(exit_button, "res://assets/images/button_exit.png")
	
	# Load and play background music
	var music = load("res://assets/sounds/landing_bgm.wav")
	if music:
		bgm.stream = music
		bgm.volume_db = 0
		bgm.play()
		print("✅ Background music playing")
	else:
		print("⚠️ Background music not found")
	
	# Add hover effects
	setup_button_hover_effects()
	
	buttons_initialized = true
	print("=== Main Menu Ready ===")

func update_layout():
	var viewport_size = get_viewport_rect().size
	
	# Scale title to 60% of screen width
	if game_title.texture:
		var texture_size = game_title.texture.get_size()
		var target_width = viewport_size.x * 0.6
		var scale_factor = target_width / texture_size.x
		var scaled_size = texture_size * scale_factor
		
		game_title.size = scaled_size
		game_title.position.x = (viewport_size.x - scaled_size.x) / 2
		game_title.position.y = viewport_size.y * 0.1  # 15% from top
	
	# Center button container
	button_container.position.x = (viewport_size.x - button_container.size.x) / 2
	button_container.position.y = viewport_size.y * 0.35  # Middle of screen

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		update_layout()

func load_button_texture(button: TextureButton, path: String):
	var texture = load(path)
	if texture:
		button.texture_normal = texture
		await get_tree().process_frame
		button.pivot_offset = button.size / 2
		button.scale = Vector2(button_base_scale, button_base_scale)
		print("✅ Button loaded: ", path)
	else:
		print("⚠️ Button placeholder: ", path)
		var placeholder = create_placeholder_button()
		button.add_child(placeholder)
		button.pivot_offset = button.size / 2
		button.scale = Vector2(button_base_scale, button_base_scale)

func create_placeholder_button() -> ColorRect:
	var rect = ColorRect.new()
	rect.size = Vector2(200, 60)
	rect.color = Color(0.8, 0.6, 0.2, 0.8)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func setup_button_hover_effects():
	play_button.mouse_entered.connect(func(): animate_button_hover(play_button, true))
	play_button.mouse_exited.connect(func(): animate_button_hover(play_button, false))
	
	settings_button.mouse_entered.connect(func(): animate_button_hover(settings_button, true))
	settings_button.mouse_exited.connect(func(): animate_button_hover(settings_button, false))
	
	exit_button.mouse_entered.connect(func(): animate_button_hover(exit_button, true))
	exit_button.mouse_exited.connect(func(): animate_button_hover(exit_button, false))

func animate_button_hover(button: TextureButton, is_hovering: bool):
	if not buttons_initialized:
		return
		
	var target_scale = Vector2(button_base_scale * 1.2, button_base_scale * 1.2) if is_hovering else Vector2(button_base_scale, button_base_scale)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", target_scale, 0.2)

func _on_play_pressed():
	if is_transitioning:
		return
	
	print("▶️ Play button pressed!")
	is_transitioning = true
	
	play_button.disabled = true
	settings_button.disabled = true
	exit_button.disabled = true
	
	fade_out_and_start_game()

func fade_out_and_start_game():
	var fade_duration = 1.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm, "volume_db", -80, fade_duration)
	
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = get_viewport_rect().size
	fade_overlay.z_index = 1000
	add_child(fade_overlay)
	
	tween.tween_property(fade_overlay, "color:a", 1.0, fade_duration)
	
	await tween.finished
	
	print("🎮 Loading game scene...")
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _on_settings_pressed():
	if is_transitioning:
		return
	
	print("⚙️ Settings button pressed!")
	print("Settings menu not implemented yet!")

func _on_exit_pressed():
	if is_transitioning:
		return
	
	print("👋 Exit button pressed!")
	
	var tween = create_tween()
	tween.tween_property(bgm, "volume_db", -80, 0.5)
	await tween.finished
	
	get_tree().quit()
