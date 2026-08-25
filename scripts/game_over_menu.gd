extends CanvasLayer

# ══════════════════════════════════════════════════════════════
#  GAME OVER PANEL
#
#  Same artwork and framing as the pause menu, but showing the run's
#  results instead of navigation. Populated by GameManager via
#  show_results() — this script never reads game state directly, so it
#  works identically in classic and chaos.
# ══════════════════════════════════════════════════════════════

var menu_sprite: Sprite2D = null
var btn_restart: TextureButton = null
var btn_mainmenu: TextureButton = null
var stat_labels: Dictionary = {}
var dim_overlay: ColorRect = null

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null
var menu_controller: MenuController

# Matches pause_menu.gd so both panels sit in the same place at the same
# size — they share the artwork and shouldn't visibly differ.
const MENU_POS   := Vector2(640, 370)
const MENU_SCALE := Vector2(0.7, 0.7)
const BTN_SCALE  := Vector2(0.85, 0.85)

# Positions are in the sprite's LOCAL space, so they're unaffected by
# MENU_SCALE — the whole panel scales together.
#
# No title constant: "GAME OVER" is part of the artwork, so drawing it
# here would double it up.
const STATS_TOP_Y    := -150.0
const STATS_ROW_GAP  := 62.0
const STATS_LABEL_X  := -195.0
const STATS_VALUE_X  := 75.0
const BTN_RESTART_Y  := 150.0
const BTN_MAINMENU_Y := 243.0

# How dark the world behind the panel gets.
const DIM_ALPHA := 0.55

const CLOWN_NAMES = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel",
	"Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]

# Rows, in display order. The jail is classic-only, so the arrests row is
# hidden rather than shown as zero when chaos has no jail.
const ROWS := ["score", "best", "reached", "arrests"]

var is_showing: bool = false
var _navigating_away: bool = false

func _ready():
	# Found by GameManager through this group, so no hard node path is
	# needed and both world scenes can place it wherever.
	add_to_group("game_over_menu")
	visible = false
	layer = 20
	# Runs while the tree is paused so the buttons still respond.
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_sounds()
	setup_ui()

func setup_sounds():
	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	hover_sound.volume_db = -5
	hover_sound.bus = "SFX"
	add_child(hover_sound)

	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/button_click.mp3")
	click_sound.bus = "SFX"
	add_child(click_sound)

func setup_ui():
	var font = load("res://assets/fonts/Clownfall-Regular.ttf")

	# Darkens the whole run behind the panel. Added BEFORE the sprite so it
	# sits underneath it, and it fades in with the panel rather than
	# snapping to black.
	dim_overlay = ColorRect.new()
	dim_overlay.color = Color(0, 0, 0, 0)
	dim_overlay.anchor_right = 1.0
	dim_overlay.anchor_bottom = 1.0
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_overlay)

	menu_sprite = Sprite2D.new()
	menu_sprite.texture = load("res://assets/images/pause/pause_menu.png")
	menu_sprite.z_index = 10
	menu_sprite.position = MENU_POS
	menu_sprite.scale = MENU_SCALE
	add_child(menu_sprite)

	# ── Stat rows ──
	# Label and value are separate nodes rather than one string so the
	# values line up in a column regardless of label length.
	for i in range(ROWS.size()):
		var key: String = ROWS[i]
		var y = STATS_TOP_Y + i * STATS_ROW_GAP

		var name_label = _make_stat_label(font, 40, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.position = Vector2(STATS_LABEL_X, y)
		name_label.size = Vector2(300, 50)
		name_label.text = key.to_upper() + ":"
		menu_sprite.add_child(name_label)

		var value_label = _make_stat_label(font, 40, HORIZONTAL_ALIGNMENT_LEFT)
		value_label.position = Vector2(STATS_VALUE_X, y)
		value_label.size = Vector2(280, 50)
		value_label.text = "-"
		menu_sprite.add_child(value_label)

		stat_labels[key] = {"name": name_label, "value": value_label}

	# ── Buttons ──
	btn_restart = _make_button(
		"res://assets/images/pause/pause_button_restart.png",
		Vector2(0, BTN_RESTART_Y))
	btn_mainmenu = _make_button(
		"res://assets/images/pause/pause_button_mainmenu.png",
		Vector2(0, BTN_MAINMENU_Y))

	btn_restart.pressed.connect(_on_restart_pressed)
	btn_mainmenu.pressed.connect(_on_mainmenu_pressed)

	menu_controller = MenuController.new()
	menu_controller.setup(
		self,
		[btn_restart, btn_mainmenu],
		Vector2(1.0, 1.0),
		Vector2(1.08, 1.08),
		hover_sound
	)

func _make_stat_label(font, size: int, align: int) -> Label:
	var label = Label.new()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.10, 0.15, 0.45))
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	return label

func _make_button(texture_path: String, offset: Vector2) -> TextureButton:
	var btn = TextureButton.new()
	btn.texture_normal = load(texture_path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var tex: Texture2D = btn.texture_normal
	var w := tex.get_width() * BTN_SCALE.x
	var h := tex.get_height() * BTN_SCALE.y
	btn.custom_minimum_size = Vector2(w, h)
	btn.size = Vector2(w, h)
	btn.pivot_offset = Vector2(w / 2.0, h / 2.0)
	btn.position = offset - Vector2(w / 2.0, h / 2.0)
	btn.z_index = 20
	menu_sprite.add_child(btn)

	SettingsManager.set_hover_cursor(btn)
	return btn

# ══════════════════════════════════════════════════════════════
#  SHOWING RESULTS
# ══════════════════════════════════════════════════════════════

# results: { score, best, peak_tier, arrests }
# Arrests is omitted by any mode without a jail, and that row hides itself.
func show_results(results: Dictionary):
	if is_showing:
		return
	is_showing = true

	var score: int = results.get("score", 0)
	var best: int = results.get("best", 0)

	stat_labels["score"].value.text = str(score)
	# best_score is updated before this runs, so a new record would show the
	# same number twice — call it out instead.
	if score >= best and score > 0:
		stat_labels["best"].value.text = "%d  (NEW!)" % best
	else:
		stat_labels["best"].value.text = str(best)

	var peak: int = clampi(results.get("peak_tier", 0), 0, CLOWN_NAMES.size() - 1)
	# Tier 0 means nothing ever merged, so naming Tessa would be misleading.
	if results.get("peak_tier", 0) <= 0:
		stat_labels["reached"].value.text = "-"
	else:
		stat_labels["reached"].value.text = CLOWN_NAMES[peak].to_upper()

	var show_arrests: bool = results.has("arrests")
	stat_labels["arrests"].name.visible = show_arrests
	stat_labels["arrests"].value.visible = show_arrests
	if show_arrests:
		stat_labels["arrests"].value.text = str(results.get("arrests", 0))

	visible = true
	get_tree().paused = true

	if menu_controller:
		menu_controller.reset_to_first()

	# Small pop so the panel arrives rather than blinking into place.
	menu_sprite.scale = MENU_SCALE * 0.75
	menu_sprite.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_sprite, "scale", MENU_SCALE, 0.35)
	tween.tween_property(menu_sprite, "modulate:a", 1.0, 0.25)
	if dim_overlay:
		tween.tween_property(dim_overlay, "color:a", DIM_ALPHA, 0.3)

func _process(delta):
	if is_showing and menu_controller:
		menu_controller.tick(delta)

func _input(event):
	if not is_showing or _navigating_away:
		return
	# Escape and the pause button are swallowed here — the run is over, so
	# there's nothing to pause or return to.
	if event.is_action_pressed("ui-pause") or event.is_action_pressed("ui-cancel"):
		get_viewport().set_input_as_handled()
		return
	if menu_controller and menu_controller.handle_input(event):
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

# ══════════════════════════════════════════════════════════════
#  ACTIONS
# ══════════════════════════════════════════════════════════════

func _on_restart_pressed():
	if _navigating_away:
		return
	_navigating_away = true
	if click_sound:
		click_sound.play()
	await get_tree().create_timer(0.1).timeout
	# Unpause BEFORE the scene swap — the flag is on the tree, not the
	# scene, so it would otherwise persist into the fresh run and freeze it.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_mainmenu_pressed():
	if _navigating_away:
		return
	_navigating_away = true
	if click_sound:
		click_sound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
