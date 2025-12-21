extends Control

@onready var background: TextureRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var normal_mode_button: TextureButton = $ButtonContainer/NormalModeButton
@onready var chaotic_mode_button: TextureButton = $ButtonContainer/ChaoticModeButton
@onready var back_button: TextureButton = $BackButton
@onready var button_container = $ButtonContainer

var is_transitioning: bool = false
var button_base_scale: float = 0.6
var buttons_initialized: bool = false

# Game mode to pass to game scene
var selected_mode: String = "normal"

func _ready():
	print("=== Mode Selection Loading ===")
	
	# Load background (same as main menu)
	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture
		print("Background loaded")
	
	# Position everything
	update_layout()
	
	# Load button textures
	load_button_texture(normal_mode_button, "res://assets/images/button_play.png")  # Reuse play button for normal
	load_button_texture(chaotic_mode_button, "res://assets/images/button_settings.png")  # Temporary: reuse settings button
	load_button_texture(back_button, "res://assets/images/button_exit.png")  # Reuse exit button for back
	
	# Setup hover effects
	setup_button_hover_effects()
	
	buttons_initialized = true
	print("=== Mode Selection Ready ===")

func update_layout():
	var viewport_size = get_viewport_rect().size
	
	# Center title
	title_label.position.x = (viewport_size.x - title_label.size.x) / 2
	title_label.position.y = viewport_size.y * 0.15
	
	# Center button container
	button_container.position.x = (viewport_size.x - button_container.size.x) / 2
	button_container.position.y = viewport_size.y * 0.35
	
	# Position back button (bottom left)
	back_button.position.x = 50
	back_button.position.y = viewport_size.y - 150

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
		print("Button loaded: ", path)
	else:
		print("Button placeholder: ", path)
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
	normal_mode_button.mouse_entered.connect(func(): animate_button_hover(normal_mode_button, true))
	normal_mode_button.mouse_exited.connect(func(): animate_button_hover(normal_mode_button, false))
	
	chaotic_mode_button.mouse_entered.connect(func(): animate_button_hover(chaotic_mode_button, true))
	chaotic_mode_button.mouse_exited.connect(func(): animate_button_hover(chaotic_mode_button, false))
	
	back_button.mouse_entered.connect(func(): animate_button_hover(back_button, true))
	back_button.mouse_exited.connect(func(): animate_button_hover(back_button, false))

func animate_button_hover(button: TextureButton, is_hovering: bool):
	if not buttons_initialized:
		return
		
	var target_scale = Vector2(button_base_scale * 1.2, button_base_scale * 1.2) if is_hovering else Vector2(button_base_scale, button_base_scale)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", target_scale, 0.2)

func _on_normal_mode_pressed():
	if is_transitioning:
		return
	
	print("Normal Mode selected!")
	selected_mode = "normal"
	start_game()

func _on_chaotic_mode_pressed():
	if is_transitioning:
		return
	
	print("Chaotic Mode selected!")
	selected_mode = "chaotic"
	start_game()

func _on_back_pressed():
	if is_transitioning:
		return
	
	print("Back to main menu")
	is_transitioning = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func start_game():
	is_transitioning = true
	
	normal_mode_button.disabled = true
	chaotic_mode_button.disabled = true
	back_button.disabled = true
	
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
	
	print("Loading game scene with mode: ", selected_mode)
	
	# Load the appropriate game scene directly
	if selected_mode == "chaotic":
		get_tree().change_scene_to_file("res://scenes/game_world_chaotic.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_world_normal.tscn")
