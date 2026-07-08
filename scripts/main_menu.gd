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

var menu_controller: MenuController
var hover_sound: AudioStreamPlayer = null
var click_sound: AudioStreamPlayer = null

# ── Collection button (built entirely in code, corner placement) ──
var collection_button: TextureButton = null
const COLLECTION_BTN_SCALE: float = 0.55
const COLLECTION_BTN_MARGIN_X: float = 40.0
const COLLECTION_BTN_MARGIN_Y: float = 40.0
# Path to the real asset once you have it — falls back to a placeholder
# ColorRect with a label if this file doesn't exist yet.
const COLLECTION_BTN_ASSET := "res://assets/images/button_collection.png"

func _ready():
	print("=== Main Menu Loading ===")

	var bg_texture = load("res://assets/images/landing_background.png")
	if bg_texture:
		background.texture = bg_texture
	else:
		background.modulate = Color(0.2, 0.15, 0.25)

	var title_texture = load("res://assets/images/game_title.png")
	if title_texture:
		game_title.texture = title_texture
		game_title.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		game_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		game_title.modulate = Color(0.8, 0.2, 0.2)

	update_layout()

	load_button_texture(play_button, "res://assets/images/button_play.png")
	load_button_texture(settings_button, "res://assets/images/button_settings.png")
	load_button_texture(exit_button, "res://assets/images/button_exit.png")

	SettingsManager.set_hover_cursor(play_button)
	SettingsManager.set_hover_cursor(settings_button)
	SettingsManager.set_hover_cursor(exit_button)

	var music = load("res://assets/sounds/landing_bgm_2.mp3")
	if music:
		music.loop = true
		bgm.stream = music
		bgm.volume_db = 0
		bgm.bus = "Music"
		bgm.play()

	setup_sounds()
	setup_collection_button()

	buttons_initialized = true

	# Setup menu controller after all buttons exist (now includes collection_button)
	menu_controller = MenuController.new()
	menu_controller.setup(
		self,
		[play_button, settings_button, collection_button, exit_button],
		Vector2(button_base_scale, button_base_scale),
		Vector2(button_base_scale * 1.2, button_base_scale * 1.2),
		hover_sound
	)

	print("=== Main Menu Ready ===")

func setup_sounds():
	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	hover_sound.volume_db = -5
	hover_sound.bus = "SFX"
	add_child(hover_sound)

	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/button_click.mp3")
	click_sound.volume_db = 0
	click_sound.bus = "SFX"
	add_child(click_sound)

	play_button.pressed.connect(func(): click_sound.play())
	settings_button.pressed.connect(func(): click_sound.play())
	exit_button.pressed.connect(func(): click_sound.play())

# ══════════════════════════════════════════════════════════════
#  COLLECTION BUTTON — built fully in code, corner placement
# ══════════════════════════════════════════════════════════════
func setup_collection_button():
	collection_button = TextureButton.new()

	var texture = load(COLLECTION_BTN_ASSET) if ResourceLoader.exists(COLLECTION_BTN_ASSET) else null

	if texture:
		collection_button.texture_normal = texture
		collection_button.ignore_texture_size = true
		collection_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		collection_button.custom_minimum_size = Vector2(texture.get_width(), texture.get_height())
	else:
		# Placeholder look until the real asset exists
		collection_button.custom_minimum_size = Vector2(160, 70)
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.5, 0.3, 0.7, 0.9)
		placeholder.size = collection_button.custom_minimum_size
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		collection_button.add_child(placeholder)

		var label = Label.new()
		label.text = "CLOWNS"
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = collection_button.custom_minimum_size
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		collection_button.add_child(label)

	# Bottom-left corner placement
	var viewport_size = get_viewport_rect().size
	collection_button.pivot_offset = collection_button.custom_minimum_size / 2.0
	collection_button.scale = Vector2(COLLECTION_BTN_SCALE, COLLECTION_BTN_SCALE)
	collection_button.position = Vector2(
		COLLECTION_BTN_MARGIN_X,
		viewport_size.y - COLLECTION_BTN_MARGIN_Y - collection_button.custom_minimum_size.y * COLLECTION_BTN_SCALE
	)

	add_child(collection_button)

	SettingsManager.set_hover_cursor(collection_button)
	collection_button.mouse_entered.connect(func(): hover_sound.play())
	collection_button.pressed.connect(func(): click_sound.play())
	collection_button.pressed.connect(_on_collection_pressed)

func update_layout():
	var viewport_size = get_viewport_rect().size

	if game_title.texture:
		var texture_size = game_title.texture.get_size()
		var target_width = viewport_size.x * 0.6
		var scale_factor = target_width / texture_size.x
		var scaled_size = texture_size * scale_factor
		game_title.size = scaled_size * 1.3
		game_title.position.x = (viewport_size.x - scaled_size.x) / 2 - 370
		game_title.position.y = viewport_size.y * 0.09

	button_container.position.x = (viewport_size.x - button_container.size.x) / 2
	button_container.position.y = viewport_size.y * 0.35

	# Reposition collection button if it already exists (e.g. on resize)
	if collection_button:
		collection_button.position = Vector2(
			COLLECTION_BTN_MARGIN_X,
			viewport_size.y - COLLECTION_BTN_MARGIN_Y - collection_button.custom_minimum_size.y * COLLECTION_BTN_SCALE
		)

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
	else:
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

func _process(delta):
	if menu_controller:
		menu_controller.tick(delta)

func _input(event):
	if is_transitioning:
		return
	if menu_controller and menu_controller.handle_input(event):
		get_viewport().set_input_as_handled()

func _on_play_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	play_button.disabled = true
	settings_button.disabled = true
	exit_button.disabled = true
	collection_button.disabled = true
	fade_out_and_go_to_mode_selection()

func fade_out_and_go_to_mode_selection():
	var fade_duration = 0.5
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
	get_tree().change_scene_to_file("res://scenes/mode_selection.tscn")

func _on_settings_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	play_button.disabled = true
	settings_button.disabled = true
	exit_button.disabled = true
	collection_button.disabled = true
	var fade_duration = 0.5
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
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_collection_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	play_button.disabled = true
	settings_button.disabled = true
	exit_button.disabled = true
	collection_button.disabled = true
	var fade_duration = 0.5
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
	get_tree().change_scene_to_file("res://scenes/CollectionMenu.tscn")

func _on_exit_pressed():
	if is_transitioning:
		return
	var tween = create_tween()
	tween.tween_property(bgm, "volume_db", -80, 0.5)
	await tween.finished
	get_tree().quit()
