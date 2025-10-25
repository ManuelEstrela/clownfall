extends Control

@onready var background: TextureRect = $Background
@onready var game_title: TextureRect = $GameTitle
@onready var play_button: TextureButton = $ButtonContainer/PlayButton
@onready var settings_button: TextureButton = $ButtonContainer/SettingsButton
@onready var exit_button: TextureButton = $ButtonContainer/ExitButton
@onready var bgm: AudioStreamPlayer = $AudioStreamPlayer

var is_transitioning: bool = false

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
	
	# Load game title
	var title_texture = load("res://assets/images/game_title.png")
	if title_texture:
		game_title.texture = title_texture
		print("✅ Game title loaded")
	else:
		print("⚠️ Game title placeholder")
		game_title.modulate = Color(0.8, 0.2, 0.2)
	
	# Load button textures
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
	
	print("=== Main Menu Ready ===")

func load_button_texture(button: TextureButton, path: String):
	var texture = load(path)
	if texture:
		button.texture_normal = texture
		print("✅ Button loaded: ", path)
	else:
		# Create placeholder colored rectangle
		print("⚠️ Button placeholder: ", path)
		var placeholder = create_placeholder_button()
		button.add_child(placeholder)

func create_placeholder_button() -> ColorRect:
	var rect = ColorRect.new()
	rect.size = Vector2(400, 120)
	rect.color = Color(0.8, 0.6, 0.2, 0.8)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func setup_button_hover_effects():
	# Play button
	play_button.mouse_entered.connect(func(): animate_button_hover(play_button, true))
	play_button.mouse_exited.connect(func(): animate_button_hover(play_button, false))
	
	# Settings button
	settings_button.mouse_entered.connect(func(): animate_button_hover(settings_button, true))
	settings_button.mouse_exited.connect(func(): animate_button_hover(settings_button, false))
	
	# Exit button
	exit_button.mouse_entered.connect(func(): animate_button_hover(exit_button, true))
	exit_button.mouse_exited.connect(func(): animate_button_hover(exit_button, false))

func animate_button_hover(button: TextureButton, is_hovering: bool):
	var target_scale = Vector2(1.1, 1.1) if is_hovering else Vector2.ONE
	
	# Create smooth scale animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", target_scale, 0.2)

func _on_play_pressed():
	if is_transitioning:
		return
	
	print("▶️ Play button pressed!")
	is_transitioning = true
	
	# Disable all buttons
	play_button.disabled = true
	settings_button.disabled = true
	exit_button.disabled = true
	
	# Fade out music and transition to game
	fade_out_and_start_game()

func fade_out_and_start_game():
	var fade_duration = 1.0
	
	# Fade out music
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm, "volume_db", -80, fade_duration)
	
	# Fade out screen
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = get_viewport_rect().size
	fade_overlay.z_index = 1000
	add_child(fade_overlay)
	
	tween.tween_property(fade_overlay, "color:a", 1.0, fade_duration)
	
	# Wait for fade to complete
	await tween.finished
	
	# Change scene
	print("🎮 Loading game scene...")
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _on_settings_pressed():
	if is_transitioning:
		return
	
	print("⚙️ Settings button pressed!")
	# TODO: Open settings menu
	# For now, just show a message
	print("Settings menu not implemented yet!")

func _on_exit_pressed():
	if is_transitioning:
		return
	
	print("👋 Exit button pressed!")
	
	# Fade out and quit
	var tween = create_tween()
	tween.tween_property(bgm, "volume_db", -80, 0.5)
	await tween.finished
	
	get_tree().quit()
