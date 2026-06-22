extends Control

# ══════════════════════════════════════════════════════════════
#  CLOWN COLLECTION SCREEN
# ══════════════════════════════════════════════════════════════
# Top row: scrollable (drag) row of clown cards
# Bottom row: 3 more clown cards (different style/size)
# Bottom-right: total clowns merged indicator (not interactive)
# Clicking a card: placeholder for lore (filled in later)

var settings: Node
var custom_font: Font

# Layout
const CARD_W := 160.0
const CARD_H := 220.0
const CARD_SPACING := 24.0

const BOTTOM_CARD_W := 200.0
const BOTTOM_CARD_H := 260.0
const BOTTOM_CARD_SPACING := 40.0

const TOP_ROW_Y := 140.0
const BOTTOM_ROW_Y := 420.0

# How many clowns go in the top scrollable row vs bottom row
const TOP_ROW_COUNT := 8
const BOTTOM_ROW_COUNT := 3

# Clown names matching CLOWNS array order in clown_ball.gd
const CLOWN_NAMES = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel",
	"Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]

# Maps clown index -> card art path. Clowns without dedicated art fall back to hazel_card.
const CARD_ASSET_PATHS = {
	0: "res://assets/images/collection/tessa_card.png",
	1: "res://assets/images/collection/twinkles_card.png",
	4: "res://assets/images/collection/hazel_card.png",
}
const FALLBACK_CARD_ASSET := "res://assets/images/collection/hazel_card.png"

var background: TextureRect
var back_button: TextureButton
var scroll_container: ScrollContainer
var top_row_box: HBoxContainer
var bottom_row_box: HBoxContainer
var total_merged_label: Label

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

func _ready():
	settings = get_node("/root/SettingsManager")
	custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	setup_sounds()
	setup_background()
	setup_back_button()
	setup_top_row()
	setup_bottom_row()
	setup_total_merged_indicator()

	print("Collection menu ready")

func setup_sounds():
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/sounds/button_click.mp3")
	click_sound.bus = "SFX"
	add_child(click_sound)

	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = load("res://assets/sounds/button_hover.mp3")
	hover_sound.volume_db = -5
	hover_sound.bus = "SFX"
	add_child(hover_sound)

func setup_background():
	background = TextureRect.new()
	background.texture = load("res://assets/images/collection/collection_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = get_viewport_rect().size
	add_child(background)

func setup_back_button():
	back_button = TextureButton.new()
	back_button.texture_normal = load("res://assets/images/button_back.png")
	back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_button.custom_minimum_size = Vector2(160, 55)
	back_button.position = Vector2(50, get_viewport_rect().size.y - 90)
	back_button.pressed.connect(_on_back_pressed)
	SettingsManager.set_hover_cursor(back_button)
	add_child(back_button)

# ══════════════════════════════════════════════════════════════
#  TOP ROW — scrollable by dragging
# ══════════════════════════════════════════════════════════════
func setup_top_row():
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(40, TOP_ROW_Y)
	scroll_container.size = Vector2(get_viewport_rect().size.x - 80, CARD_H + 20)
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Allow drag-to-scroll with mouse (Godot supports this by default with
	# a touch-like drag if scroll_deadzone is set low and follow_focus off)
	add_child(scroll_container)

	top_row_box = HBoxContainer.new()
	top_row_box.add_theme_constant_override("separation", int(CARD_SPACING))
	scroll_container.add_child(top_row_box)

	for i in TOP_ROW_COUNT:
		var card = _build_card(i, CARD_W, CARD_H)
		top_row_box.add_child(card)

	_enable_drag_scroll(scroll_container)

# Enables click-and-drag scrolling on a ScrollContainer (Godot doesn't do
# this natively with a mouse, only touch, so we implement it manually).
func _enable_drag_scroll(sc: ScrollContainer):
	var dragging = false
	var drag_start_mouse_x = 0.0
	var drag_start_scroll_x = 0.0

	sc.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_mouse_x = event.position.x
				drag_start_scroll_x = sc.scroll_horizontal
			else:
				dragging = false
		elif event is InputEventMouseMotion and dragging:
			var delta_x = event.position.x - drag_start_mouse_x
			sc.scroll_horizontal = int(drag_start_scroll_x - delta_x)
	)

# ══════════════════════════════════════════════════════════════
#  BOTTOM ROW — 3 cards, different style (bigger)
# ══════════════════════════════════════════════════════════════
func setup_bottom_row():
	bottom_row_box = HBoxContainer.new()
	bottom_row_box.add_theme_constant_override("separation", int(BOTTOM_CARD_SPACING))

	var total_width = BOTTOM_ROW_COUNT * BOTTOM_CARD_W + (BOTTOM_ROW_COUNT - 1) * BOTTOM_CARD_SPACING
	bottom_row_box.position = Vector2((get_viewport_rect().size.x - total_width) / 2.0 - 150, BOTTOM_ROW_Y)
	add_child(bottom_row_box)

	for i in BOTTOM_ROW_COUNT:
		var clown_index = TOP_ROW_COUNT + i
		var card = _build_card(clown_index, BOTTOM_CARD_W, BOTTOM_CARD_H)
		bottom_row_box.add_child(card)

# ══════════════════════════════════════════════════════════════
#  CARD BUILDER — shared by top and bottom rows
# ══════════════════════════════════════════════════════════════
func _build_card(clown_index: int, width: float, height: float) -> Control:
	var card_btn = TextureButton.new()
	card_btn.custom_minimum_size = Vector2(width, height)
	card_btn.ignore_texture_size = true
	card_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var card_art_path: String = CARD_ASSET_PATHS.get(clown_index, FALLBACK_CARD_ASSET)
	card_btn.texture_normal = load(card_art_path)

	SettingsManager.set_hover_cursor(card_btn)
	card_btn.mouse_entered.connect(func():
		hover_sound.play()
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card_btn, "scale", Vector2(1.06, 1.06), 0.15)
	)
	card_btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(card_btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	card_btn.pressed.connect(func():
		click_sound.play()
		_on_card_clicked(clown_index)
	)

	# Name label, overlaid near the top-middle of the card art
	var name_label = Label.new()
	name_label.text = CLOWN_NAMES[clown_index]
	if custom_font:
		name_label.add_theme_font_override("font", custom_font)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(width, 24)
	name_label.position = Vector2(0, height * 0.55)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(name_label)

	# Progress bar + text, near the bottom of the card
	var progress_data = _get_progress_for(clown_index)

	var bar_tex = TextureRect.new()
	bar_tex.texture = load("res://assets/images/collection/progress_bar.png")
	bar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_tex.size = Vector2(width * 0.8, 20)
	bar_tex.position = Vector2(width * 0.1, height * 0.8)
	card_btn.add_child(bar_tex)

	var progress_label = Label.new()
	progress_label.text = str(progress_data.total_merges) + " / " + str(progress_data.goal)
	if custom_font:
		progress_label.add_theme_font_override("font", custom_font)
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(1, 1, 1))
	progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	progress_label.add_theme_constant_override("outline_size", 3)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.size = bar_tex.size
	progress_label.position = bar_tex.position
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(progress_label)

	# Stars-on-goal indicator, slightly above/overlapping the bar
	var stars_label = Label.new()
	stars_label.text = "★ " + str(progress_data.stars)
	if custom_font:
		stars_label.add_theme_font_override("font", custom_font)
	stars_label.add_theme_font_size_override("font_size", 14)
	stars_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	stars_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	stars_label.add_theme_constant_override("outline_size", 3)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars_label.size = Vector2(width * 0.4, 18)
	stars_label.position = Vector2(width * 0.55, height * 0.74)
	stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(stars_label)

	return card_btn

func _get_progress_for(clown_index: int) -> Dictionary:
	var total_merges = 0
	if settings and clown_index < settings.merges_per_clown.size():
		total_merges = settings.merges_per_clown[clown_index]

	var goal_data = ClownCollectionData.get_current_goal(clown_index, total_merges)
	return {
		"total_merges": total_merges,
		"goal": goal_data.goal,
		"stars": goal_data.stars
	}

# ══════════════════════════════════════════════════════════════
#  BOTTOM-RIGHT — total clowns merged (static display, not a button)
# ══════════════════════════════════════════════════════════════
func setup_total_merged_indicator():
	var total = 0
	if settings:
		for count in settings.merges_per_clown:
			total += count

	var ticket_bg = TextureRect.new()
	# Placeholder — swap with the real ticket asset once provided
	ticket_bg.custom_minimum_size = Vector2(160, 90)
	ticket_bg.size = Vector2(160, 90)
	var vp_size = get_viewport_rect().size
	ticket_bg.position = Vector2(vp_size.x - 200, vp_size.y - 130)
	add_child(ticket_bg)

	total_merged_label = Label.new()
	total_merged_label.text = "TOTAL MERGED\n" + str(total)
	if custom_font:
		total_merged_label.add_theme_font_override("font", custom_font)
	total_merged_label.add_theme_font_size_override("font_size", 18)
	total_merged_label.add_theme_color_override("font_color", Color(1, 1, 1))
	total_merged_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	total_merged_label.add_theme_constant_override("outline_size", 4)
	total_merged_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_merged_label.size = ticket_bg.size
	total_merged_label.position = ticket_bg.position
	add_child(total_merged_label)

# ══════════════════════════════════════════════════════════════
#  CARD CLICK — lore placeholder (fleshed out later)
# ══════════════════════════════════════════════════════════════
func _on_card_clicked(clown_index: int):
	print("Clicked on: ", CLOWN_NAMES[clown_index], " (lore screen coming later)")
	# TODO: open lore panel/popup here

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
