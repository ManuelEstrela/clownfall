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

# ── Layout — tweak these freely ─────────────────────────────────
const CARD_W := 190.0
const CARD_H := 260.0
const CARD_SPACING := 24.0
const TOP_ROW_END_PADDING := 40.0
# Left margin before the first card in the scrollable row
const TOP_ROW_START_MARGIN := 16.0

const BOTTOM_CARD_W := 250.0
const BOTTOM_CARD_H := 330.0
const BOTTOM_CARD_SPACING := 40.0
const BOTTOM_ROW_X_OFFSET := 40.0

const TOP_ROW_Y := 100.0
const BOTTOM_ROW_Y := 385.0

const TOP_ROW_Y_OFFSETS := [0.0, -14.0, 8.0, -8.0, 14.0, -10.0, 6.0, -6.0]

# ── PROGRESS BAR position/size (TOP ROW cards) ──────────────────
# BAR_Y_FRACTION: vertical position of the bar inside the card.
#   0.0 = very top of the card, 1.0 = very bottom. Increase to move
#   the bar DOWN, decrease to move it UP.
const BAR_Y_FRACTION := 0.5
# Bar width as a fraction of the card's width (0.8 = 80% of card width,
# centered). Increase to make the bar WIDER, decrease for NARROWER.
const BAR_WIDTH_FRACTION := 0.8
# Bar height in pixels for the TOP ROW cards specifically.
const BAR_HEIGHT := 150.0
# Font size of the "X / Y" progress text on TOP ROW cards.
const PROGRESS_FONT := 14
# Nudges the "X / Y" text up/down relative to the bar texture, on the
# TOP ROW cards specifically. Negative = up, positive = down.
const PROGRESS_TEXT_Y_OFFSET := 63.0
# Same nudge, but for the BOTTOM ROW cards — independent from the
# top row so you can position each row's numbers separately.
const BOTTOM_PROGRESS_TEXT_Y_OFFSET := 84.0

# ── STARS position/size — TOP ROW cards ──────────────────────────
# STARS_X_FRACTION: horizontal position (0.0 = left edge of card,
#   1.0 = right edge). Increase to move stars RIGHT, decrease for LEFT.
const STARS_X_FRACTION := 0.42
# STARS_Y_FRACTION: vertical position (0.0 = top, 1.0 = bottom).
#   Increase to move stars DOWN, decrease to move UP.
const STARS_Y_FRACTION := 0.67
# Font size of the "★ N" stars text on TOP ROW cards.
const STARS_FONT := 14

# ── STARS position/size — BOTTOM ROW cards (independent) ─────────
const BOTTOM_STARS_X_FRACTION := 0.44
const BOTTOM_STARS_Y_FRACTION := 0.68

# ── BOTTOM ROW cards have their own independent sizing ───────────
# (bigger cards, so bar/stars get bigger pixel values too)
const BOTTOM_BAR_HEIGHT := 200.0
const BOTTOM_PROGRESS_FONT := 20
const BOTTOM_STARS_FONT := 20

# ── Scrollbar — separate dedicated bar, NOT the container's built-in one ──
const SCROLLBAR_WIDTH := 300.0
const SCROLLBAR_HEIGHT := 10.0
const SCROLLBAR_Y_GAP := -65.0

# How far (in pixels) the mouse must move before a press counts as a
# drag instead of a click. Keeps short clicks opening the lore screen
# while longer drags scroll the row.
const CLICK_VS_DRAG_THRESHOLD := 6.0

const TOP_ROW_COUNT := 8
const BOTTOM_ROW_COUNT := 3

const CLOWN_NAMES = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel",
	"Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]

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
var custom_scrollbar_track: ColorRect
var custom_scrollbar_grabber: ColorRect

var click_sound: AudioStreamPlayer = null
var hover_sound: AudioStreamPlayer = null

# Drag-scroll state shared across the whole top row
var _dragging: bool = false
var _drag_start_mouse_x: float = 0.0
var _drag_start_scroll_x: float = 0.0
var _drag_distance: float = 0.0
var _pending_click_card: TextureRect = null  # the card "armed" to click if drag stays small

# ── Momentum scrolling ──────────────────────────────────────────
# Tracks recent mouse movement to compute a release velocity, then
# decelerates smoothly instead of stopping the instant the mouse is
# released — gives the row a "thrown" feel like native mobile lists.
var _velocity: float = 0.0          # pixels/second, signed
var _last_mouse_x: float = 0.0
var _last_motion_time: float = 0.0
var _momentum_active: bool = false
const MOMENTUM_FRICTION := 4.0      # higher = stops sooner
const MOMENTUM_MIN_VELOCITY := 40.0 # below this, momentum just stops
const MOMENTUM_MAX_VELOCITY := 4000.0  # clamp so a huge flick doesn't fly off screen

# How many pixels to overshoot when bouncing at an edge, and how
# long the snap-back animation takes.
const EDGE_JIGGLE_AMOUNT := 18.0
const EDGE_JIGGLE_DURATION := 0.22

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

# Pressing Escape (or Circle on a PS4 controller, since ui_cancel is
# mapped to both) returns to the main menu, same pattern as your
# other menu screens.
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _process(delta: float):
	if not _momentum_active:
		return

	# Apply current velocity to scroll position
	scroll_container.scroll_horizontal -= int(_velocity * delta)

	# Decelerate smoothly toward zero
	_velocity = move_toward(_velocity, 0.0, MOMENTUM_FRICTION * 1000.0 * delta)

	# Stop once slow enough, or if we've hit either scroll edge
	var h_bar = scroll_container.get_h_scroll_bar()
	var max_scroll = h_bar.max_value - h_bar.page
	var hit_left_edge = scroll_container.scroll_horizontal <= 0 and _velocity > 0
	var hit_right_edge = scroll_container.scroll_horizontal >= max_scroll and _velocity < 0

	if abs(_velocity) < MOMENTUM_MIN_VELOCITY or hit_left_edge or hit_right_edge:
		_momentum_active = false
		_velocity = 0.0
		_jiggle_if_at_edge()

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
	# gui_input only fires for mouse events within this Control's OWN
	# rect, regardless of clip_contents, so it must cover the full
	# visual extent of every card including downward Y offsets.
	var max_positive_offset = 0.0
	for off in TOP_ROW_Y_OFFSETS:
		if off > max_positive_offset:
			max_positive_offset = off
	var required_height = 30.0 + 20.0 + max_positive_offset + CARD_H + 20.0
	scroll_container.size = Vector2(get_viewport_rect().size.x - 80, required_height)
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.clip_contents = false
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Hide the container's built-in scrollbar — we draw our own below.
	var hidden_style = StyleBoxEmpty.new()
	scroll_container.get_h_scroll_bar().add_theme_stylebox_override("scroll", hidden_style)
	scroll_container.get_h_scroll_bar().add_theme_stylebox_override("grabber", hidden_style)
	scroll_container.get_h_scroll_bar().add_theme_stylebox_override("grabber_highlight", hidden_style)
	scroll_container.get_h_scroll_bar().add_theme_stylebox_override("grabber_pressed", hidden_style)
	scroll_container.get_h_scroll_bar().modulate.a = 0.0

	add_child(scroll_container)

	top_row_box = HBoxContainer.new()
	top_row_box.add_theme_constant_override("separation", int(CARD_SPACING))
	top_row_box.position = Vector2(0, 30)
	scroll_container.add_child(top_row_box)

	# Left margin before the first card
	var start_spacer = Control.new()
	start_spacer.custom_minimum_size = Vector2(TOP_ROW_START_MARGIN, 1)
	top_row_box.add_child(start_spacer)

	for i in TOP_ROW_COUNT:
		var card = _build_card(i, CARD_W, CARD_H, false)

		var y_offset = 0.0
		if i < TOP_ROW_Y_OFFSETS.size():
			y_offset = TOP_ROW_Y_OFFSETS[i]

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(CARD_W, CARD_H + 40)
		wrapper.clip_contents = false
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(0, 20 + y_offset)
		wrapper.add_child(card)

		top_row_box.add_child(wrapper)

	var end_spacer = Control.new()
	end_spacer.custom_minimum_size = Vector2(TOP_ROW_END_PADDING, 1)
	top_row_box.add_child(end_spacer)

	scroll_container.gui_input.connect(_on_top_row_input)
	scroll_container.mouse_exited.connect(func():
		if _pending_click_card:
			_set_card_hover(_pending_click_card, false)
			_pending_click_card = null
	)

	_setup_custom_scrollbar(scroll_container)

# Single handler for everything in the top row: hover, click, and drag.
func _on_top_row_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_momentum_active = false  # grabbing the row cancels any momentum
			_drag_distance = 0.0
			_drag_start_mouse_x = event.global_position.x
			_drag_start_scroll_x = scroll_container.scroll_horizontal
			_last_mouse_x = event.global_position.x
			_last_motion_time = Time.get_ticks_msec() / 1000.0
			_velocity = 0.0
		else:
			_dragging = false
			if _drag_distance < CLICK_VS_DRAG_THRESHOLD:
				var card = _find_card_at(event.position)
				if card:
					click_sound.play()
					_on_card_clicked(card.get_meta("clown_index"))
			else:
				# Hand off to momentum scrolling using the last tracked velocity
				if abs(_velocity) > MOMENTUM_MIN_VELOCITY:
					_momentum_active = true
				else:
					_jiggle_if_at_edge()

	elif event is InputEventMouseMotion:
		if _dragging:
			var now = Time.get_ticks_msec() / 1000.0
			var dt = now - _last_motion_time
			if dt > 0.0:
				var instant_velocity = (event.global_position.x - _last_mouse_x) / dt
				instant_velocity = clampf(instant_velocity, -MOMENTUM_MAX_VELOCITY, MOMENTUM_MAX_VELOCITY)
				_velocity = lerp(_velocity, instant_velocity, 0.5)
			_last_mouse_x = event.global_position.x
			_last_motion_time = now

			var delta_x = event.global_position.x - _drag_start_mouse_x
			_drag_distance = max(_drag_distance, abs(delta_x))
			scroll_container.scroll_horizontal = int(_drag_start_scroll_x - delta_x)

			if _pending_click_card:
				_set_card_hover(_pending_click_card, false)
				_pending_click_card = null
		else:
			var card = _find_card_at(event.position)
			if card != _pending_click_card:
				if _pending_click_card:
					_set_card_hover(_pending_click_card, false)
				if card:
					_set_card_hover(card, true)
				_pending_click_card = card

# Finds which card's rect (in screen space) contains the given mouse
# position. Uses global_position directly since that's always the
# node's actual top-left corner — pivot_offset never affects this.
func _find_card_at(local_pos: Vector2) -> TextureRect:
	var mouse_pos = get_viewport().get_mouse_position()
	for wrapper in top_row_box.get_children():
		if not (wrapper is Control):
			continue
		for child in wrapper.get_children():
			if child is TextureRect and child.has_meta("clown_index"):
				# Card may be scaled up slightly on hover — grow the
				# hit-test rect symmetrically around its own center to
				# match, rather than just from the top-left corner.
				var unscaled_pos = child.global_position
				var unscaled_size = child.size
				var center = unscaled_pos + unscaled_size / 2.0
				var scaled_size = unscaled_size * child.scale
				var scaled_pos = center - scaled_size / 2.0

				var card_global_rect = Rect2(scaled_pos, scaled_size)
				if card_global_rect.has_point(mouse_pos):
					return child
	return null

func _set_card_hover(card: TextureRect, hovering: bool):
	if not is_instance_valid(card):
		return
	if hovering:
		hover_sound.play()
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.15)
		SettingsManager.set_hover_cursor(scroll_container)
	else:
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15)

# If the row was dragged hard enough to be sitting at (or very near)
# either end, play a small overshoot-and-snap-back bounce for feel.
func _jiggle_if_at_edge():
	var h_bar = scroll_container.get_h_scroll_bar()
	var max_scroll = h_bar.max_value - h_bar.page
	if max_scroll <= 0:
		return

	var at_left_edge = scroll_container.scroll_horizontal <= 0
	var at_right_edge = scroll_container.scroll_horizontal >= max_scroll

	if not (at_left_edge or at_right_edge):
		return

	var overshoot = -EDGE_JIGGLE_AMOUNT if at_left_edge else EDGE_JIGGLE_AMOUNT
	var original_x = top_row_box.position.x

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(top_row_box, "position:x", original_x + overshoot, EDGE_JIGGLE_DURATION * 0.4)
	tw.tween_property(top_row_box, "position:x", original_x, EDGE_JIGGLE_DURATION * 0.6)

# ── Custom-drawn scrollbar: short, centered, sits BELOW the cards ──
func _setup_custom_scrollbar(sc: ScrollContainer):
	var viewport_w = get_viewport_rect().size.x
	var bar_y = sc.position.y + sc.size.y + SCROLLBAR_Y_GAP
	var bar_x = (viewport_w - SCROLLBAR_WIDTH) / 2.0

	custom_scrollbar_track = ColorRect.new()
	custom_scrollbar_track.color = Color(0.05, 0.15, 0.35)
	custom_scrollbar_track.size = Vector2(SCROLLBAR_WIDTH, SCROLLBAR_HEIGHT)
	custom_scrollbar_track.position = Vector2(bar_x, bar_y)
	custom_scrollbar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(custom_scrollbar_track)

	custom_scrollbar_grabber = ColorRect.new()
	custom_scrollbar_grabber.color = Color(0.4, 0.65, 0.95)
	custom_scrollbar_grabber.size = Vector2(SCROLLBAR_WIDTH * 0.3, SCROLLBAR_HEIGHT)
	custom_scrollbar_grabber.position = Vector2(bar_x, bar_y)
	custom_scrollbar_grabber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(custom_scrollbar_grabber)

	sc.get_h_scroll_bar().value_changed.connect(func(_v):
		_update_custom_scrollbar(sc)
	)
	call_deferred("_update_custom_scrollbar", sc)

func _update_custom_scrollbar(sc: ScrollContainer):
	if not custom_scrollbar_grabber:
		return
	var h_bar = sc.get_h_scroll_bar()
	var max_scroll = h_bar.max_value - h_bar.page
	if max_scroll <= 0:
		custom_scrollbar_grabber.visible = false
		return
	custom_scrollbar_grabber.visible = true

	var scroll_fraction = clampf(sc.scroll_horizontal / max_scroll, 0.0, 1.0)
	var track_x = custom_scrollbar_track.position.x
	var travel_range = SCROLLBAR_WIDTH - custom_scrollbar_grabber.size.x
	custom_scrollbar_grabber.position.x = track_x + scroll_fraction * travel_range

# ══════════════════════════════════════════════════════════════
#  BOTTOM ROW — 3 cards, different style (bigger). These remain
#  TextureButtons since they're not inside a scrolling container,
#  so there's no event-swallowing conflict to worry about here.
# ══════════════════════════════════════════════════════════════
func setup_bottom_row():
	bottom_row_box = HBoxContainer.new()
	bottom_row_box.add_theme_constant_override("separation", int(BOTTOM_CARD_SPACING))

	var total_width = BOTTOM_ROW_COUNT * BOTTOM_CARD_W + (BOTTOM_ROW_COUNT - 1) * BOTTOM_CARD_SPACING
	bottom_row_box.position = Vector2(
		(get_viewport_rect().size.x - total_width) / 2.0 - 150 + BOTTOM_ROW_X_OFFSET,
		BOTTOM_ROW_Y
	)
	add_child(bottom_row_box)

	for i in BOTTOM_ROW_COUNT:
		var clown_index = TOP_ROW_COUNT + i
		var card = _build_bottom_card(clown_index, BOTTOM_CARD_W, BOTTOM_CARD_H)

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(BOTTOM_CARD_W, BOTTOM_CARD_H)
		wrapper.clip_contents = false
		card.position = Vector2(0, 0)
		wrapper.add_child(card)

		bottom_row_box.add_child(wrapper)

func _build_bottom_card(clown_index: int, width: float, height: float) -> TextureButton:
	var card_btn = TextureButton.new()
	card_btn.custom_minimum_size = Vector2(width, height)
	card_btn.ignore_texture_size = true
	card_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	card_btn.pivot_offset = Vector2(width / 2.0, height / 2.0)

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

	_add_card_overlays(card_btn, clown_index, width, height, true)
	return card_btn

# ══════════════════════════════════════════════════════════════
#  TOP-ROW CARD BUILDER — plain TextureRect, input handled by the
#  ScrollContainer's gui_input instead of the node itself.
# ══════════════════════════════════════════════════════════════
func _build_card(clown_index: int, width: float, height: float, is_bottom_row: bool) -> TextureRect:
	var card = TextureRect.new()
	card.custom_minimum_size = Vector2(width, height)
	card.size = Vector2(width, height)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.pivot_offset = Vector2(width / 2.0, height / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # events handled by ScrollContainer, not this node
	card.set_meta("clown_index", clown_index)

	var card_art_path: String = CARD_ASSET_PATHS.get(clown_index, FALLBACK_CARD_ASSET)
	card.texture = load(card_art_path)

	_add_card_overlays(card, clown_index, width, height, is_bottom_row)
	return card

# Shared progress bar / stars overlay builder for both card types.
# Width/height/font values below come from the constants documented
# at the top of the file — see BAR_Y_FRACTION, BAR_WIDTH_FRACTION,
# BAR_HEIGHT, PROGRESS_FONT, PROGRESS_TEXT_Y_OFFSET, STARS_X_FRACTION,
# STARS_Y_FRACTION, STARS_FONT (top row) and BOTTOM_BAR_HEIGHT,
# BOTTOM_PROGRESS_FONT, BOTTOM_PROGRESS_TEXT_Y_OFFSET,
# BOTTOM_STARS_FONT, BOTTOM_STARS_X_FRACTION, BOTTOM_STARS_Y_FRACTION
# (bottom row).
func _add_card_overlays(card: Control, clown_index: int, width: float, height: float, is_bottom_row: bool):
	var progress_data = _get_progress_for(clown_index)

	var bar_height: float = BOTTOM_BAR_HEIGHT if is_bottom_row else BAR_HEIGHT
	var progress_font: int = BOTTOM_PROGRESS_FONT if is_bottom_row else PROGRESS_FONT
	var progress_text_y_offset: float = BOTTOM_PROGRESS_TEXT_Y_OFFSET if is_bottom_row else PROGRESS_TEXT_Y_OFFSET
	var stars_font: int = BOTTOM_STARS_FONT if is_bottom_row else STARS_FONT
	var stars_x_fraction: float = BOTTOM_STARS_X_FRACTION if is_bottom_row else STARS_X_FRACTION
	var stars_y_fraction: float = BOTTOM_STARS_Y_FRACTION if is_bottom_row else STARS_Y_FRACTION

	var bar_width = width * BAR_WIDTH_FRACTION
	var bar_x = width * (1.0 - BAR_WIDTH_FRACTION) / 2.0  # keeps the bar centered

	var bar_tex = TextureRect.new()
	bar_tex.texture = load("res://assets/images/collection/progress_bar.png")
	bar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_tex.size = Vector2(bar_width, bar_height)
	bar_tex.position = Vector2(bar_x, height * BAR_Y_FRACTION)
	card.add_child(bar_tex)

	# Progress text position is independent of the bar's own size — it
	# starts at the bar's position but is nudged up/down on its own via
	# progress_text_y_offset (PROGRESS_TEXT_Y_OFFSET or
	# BOTTOM_PROGRESS_TEXT_Y_OFFSET) without affecting the bar texture.
	var progress_label = Label.new()
	progress_label.text = str(progress_data.total_merges) + " / " + str(progress_data.goal)
	if custom_font:
		progress_label.add_theme_font_override("font", custom_font)
	progress_label.add_theme_font_size_override("font_size", progress_font)
	progress_label.add_theme_color_override("font_color", Color(1, 1, 1))
	progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	progress_label.add_theme_constant_override("outline_size", 3)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.size = bar_tex.size
	progress_label.position = Vector2(bar_tex.position.x, bar_tex.position.y + progress_text_y_offset)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(progress_label)

	# Stars position now fully independent per row via stars_x_fraction /
	# stars_y_fraction — move STARS_X_FRACTION/STARS_Y_FRACTION for the
	# top row, or BOTTOM_STARS_X_FRACTION/BOTTOM_STARS_Y_FRACTION for
	# the bottom row, to move left/right/up/down on each row separately.
	var stars_label = Label.new()
	stars_label.text = "★ " + str(progress_data.stars)
	if custom_font:
		stars_label.add_theme_font_override("font", custom_font)
	stars_label.add_theme_font_size_override("font_size", stars_font)
	stars_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	stars_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	stars_label.add_theme_constant_override("outline_size", 3)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars_label.size = Vector2(width * 0.4, 18 if not is_bottom_row else 26)
	stars_label.position = Vector2(width * stars_x_fraction, height * stars_y_fraction)
	stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stars_label)

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
