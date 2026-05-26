extends CanvasLayer

var is_paused: bool = false
var settings_menu_scene = preload("res://scenes/settings_menu.tscn")
var settings_menu_instance = null

# UI nodes built in code
var menu_sprite: Sprite2D = null
var btn_resume: TextureButton = null
var btn_restart: TextureButton = null
var btn_settings: TextureButton = null
var btn_mainmenu: TextureButton = null

# Sounds
var show_esc_sound: AudioStreamPlayer = null
var hide_esc_sound: AudioStreamPlayer = null
var click_sound: AudioStreamPlayer = null

# ── Layout constants ──────────────────────────────────────────
const MENU_POS       := Vector2(640, 370)
const MENU_SCALE     := Vector2(0.7, 0.7)

const BTN_RESUME_Y   := -80.0
const BTN_RESTART_Y  := 20.0
const BTN_SETTINGS_Y :=  120.0
const BTN_MAINMENU_Y := 220.0

const BTN_SCALE      := Vector2(0.85, 0.85)
# ─────────────────────────────────────────────────────────────

func _ready():
	visible = false
	setup_sounds()
	setup_ui()

	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.visual_changed.connect(_on_settings_changed)

func setup_sounds():
	show_esc_sound = AudioStreamPlayer.new()
	show_esc_sound.stream = load("res://assets/sounds/show_esc.mp3")
	show_esc_sound.volume_db = 0
	show_esc_sound.bus = "SFX"
	add_child(show_esc_sound)

	hide_esc_sound = AudioStreamPlayer.new()
	hide_esc_sound.stream = load("res://assets/sounds/hide_esc.mp3")
	hide_esc_sound.volume_db = 0
	hide_esc_sound.bus = "SFX"
	add_child(hide_esc_sound)

func setup_ui():
	# ── Background panel sprite ───────────────────────────────
	menu_sprite = Sprite2D.new()
	menu_sprite.texture = load("res://assets/images/pause/pause_menu.png")
	menu_sprite.z_index = 10
	menu_sprite.position = MENU_POS
	menu_sprite.scale = MENU_SCALE
	add_child(menu_sprite)

	# ── Buttons (children of sprite so they move with it) ────
	btn_resume   = _make_button("res://assets/images/pause/pause_button_resume.png",   Vector2(0, BTN_RESUME_Y))
	btn_restart  = _make_button("res://assets/images/pause/pause_button_restart.png",  Vector2(0, BTN_RESTART_Y))
	btn_settings = _make_button("res://assets/images/pause/pause_button_settings.png", Vector2(0, BTN_SETTINGS_Y))
	btn_mainmenu = _make_button("res://assets/images/pause/pause_button_mainmenu.png", Vector2(0, BTN_MAINMENU_Y))

	# Connect signals
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_mainmenu.pressed.connect(_on_menu_pressed)

	# ── Sounds ───────────────────────────────────────────────
	var hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	hover_sound.volume_db = -5
	hover_sound.bus = "SFX"
	add_child(hover_sound)

	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/button_click.mp3")
	click_sound.volume_db = 0
	click_sound.bus = "SFX"
	add_child(click_sound)

	# Hover on all buttons
	for btn in [btn_resume, btn_restart, btn_settings, btn_mainmenu]:
		btn.mouse_entered.connect(func(): hover_sound.play())

	# Click sound on settings only (restart and mainmenu handled in their functions)
	btn_settings.pressed.connect(func(): click_sound.play())

func _make_button(texture_path: String, offset: Vector2) -> TextureButton:
	var btn = TextureButton.new()
	btn.texture_normal = load(texture_path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var tex: Texture2D = btn.texture_normal
	var w := tex.get_width()  * BTN_SCALE.x
	var h := tex.get_height() * BTN_SCALE.y
	btn.custom_minimum_size = Vector2(w, h)
	btn.size = Vector2(w, h)

	btn.pivot_offset = Vector2(w / 2.0, h / 2.0)
	btn.position = offset - Vector2(w / 2.0, h / 2.0)

	btn.z_index = 20
	menu_sprite.add_child(btn)

	SettingsManager.set_hover_cursor(btn)
	_add_hover_effect(btn)
	return btn

func _add_hover_effect(btn: TextureButton):
	btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_menu_instance:
			close_settings_menu()
		elif is_paused:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game():
	is_paused = true
	visible = true
	get_tree().paused = true
	if show_esc_sound:
		show_esc_sound.play()

func resume_game():
	is_paused = false
	visible = false
	get_tree().paused = false
	if hide_esc_sound:
		hide_esc_sound.play()

func _on_resume_pressed():
	resume_game()

func _on_restart_pressed():
	if click_sound:
		click_sound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_settings_pressed():
	settings_menu_instance = settings_menu_scene.instantiate()
	add_child(settings_menu_instance)
	move_child(settings_menu_instance, get_child_count() - 1)
	menu_sprite.visible = false
	$Overlay.visible = true

func close_settings_menu():
	if settings_menu_instance:
		settings_menu_instance.queue_free()
		settings_menu_instance = null
		menu_sprite.visible = true

func _on_settings_changed():
	pass

func _on_menu_pressed():
	if click_sound:
		click_sound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
