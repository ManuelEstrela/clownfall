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

# ── Corner buttons (built entirely in code, corner placement) ──
var collection_button: TextureButton = null
var shop_button: TextureButton = null
var wishlist_button: TextureButton = null
var discord_button: TextureButton = null
var credits_button: TextureButton = null

const COLLECTION_BTN_SCALE: float = 0.55
const COLLECTION_BTN_MARGIN_X: float = 40.0
const COLLECTION_BTN_MARGIN_Y: float = 40.0
# Gap between neighbouring corner buttons, in final (scaled) pixels.
const CORNER_BTN_GAP: float = 14.0
# Placeholder size used until a real asset exists for a button.
const CORNER_BTN_PLACEHOLDER_SIZE := Vector2(160, 70)
# Path to the real asset once you have it — falls back to a placeholder
# ColorRect with a label if this file doesn't exist yet.
const COLLECTION_BTN_ASSET := "res://assets/images/button_collection.png"
# Drop a real asset at any of these paths and that button switches from the
# coloured placeholder to the artwork automatically — no code change needed.
const SHOP_BTN_ASSET := "res://assets/images/button_shop.png"
const WISHLIST_BTN_ASSET := "res://assets/images/button_wishlist.png"
const DISCORD_BTN_ASSET := "res://assets/images/button_discord.png"
const CREDITS_BTN_ASSET := "res://assets/images/button_credits.png"

# Opened by the Discord button. Swap for your real invite.
const DISCORD_URL := "https://discord.gg/your-invite-here"
# Opened by the Wishlist button. Fill in once you have a Steam app page.
const WISHLIST_URL := ""

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
	setup_corner_buttons()

	buttons_initialized = true

	# Setup menu controller after all buttons exist (now includes collection_button)
	menu_controller = MenuController.new()
	menu_controller.setup(
		self,
		[play_button, settings_button, collection_button, shop_button, exit_button],
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
#  CORNER BUTTONS — built fully in code
#
#  Bottom-left:  CLOWNS, SHOP
#  Bottom-right: WISHLIST, DISCORD, CREDITS
#
#  All five go through the same builder. Each falls back to a coloured
#  rectangle with its name on it when its asset is missing, so the new
#  ones are placeholders today and become artwork the moment a file
#  appears at the matching path.
# ══════════════════════════════════════════════════════════════
func setup_corner_buttons():
	collection_button = _build_corner_button("CLOWNS", COLLECTION_BTN_ASSET, Color(0.5, 0.3, 0.7, 0.9))
	shop_button = _build_corner_button("SHOP", SHOP_BTN_ASSET, Color(0.85, 0.45, 0.15, 0.9))
	wishlist_button = _build_corner_button("WISHLIST", WISHLIST_BTN_ASSET, Color(0.2, 0.45, 0.75, 0.9))
	discord_button = _build_corner_button("DISCORD", DISCORD_BTN_ASSET, Color(0.35, 0.40, 0.85, 0.9))
	credits_button = _build_corner_button("CREDITS", CREDITS_BTN_ASSET, Color(0.55, 0.25, 0.35, 0.9))

	collection_button.pressed.connect(_on_collection_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	wishlist_button.pressed.connect(_on_wishlist_pressed)
	discord_button.pressed.connect(_on_discord_pressed)
	credits_button.pressed.connect(_on_credits_pressed)

	position_corner_buttons()

func _build_corner_button(label_text: String, asset_path: String, placeholder_color: Color) -> TextureButton:
	var button = TextureButton.new()

	var texture = load(asset_path) if ResourceLoader.exists(asset_path) else null

	if texture:
		button.texture_normal = texture
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(texture.get_width(), texture.get_height())
	else:
		# Placeholder look until the real asset exists
		button.custom_minimum_size = CORNER_BTN_PLACEHOLDER_SIZE
		var placeholder = ColorRect.new()
		placeholder.color = placeholder_color
		placeholder.size = button.custom_minimum_size
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(placeholder)

		var label = Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = button.custom_minimum_size
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)

	button.pivot_offset = button.custom_minimum_size / 2.0
	button.scale = Vector2(COLLECTION_BTN_SCALE, COLLECTION_BTN_SCALE)
	add_child(button)

	SettingsManager.set_hover_cursor(button)
	button.mouse_entered.connect(func(): hover_sound.play())
	button.pressed.connect(func(): click_sound.play())
	return button

# Buttons are laid out in SCALED pixels. A TextureButton's `size` ignores
# `scale`, so using custom_minimum_size directly would leave gaps roughly
# twice as wide as intended at 0.55 scale.
func position_corner_buttons():
	if not collection_button:
		return

	var viewport_size = get_viewport_rect().size
	var row_y = viewport_size.y - COLLECTION_BTN_MARGIN_Y \
		- CORNER_BTN_PLACEHOLDER_SIZE.y * COLLECTION_BTN_SCALE

	# ── Bottom-left, running rightward ──
	var x = COLLECTION_BTN_MARGIN_X
	for button in [collection_button, shop_button]:
		if not button:
			continue
		button.position = Vector2(x, row_y)
		x += button.custom_minimum_size.x * COLLECTION_BTN_SCALE + CORNER_BTN_GAP

	# ── Bottom-right, laid out right to left so the row ends flush with
	#    the margin regardless of how wide each button turns out to be ──
	var right_x = viewport_size.x - COLLECTION_BTN_MARGIN_X
	for button in [credits_button, discord_button, wishlist_button]:
		if not button:
			continue
		var width = button.custom_minimum_size.x * COLLECTION_BTN_SCALE
		right_x -= width
		button.position = Vector2(right_x, row_y)
		right_x -= CORNER_BTN_GAP

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

	# Reposition the corner buttons if they already exist (e.g. on resize)
	position_corner_buttons()

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
	shop_button.disabled = true
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

func _on_shop_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")

func _on_wishlist_pressed():
	# Fill WISHLIST_URL in once the Steam page exists.
	if WISHLIST_URL != "":
		OS.shell_open(WISHLIST_URL)
	else:
		print("Wishlist URL not set yet - see WISHLIST_URL in main_menu.gd")

func _on_discord_pressed():
	OS.shell_open(DISCORD_URL)

func _on_credits_pressed():
	# Placeholder until the credits screen exists.
	print("Credits screen not built yet")

func _on_exit_pressed():
	if is_transitioning:
		return
	var tween = create_tween()
	tween.tween_property(bgm, "volume_db", -80, 0.5)
	await tween.finished
	get_tree().quit()
