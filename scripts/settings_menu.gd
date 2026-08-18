extends Control

var settings: Node
var current_category: String = "audio"

var listening_for_key: bool = false
var listening_slot: String = ""
var listening_button: Button = null

var opened_from_pause_menu: bool = false

var background: TextureRect
var back_button: TextureButton

var category_buttons: Dictionary = {}
var nav_arrow: Sprite2D = null

var content_container: Control
var audio_panel: Control
var visual_panel: Control
var gameplay_panel: Control
var statistics_panel: Control

var custom_font: Font

# ══════════════════════════════════════════════════════════════
#  LAYOUT CONSTANTS
# ══════════════════════════════════════════════════════════════
const NAV_X         := 970.0
const NAV_Y_START   := 318.0
const NAV_BTN_W     := 185.0
const NAV_BTN_H     := 48.0
const NAV_SPACING   := 14.0
const NAV_ARROW_GAP := -5.0

const PANEL_X       := 55.0
const PANEL_Y       := 170.0
const PANEL_W       := 880.0
const PANEL_H       := 480.0

const COL_L         := 65.0
const COL_R         := 435.0
const ROW_TOP       := 50.0
const ROW_BOT       := 250.0
const LABEL_FONT_SZ := 30
const CTRL_OFFSET_Y := 48.0

const SLIDER_W      := 280.0
const SLIDER_H      := 22.0
const KNOB_SIZE     := 32.0
const CHECKBOX_SIZE := 50.0
const OPTION_IMG_H  := 36.0
const KEYBIND_W     := 200.0
const KEYBIND_H     := 50.0

# ══════════════════════════════════════════════════════════════
#  CONTROLLER STATE
# ══════════════════════════════════════════════════════════════
# Left stick:  navigate grid (up/down/left/right between controls)
#              navigate categories (up/down when in category col)
#              moving right from category col enters the panel grid
#              moving left from col 0 does nothing (hard boundary)
#              moving up from row 0 does nothing (hard boundary)
#              moving down from last row does nothing (hard boundary)
# Right stick: horizontal only — adjusts slider value or cycles selector
# Cross:       toggle checkbox / activate keybind
# Circle:      go back

var using_controller: bool = false
var mouse_has_moved: bool = false

# Which "column zone" we're in:
#   -1 = category nav column (right side nav buttons)
#    0 = left content column
#    1 = right content column
var ctrl_col: int = -1
var ctrl_row: int = 0       # row within current panel grid
var ctrl_cat_index: int = 0 # which category is highlighted

var ctrl_nav_cd: float = 0.0
var ctrl_adj_cd: float = 0.0
const NAV_CD: float = 0.22
const ADJ_CD: float = 0.06
const AXIS_THRESHOLD: float = 0.3

var ctrl_highlight: Panel = null

# Left-stick latching. project.godot binds ui-up / ui-down / move_left /
# move_right to KEYS only — no joypad axes — so the stick produces no
# actions at all and navigation has to read it directly. A direction fires
# once when the stick crosses ACTIVATION and won't fire again until it
# falls back under RELEASE; without that gap a held stick emits a motion
# event every frame and the cursor bolts across the panel.
const STICK_ACTIVATE: float = 0.55
const STICK_RELEASE: float = 0.35
var _stick_latch: Dictionary = {"x": 0, "y": 0}

# How fast the right stick sweeps a slider, in value units per second.
const SLIDER_ADJUST_SPEED: float = 0.9

# panel_grid["audio"] = [
#   [ {left cell row0}, {right cell row0} ],
#   [ {left cell row1}, {right cell row1} ],
# ]
# cell = { "type": "slider"|"checkbox"|"selector"|"keybind"|"none", "node": <node> }
var panel_grid: Dictionary = {
	"audio": [], "visual": [], "gameplay": [], "statistics": []
}

const CATEGORIES = ["audio", "visual", "gameplay", "statistics"]

# ══════════════════════════════════════════════════════════════
func _ready():
	opened_from_pause_menu = get_tree().paused
	settings = get_node("/root/SettingsManager")
	custom_font = load("res://assets/fonts/Clownfall-Regular.ttf")

	setup_background()
	setup_nav_buttons()
	setup_content_area()
	setup_back_button()
	setup_ctrl_highlight()

	setup_audio_panel()
	setup_visual_panel()
	setup_gameplay_panel()
	setup_statistics_panel()

	switch_category("audio")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("Settings menu ready")

# ══════════════════════════════════════════════════════════════
#  HIGHLIGHT
# ══════════════════════════════════════════════════════════════
func setup_ctrl_highlight():
	ctrl_highlight = Panel.new()
	# A faint fill alone was hard to spot against the panel art, so this
	# carries a bright border too.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.10)
	box.border_color = Color(1, 0.85, 0.30, 0.95)
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	ctrl_highlight.add_theme_stylebox_override("panel", box)
	ctrl_highlight.visible = false
	ctrl_highlight.z_index = 5
	ctrl_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.add_child(ctrl_highlight)

func _show_highlight_on(node: Control):
	if not node or not ctrl_highlight:
		_hide_highlight()
		return
	# Wait one frame so layout positions are settled
	await get_tree().process_frame
	if not is_instance_valid(node) or not is_instance_valid(ctrl_highlight):
		return
	var gp = node.get_global_position() - content_container.get_global_position()
	var sz = node.size if node.size.x > 10 else Vector2(SLIDER_W, KNOB_SIZE)
	ctrl_highlight.position = Vector2(gp.x - 8, gp.y - 6)
	ctrl_highlight.size = Vector2(sz.x + 16, sz.y + 12)
	ctrl_highlight.visible = true

func _hide_highlight():
	if ctrl_highlight:
		ctrl_highlight.visible = false

# ══════════════════════════════════════════════════════════════
#  PROCESS — right stick adjusts current control value
# ══════════════════════════════════════════════════════════════
func _process(delta):
	if ctrl_nav_cd > 0.0: ctrl_nav_cd -= delta
	if ctrl_adj_cd > 0.0: ctrl_adj_cd -= delta

	if not using_controller or ctrl_col < 0:
		return
	if ctrl_adj_cd > 0.0:
		return

	var grid = panel_grid.get(current_category, [])
	if ctrl_row >= grid.size():
		return
	var row = grid[ctrl_row]
	if ctrl_col >= row.size():
		return
	var cell = row[ctrl_col]

	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if abs(rx) < 0.15:
		return

	if cell.type == "slider":
		# Scaled by delta and NOT rate-limited, so the volume sweeps
		# smoothly with how far the stick is pushed. The old fixed step on a
		# cooldown moved in visible jerks and took several seconds end to end.
		var slider: HSlider = cell.node
		slider.value = clampf(slider.value + rx * SLIDER_ADJUST_SPEED * delta, 0.0, 1.0)

	elif cell.type == "selector":
		# Selectors are discrete, so these still step one at a time.
		if rx > 0:
			cell.node.get_node("Right").emit_signal("pressed")
		else:
			cell.node.get_node("Left").emit_signal("pressed")
		ctrl_adj_cd = NAV_CD

# ══════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════
func _input(event):
	# Circle / ESC — always go back
	if _pressed_back(event):
		if not listening_for_key:
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()
			_on_back_pressed()
		return

	# Mouse movement — switch to mouse mode
	if event is InputEventMouseMotion:
		mouse_has_moved = true
		if using_controller:
			using_controller = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_hide_highlight()
			_refresh_cat_visuals()
		return

	if event is InputEventMouseButton:
		if mouse_has_moved and using_controller:
			using_controller = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_hide_highlight()
			_refresh_cat_visuals()
		return

	# Releasing the stick clears its latch so the next push registers. This
	# has to happen before the drift filter bails out, otherwise the latch
	# would never reset and the stick would work exactly once.
	if event is InputEventJoypadMotion:
		_update_stick_latch(event)
		if abs(event.axis_value) < AXIS_THRESHOLD:
			return

	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	# First real controller input — activate
	if not using_controller:
		using_controller = true
		mouse_has_moved = false
		ctrl_col = -1
		ctrl_cat_index = CATEGORIES.find(current_category)
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_refresh_cat_visuals()
		return

	var dir := _nav_dir(event)
	var confirm := _pressed_confirm(event)

	# ── Category column ───────────────────────────────────────
	#
	# The category buttons sit at NAV_X = 970, to the RIGHT of the panel
	# (which ends at 55 + 880 = 935). The original code had this backwards —
	# it entered the panel on "right" and treated "left" as a wall, which is
	# the opposite of where the two actually are on screen.
	if ctrl_col == -1:
		if dir == "up" and ctrl_nav_cd <= 0.0:
			# Hard boundary — can't go above first category
			if ctrl_cat_index > 0:
				ctrl_cat_index -= 1
				switch_category(CATEGORIES[ctrl_cat_index])
				_refresh_cat_visuals()
				ctrl_nav_cd = NAV_CD
			_consume()

		elif dir == "down" and ctrl_nav_cd <= 0.0:
			# Hard boundary — can't go below last category
			if ctrl_cat_index < CATEGORIES.size() - 1:
				ctrl_cat_index += 1
				switch_category(CATEGORIES[ctrl_cat_index])
				_refresh_cat_visuals()
				ctrl_nav_cd = NAV_CD
			_consume()

		elif (dir == "left" or confirm) and ctrl_nav_cd <= 0.0:
			# Into the panel, landing on the top-left control.
			_enter_panel()
			ctrl_nav_cd = NAV_CD
			_consume()

		elif dir == "right" and ctrl_nav_cd <= 0.0:
			# Hard boundary — nothing further right than the category list.
			_consume()

	# ── Panel grid ────────────────────────────────────────────
	else:
		var grid = panel_grid.get(current_category, [])

		if dir == "left" and ctrl_nav_cd <= 0.0:
			if ctrl_col > 0:
				ctrl_col -= 1
				_highlight_current()
				ctrl_nav_cd = NAV_CD
			# Hard boundary at col 0 — the panel's left edge.
			_consume()

		elif dir == "right" and ctrl_nav_cd <= 0.0:
			var moved := false
			if ctrl_col == 0:
				var row = grid[ctrl_row] if ctrl_row < grid.size() else []
				if row.size() > 1 and row[1].type != "none":
					ctrl_col = 1
					_highlight_current()
					moved = true
			if not moved:
				# Already at the rightmost filled cell, so right leaves the
				# panel and lands back on the category list.
				_leave_panel()
			ctrl_nav_cd = NAV_CD
			_consume()

		elif dir == "up" and ctrl_nav_cd <= 0.0:
			if ctrl_row > 0:
				ctrl_row -= 1
				# If the right column is selected but this row has no right
				# cell, fall back to the left one.
				var row = grid[ctrl_row] if ctrl_row < grid.size() else []
				if ctrl_col == 1 and (row.size() < 2 or row[1].type == "none"):
					ctrl_col = 0
				_highlight_current()
				ctrl_nav_cd = NAV_CD
			_consume()

		elif dir == "down" and ctrl_nav_cd <= 0.0:
			if ctrl_row < grid.size() - 1:
				ctrl_row += 1
				var row = grid[ctrl_row] if ctrl_row < grid.size() else []
				if ctrl_col == 1 and (row.size() < 2 or row[1].type == "none"):
					ctrl_col = 0
				_highlight_current()
				ctrl_nav_cd = NAV_CD
			_consume()

		elif confirm and ctrl_row < grid.size():
			var row = grid[ctrl_row]
			if ctrl_col < row.size():
				var cell = row[ctrl_col]
				if cell.type == "checkbox":
					var cb: TextureButton = cell.node
					cb.button_pressed = not cb.button_pressed
					cb.toggled.emit(cb.button_pressed)
				elif cell.type == "keybind":
					cell.node.emit_signal("pressed")
			_consume()

func _unhandled_input(event):
	if not listening_for_key:
		return
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		match listening_slot:
			"drop":      settings.set_drop_key(key)
			"powerup_1": settings.set_powerup_key(1, key)
			"powerup_2": settings.set_powerup_key(2, key)
			"powerup_3": settings.set_powerup_key(3, key)
		if listening_button:
			listening_button.text     = settings.get_key_name(key)
			listening_button.modulate = Color.WHITE
		listening_for_key = false
		listening_slot    = ""
		listening_button  = null
		settings.save_settings()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════
#  CONTROLLER HELPERS
# ══════════════════════════════════════════════════════════════

func _consume():
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()

# Updates the latch for whichever axis this event belongs to, and reports
# the direction if this push is a fresh one.
func _update_stick_latch(event: InputEventJoypadMotion) -> String:
	var key := ""
	if event.axis == JOY_AXIS_LEFT_X:
		key = "x"
	elif event.axis == JOY_AXIS_LEFT_Y:
		key = "y"
	else:
		return ""

	var value = event.axis_value

	if abs(value) < STICK_RELEASE:
		_stick_latch[key] = 0
		return ""

	var sign_now := 0
	if value > STICK_ACTIVATE:
		sign_now = 1
	elif value < -STICK_ACTIVATE:
		sign_now = -1

	if sign_now == 0 or _stick_latch[key] == sign_now:
		return ""

	_stick_latch[key] = sign_now
	if key == "x":
		return "right" if sign_now > 0 else "left"
	return "down" if sign_now > 0 else "up"

# One direction for all three input styles: the mapped keyboard actions,
# the d-pad, and the left stick.
func _nav_dir(event) -> String:
	if event is InputEventJoypadMotion:
		return _update_stick_latch(event)

	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: return "up"
			JOY_BUTTON_DPAD_DOWN: return "down"
			JOY_BUTTON_DPAD_LEFT: return "left"
			JOY_BUTTON_DPAD_RIGHT: return "right"

	if event.is_action_pressed("ui-up"):
		return "up"
	if event.is_action_pressed("ui-down"):
		return "down"
	if event.is_action_pressed("move_left"):
		return "left"
	if event.is_action_pressed("move_right"):
		return "right"
	return ""

# Cross on PlayStation, A on Xbox — both report as JOY_BUTTON_A.
func _pressed_confirm(event) -> bool:
	if event is InputEventJoypadButton and event.pressed \
		and event.button_index == JOY_BUTTON_A:
		return true
	return event.is_action_pressed("ui-confirm")

# project.godot binds Escape to "ui-cancel" — with a HYPHEN. This was
# checking Godot's built-in "ui_cancel" (underscore), a different action
# that the key isn't bound to, so Escape did nothing on this screen.
func _pressed_back(event) -> bool:
	if event is InputEventJoypadButton and event.pressed \
		and event.button_index == JOY_BUTTON_B:
		return true
	if InputMap.has_action("ui-cancel") and event.is_action_pressed("ui-cancel"):
		return true
	if InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_ESCAPE:
		return true
	return false

# Moves focus from the category list into the panel, at the top-left
# control. Statistics has no adjustable cells, so focus stays put there
# rather than landing on nothing.
func _enter_panel():
	var grid = panel_grid.get(current_category, [])
	if grid.is_empty():
		return
	ctrl_col = 0
	ctrl_row = 0
	_highlight_current()
	_refresh_cat_visuals()

func _leave_panel():
	ctrl_col = -1
	ctrl_cat_index = CATEGORIES.find(current_category)
	_hide_highlight()
	_refresh_cat_visuals()

func _highlight_current():
	var grid = panel_grid.get(current_category, [])
	if ctrl_row >= grid.size():
		return
	var row = grid[ctrl_row]
	if ctrl_col >= row.size():
		return
	var cell = row[ctrl_col]
	if cell.type == "none" or not cell.node:
		_hide_highlight()
		return
	_show_highlight_on(cell.node)

func _refresh_cat_visuals():
	for i in CATEGORIES.size():
		var cat = CATEGORIES[i]
		var btn = category_buttons[cat]
		# Highlight whichever category is currently pointed at by controller
		var is_ctrl_pointed = using_controller and ctrl_col == -1 and i == ctrl_cat_index
		if is_ctrl_pointed or cat == current_category:
			btn.modulate = Color(1, 1, 1, 1.0)
		else:
			btn.modulate = Color(1, 1, 1, 0.5)

func _cell(type: String, node) -> Dictionary:
	return { "type": type, "node": node }

func _empty() -> Dictionary:
	return { "type": "none", "node": null }

# ══════════════════════════════════════════════════════════════
#  BACKGROUND
# ══════════════════════════════════════════════════════════════
func setup_background():
	background = TextureRect.new()
	background.texture = load("res://assets/images/settings_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = get_viewport_rect().size
	add_child(background)

# ══════════════════════════════════════════════════════════════
#  NAV BUTTONS
# ══════════════════════════════════════════════════════════════
func setup_nav_buttons():
	var assets = {
		"audio":      "res://assets/images/settings/audio.png",
		"visual":     "res://assets/images/settings/visuals.png",
		"gameplay":   "res://assets/images/settings/gameplay.png",
		"statistics": "res://assets/images/settings/statistics.png",
	}

	for i in CATEGORIES.size():
		var cat = CATEGORIES[i]
		var btn = TextureButton.new()
		btn.texture_normal = load(assets[cat])
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
		btn.ignore_texture_size = true
		btn.custom_minimum_size = Vector2(NAV_BTN_W, NAV_BTN_H)
		btn.pivot_offset = Vector2(0, NAV_BTN_H / 2.0)
		btn.position = Vector2(NAV_X, NAV_Y_START + i * (NAV_BTN_H + NAV_SPACING))
		btn.modulate = Color(1, 1, 1, 0.5)
		btn.pressed.connect(func(c = cat): switch_category(c))

		btn.mouse_entered.connect(func(c = cat, b = btn):
			if not mouse_has_moved or using_controller:
				return
			if c != current_category:
				b.modulate = Color(1, 1, 1, 1.0)
				var tw = create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(b, "scale", Vector2(1.05, 1.05), 0.12)
		)
		btn.mouse_exited.connect(func(c = cat, b = btn):
			if not mouse_has_moved or using_controller:
				return
			if c != current_category:
				b.modulate = Color(1, 1, 1, 0.5)
				var tw = create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.12)
		)

		add_child(btn)
		category_buttons[cat] = btn
		SettingsManager.set_hover_cursor(btn)

	nav_arrow = Sprite2D.new()
	nav_arrow.texture = load("res://assets/images/settings/arrowcategory.png")
	nav_arrow.centered = true
	nav_arrow.z_index = 20
	nav_arrow.position = _arrow_pos_for_row(0)
	add_child(nav_arrow)

func _arrow_pos_for_row(row_index: int) -> Vector2:
	var half_w = 16.0
	if nav_arrow and nav_arrow.texture:
		half_w = nav_arrow.texture.get_width() / 2.0
	var x = NAV_X + NAV_BTN_W + NAV_ARROW_GAP + half_w
	var y = NAV_Y_START + row_index * (NAV_BTN_H + NAV_SPACING) + NAV_BTN_H / 2.0
	return Vector2(x, y)

# ══════════════════════════════════════════════════════════════
#  CONTENT AREA
# ══════════════════════════════════════════════════════════════
func setup_content_area():
	content_container = Control.new()
	content_container.position = Vector2(PANEL_X, PANEL_Y)
	content_container.size = Vector2(PANEL_W, PANEL_H)
	add_child(content_container)

	for panel_name in CATEGORIES:
		var p = Control.new()
		p.size = Vector2(PANEL_W, PANEL_H)
		p.visible = false
		content_container.add_child(p)
		match panel_name:
			"audio":      audio_panel      = p
			"visual":     visual_panel     = p
			"gameplay":   gameplay_panel   = p
			"statistics": statistics_panel = p

# ══════════════════════════════════════════════════════════════
#  BACK BUTTON
# ══════════════════════════════════════════════════════════════
func setup_back_button():
	back_button = TextureButton.new()
	back_button.texture_normal = load("res://assets/images/button_back.png")
	if not back_button.texture_normal:
		var b = Button.new()
		b.text = "BACK"
		if custom_font: b.add_theme_font_override("font", custom_font)
		b.add_theme_font_size_override("font_size", 26)
		b.custom_minimum_size = Vector2(160, 55)
		b.position = Vector2(50, get_viewport_rect().size.y - 90)
		b.pressed.connect(_on_back_pressed)
		add_child(b)
		back_button.queue_free()
		return

	back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_button.custom_minimum_size = Vector2(160, 55)
	back_button.position = Vector2(50, get_viewport_rect().size.y - 90)
	back_button.pressed.connect(_on_back_pressed)
	SettingsManager.set_hover_cursor(back_button)
	add_child(back_button)

# ══════════════════════════════════════════════════════════════
#  CATEGORY SWITCH
# ══════════════════════════════════════════════════════════════
func switch_category(category: String):
	current_category = category
	ctrl_row = 0
	_hide_highlight()

	audio_panel.visible      = false
	visual_panel.visible     = false
	gameplay_panel.visible   = false
	statistics_panel.visible = false

	for cat in category_buttons:
		if cat != category:
			category_buttons[cat].modulate = Color(1, 1, 1, 0.5)
			var tw = create_tween()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(category_buttons[cat], "scale", Vector2(1.0, 1.0), 0.1)

	match category:
		"audio":      audio_panel.visible      = true
		"visual":     visual_panel.visible     = true
		"gameplay":   gameplay_panel.visible   = true
		"statistics":
			statistics_panel.visible = true
			update_statistics_display()

	category_buttons[category].modulate = Color(1, 1, 1, 1.0)
	category_buttons[category].scale = Vector2(1.0, 1.0)

	var row_index = CATEGORIES.find(category)
	if nav_arrow and row_index >= 0:
		nav_arrow.position = _arrow_pos_for_row(row_index)
	if using_controller:
		ctrl_cat_index = row_index

# ══════════════════════════════════════════════════════════════
#  AUDIO PANEL
#  Grid:
#    row 0: [MASTER slider,  MUSIC slider ]
#    row 1: [SFX slider,     MUTE checkbox]
# ══════════════════════════════════════════════════════════════
func setup_audio_panel():
	_place_label(audio_panel, "MASTER", COL_L, ROW_TOP)
	var master_s = _place_slider(audio_panel, settings.master_volume, COL_L, ROW_TOP + CTRL_OFFSET_Y)
	master_s.value_changed.connect(func(v): settings.set_master_volume(v); settings.save_settings())

	_place_label(audio_panel, "MUSIC", COL_R, ROW_TOP)
	var music_s = _place_slider(audio_panel, settings.music_volume, COL_R, ROW_TOP + CTRL_OFFSET_Y)
	music_s.value_changed.connect(func(v): settings.set_music_volume(v); settings.save_settings())

	_place_label(audio_panel, "SFX", COL_L, ROW_BOT)
	var sfx_s = _place_slider(audio_panel, settings.sfx_volume, COL_L, ROW_BOT + CTRL_OFFSET_Y)
	sfx_s.value_changed.connect(func(v): settings.set_sfx_volume(v); settings.save_settings())

	_place_label(audio_panel, "MUTE WHEN TAB", COL_R, ROW_BOT)
	var mute_cb = _place_checkbox(audio_panel, settings.mute_when_tabbed, COL_R, ROW_BOT + CTRL_OFFSET_Y)
	mute_cb.toggled.connect(func(p): settings.set_mute_when_tabbed(p); settings.save_settings())

	panel_grid["audio"] = [
		[_cell("slider", master_s), _cell("slider",   music_s)],
		[_cell("slider", sfx_s),    _cell("checkbox", mute_cb)],
	]

# ══════════════════════════════════════════════════════════════
#  VISUAL PANEL
#  Grid:
#    row 0: [SCREEN MODE selector, FPS CAP selector  ]
#    row 1: [VSYNC checkbox,       COLORBLIND selector]
# ══════════════════════════════════════════════════════════════
func setup_visual_panel():
	var screen_mode_assets := ["windowed", "fullscreen", "borderless"]
	var fps_assets         := ["30", "60", "120", "unlimited"]
	var colorblind_assets  := ["none", "protanopia", "deuteranopia", "tritanopia"]

	_place_label(visual_panel, "SCREEN MODE", COL_L, ROW_TOP)
	var sm = _place_selector_img(visual_panel, screen_mode_assets, settings.screen_mode, COL_L, ROW_TOP + CTRL_OFFSET_Y)
	sm.get_node("Left").pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode - 1 + 3) % 3)
		_update_selector_img(sm, screen_mode_assets, settings.screen_mode)
		settings.save_settings())
	sm.get_node("Right").pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode + 1) % 3)
		_update_selector_img(sm, screen_mode_assets, settings.screen_mode)
		settings.save_settings())

	_place_label(visual_panel, "VSYNC", COL_L, ROW_BOT)
	var vsync_cb = _place_checkbox(visual_panel, settings.vsync_enabled, COL_L, ROW_BOT + CTRL_OFFSET_Y)
	vsync_cb.toggled.connect(func(p): settings.set_vsync(p); settings.save_settings())

	_place_label(visual_panel, "FPS CAP", COL_R, ROW_TOP)
	var fps = _place_selector_img(visual_panel, fps_assets, _fps_to_index(settings.fps_cap), COL_R, ROW_TOP + CTRL_OFFSET_Y)
	fps.get_node("Left").pressed.connect(func():
		var idx = (_fps_to_index(settings.fps_cap) - 1 + fps_assets.size()) % fps_assets.size()
		settings.set_fps_cap(_index_to_fps(idx))
		_update_selector_img(fps, fps_assets, idx)
		settings.save_settings())
	fps.get_node("Right").pressed.connect(func():
		var idx = (_fps_to_index(settings.fps_cap) + 1) % fps_assets.size()
		settings.set_fps_cap(_index_to_fps(idx))
		_update_selector_img(fps, fps_assets, idx)
		settings.save_settings())

	_place_label(visual_panel, "COLORBLIND", COL_R, ROW_BOT)
	var cbl = _place_selector_img(visual_panel, colorblind_assets, settings.colorblind_mode, COL_R, ROW_BOT + CTRL_OFFSET_Y)
	cbl.get_node("Left").pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode - 1 + 4) % 4)
		_update_selector_img(cbl, colorblind_assets, settings.colorblind_mode)
		settings.save_settings())
	cbl.get_node("Right").pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode + 1) % 4)
		_update_selector_img(cbl, colorblind_assets, settings.colorblind_mode)
		settings.save_settings())

	panel_grid["visual"] = [
		[_cell("selector", sm),       _cell("selector", fps)],
		[_cell("checkbox", vsync_cb), _cell("selector", cbl)],
	]

func _fps_to_index(cap: int) -> int:
	match cap:
		30:  return 0
		60:  return 1
		120: return 2
		_:   return 3

func _index_to_fps(idx: int) -> int:
	match idx:
		0: return 30
		1: return 60
		2: return 120
		_: return 0

# ══════════════════════════════════════════════════════════════
#  GAMEPLAY PANEL
#  Grid:
#    row 0: [POWERUP 1 keybind, DROP KEY keybind   ]
#    row 1: [POWERUP 2 keybind, DROP ASSIST checkbox]
#    row 2: [POWERUP 3 keybind, (empty)             ]
# ══════════════════════════════════════════════════════════════
func setup_gameplay_panel():
	var row_h := 120.0

	_place_label(gameplay_panel, "POWERUP SLOT 1", COL_L, ROW_TOP)
	var p1 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_1), COL_L, ROW_TOP + CTRL_OFFSET_Y)
	p1.pressed.connect(func(): _start_listening("powerup_1", p1))

	_place_label(gameplay_panel, "POWERUP SLOT 2", COL_L, ROW_TOP + row_h)
	var p2 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_2), COL_L, ROW_TOP + row_h + CTRL_OFFSET_Y)
	p2.pressed.connect(func(): _start_listening("powerup_2", p2))

	_place_label(gameplay_panel, "POWERUP SLOT 3", COL_L, ROW_TOP + row_h * 2)
	var p3 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_3), COL_L, ROW_TOP + row_h * 2 + CTRL_OFFSET_Y)
	p3.pressed.connect(func(): _start_listening("powerup_3", p3))

	_place_label(gameplay_panel, "DROP KEY", COL_R, ROW_TOP)
	var dk = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.drop_key), COL_R, ROW_TOP + CTRL_OFFSET_Y)
	dk.pressed.connect(func(): _start_listening("drop", dk))

	_place_label(gameplay_panel, "DROP ASSIST", COL_R, ROW_TOP + row_h)
	var da = _place_checkbox(gameplay_panel, settings.drop_assist_enabled, COL_R, ROW_TOP + row_h + CTRL_OFFSET_Y)
	da.toggled.connect(func(p): settings.set_drop_assist(p); settings.save_settings())

	panel_grid["gameplay"] = [
		[_cell("keybind", p1), _cell("keybind",  dk)],
		[_cell("keybind", p2), _cell("checkbox", da)],
		[_cell("keybind", p3), _empty()],
	]

func _start_listening(slot: String, btn: Button):
	listening_for_key = true
	listening_slot    = slot
	listening_button  = btn
	btn.text     = "Press any key..."
	btn.modulate = Color(1, 1, 0)

# ══════════════════════════════════════════════════════════════
#  STATISTICS PANEL
# ══════════════════════════════════════════════════════════════
func setup_statistics_panel():
	var rows = [
		["BEST SCORE:",            "0",     "BestScore"],
		["TOTAL RUNS:",            "0",     "TotalRuns"],
		["TOTAL CLOWNS DROPPED:",  "0",     "ClownsDropped"],
		["HIGHEST TIER CREATED:",  "None",  "HighestTier"],
		["TOTAL CURRENCY EARNED:", "0",     "Currency"],
		["TIME PLAYED:",           "0h 0m", "TimePlayed"],
	]
	var row_h      := 55.0
	var stat_col_l := COL_L + 40.0
	var stat_col_r := stat_col_l + 320.0

	for i in rows.size():
		var y = ROW_TOP + i * row_h
		var lbl = _make_label(rows[i][0], 22)
		lbl.position = Vector2(stat_col_l, y)
		statistics_panel.add_child(lbl)
		var val = _make_label(rows[i][1], 22)
		val.name = rows[i][2] + "Value"
		val.position = Vector2(stat_col_r, y)
		statistics_panel.add_child(val)

	panel_grid["statistics"] = []

func update_statistics_display():
	var clown_names = ["Tessa","Twinkles","Reina","Osvaldo","Hazel",
					   "Mumbles","Sneaky","Wendy","Chatty","Cups","Kirk"]
	var tier_text = "None"
	if settings.highest_tier_created < clown_names.size():
		tier_text = clown_names[settings.highest_tier_created]
	_set_stat("BestScore",     str(settings.best_score))
	_set_stat("TotalRuns",     str(settings.total_runs))
	_set_stat("ClownsDropped", str(settings.total_clowns_dropped))
	_set_stat("HighestTier",   tier_text)
	_set_stat("Currency",      str(settings.total_currency_earned))
	_set_stat("TimePlayed",    settings.format_time_played())

func _set_stat(stat_name: String, value: String):
	var node = statistics_panel.get_node_or_null(stat_name + "Value")
	if node: node.text = value

# ══════════════════════════════════════════════════════════════
#  WIDGET HELPERS
# ══════════════════════════════════════════════════════════════
func _make_label(text: String, font_size: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	if custom_font:
		lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.239, 0.337, 0.671))
	lbl.add_theme_color_override("font_outline_color", Color(0.035, 0.098, 0.247))
	lbl.add_theme_constant_override("outline_size", 6)
	return lbl

func _place_label(parent: Control, text: String, x: float, y: float) -> Label:
	var lbl = _make_label(text, LABEL_FONT_SZ)
	lbl.position = Vector2(x, y)
	lbl.custom_minimum_size = Vector2(SLIDER_W, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl

func _place_slider(parent: Control, initial: float, x: float, y: float) -> HSlider:
	var slider_tex = load("res://assets/images/settings/volumeslider.png")
	var knob_tex   = load("res://assets/images/settings/volumeknob.png")
	var slot_h: float = KNOB_SIZE

	if slider_tex:
		var track_img = TextureRect.new()
		track_img.texture = slider_tex
		track_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		track_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		track_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track_img.size = Vector2(SLIDER_W, SLIDER_H)
		track_img.position = Vector2(x, y + (slot_h - SLIDER_H) / 2.0)
		parent.add_child(track_img)

	var scaled_knob: Texture2D = knob_tex
	if knob_tex:
		var img = knob_tex.get_image()
		if img:
			img.resize(int(KNOB_SIZE), int(KNOB_SIZE), Image.INTERPOLATE_LANCZOS)
			scaled_knob = ImageTexture.create_from_image(img)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.custom_minimum_size = Vector2(SLIDER_W, slot_h)
	slider.position  = Vector2(x, y)

	var invisible_box = StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider",                 invisible_box)
	slider.add_theme_stylebox_override("grabber_area",           invisible_box)
	slider.add_theme_stylebox_override("grabber_area_highlight", invisible_box)

	if scaled_knob:
		slider.add_theme_icon_override("grabber",           scaled_knob)
		slider.add_theme_icon_override("grabber_highlight", scaled_knob)

	SettingsManager.set_hover_cursor(slider)
	parent.add_child(slider)
	return slider

func _place_checkbox(parent: Control, initial: bool, x: float, y: float) -> TextureButton:
	var cb = TextureButton.new()
	cb.toggle_mode    = true
	cb.button_pressed = initial
	cb.ignore_texture_size = true
	cb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	cb.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
	cb.position = Vector2(
		x + (SLIDER_W - CHECKBOX_SIZE) / 2.0,
		y + (KNOB_SIZE - CHECKBOX_SIZE) / 2.0
	)

	var box_tex   = load("res://assets/images/settings/box_uncheckmarked.png")
	var check_tex = load("res://assets/images/settings/checkmark.png")
	if box_tex:
		cb.texture_normal  = box_tex
		cb.texture_pressed = box_tex
		cb.texture_hover   = box_tex
	if check_tex:
		var mark = TextureRect.new()
		mark.name         = "Checkmark"
		mark.texture      = check_tex
		mark.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.anchor_right  = 1.0
		mark.anchor_bottom = 1.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible      = initial
		cb.add_child(mark)
		cb.toggled.connect(func(p): mark.visible = p)
	SettingsManager.set_hover_cursor(cb)
	parent.add_child(cb)
	return cb

func _place_selector_img(parent: Control, option_names: Array, current_idx: int, x: float, y: float) -> Control:
	var arrow_size := 36.0

	var container = Control.new()
	container.name = "SelectorContainer"
	container.position = Vector2(x, y)
	container.custom_minimum_size = Vector2(SLIDER_W, 44)
	container.size = Vector2(SLIDER_W, 44)

	var left_tex  = _scale_texture("res://assets/images/settings/arrowleft.png",  int(arrow_size))
	var right_tex = _scale_texture("res://assets/images/settings/arrowright.png", int(arrow_size))

	var left_btn = TextureButton.new()
	left_btn.name = "Left"
	left_btn.ignore_texture_size = true
	left_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	left_btn.custom_minimum_size = Vector2(arrow_size, arrow_size)
	left_btn.position = Vector2(0, (44.0 - arrow_size) / 2.0)
	if left_tex: left_btn.texture_normal = left_tex
	SettingsManager.set_hover_cursor(left_btn)
	container.add_child(left_btn)

	var img_w = SLIDER_W - arrow_size * 2 - 8
	var option_img = TextureRect.new()
	option_img.name = "OptionImage"
	option_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	option_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	option_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	option_img.custom_minimum_size = Vector2(img_w, OPTION_IMG_H)
	option_img.size = Vector2(img_w, OPTION_IMG_H)
	option_img.position = Vector2(arrow_size + 4, (44.0 - OPTION_IMG_H) / 2.0)
	var opt_tex = load("res://assets/images/settings/" + option_names[current_idx] + ".png")
	if opt_tex: option_img.texture = opt_tex
	container.add_child(option_img)

	var right_btn = TextureButton.new()
	right_btn.name = "Right"
	right_btn.ignore_texture_size = true
	right_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	right_btn.custom_minimum_size = Vector2(arrow_size, arrow_size)
	right_btn.position = Vector2(SLIDER_W - arrow_size, (44.0 - arrow_size) / 2.0)
	if right_tex: right_btn.texture_normal = right_tex
	SettingsManager.set_hover_cursor(right_btn)
	container.add_child(right_btn)

	parent.add_child(container)
	return container

func _update_selector_img(container: Control, option_names: Array, new_idx: int):
	var option_img = container.get_node_or_null("OptionImage")
	if option_img:
		var tex = load("res://assets/images/settings/" + option_names[new_idx] + ".png")
		if tex: option_img.texture = tex

func _place_keybind_button(parent: Control, initial_text: String, x: float, y: float) -> Button:
	var box_tex = load("res://assets/images/settings/keybind_box.png")

	var btn = Button.new()
	btn.text = initial_text
	if custom_font: btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.035, 0.098, 0.247))
	btn.add_theme_constant_override("outline_size", 4)
	btn.custom_minimum_size = Vector2(KEYBIND_W, KEYBIND_H)
	btn.position = Vector2(x + (SLIDER_W - KEYBIND_W) / 2.0, y)

	if box_tex:
		var style = StyleBoxTexture.new()
		style.texture = box_tex
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus",   style)

	SettingsManager.set_hover_cursor(btn)
	parent.add_child(btn)
	return btn

func _scale_texture(path: String, target_px: int) -> Texture2D:
	var tex = load(path)
	if not tex: return null
	var img = tex.get_image()
	if not img: return tex
	img.resize(target_px, target_px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# ══════════════════════════════════════════════════════════════
#  BACK
# ══════════════════════════════════════════════════════════════
func _on_back_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	settings.save_settings()
	if opened_from_pause_menu:
		var pause_menu = get_parent()
		if pause_menu and pause_menu.has_method("close_settings_menu"):
			pause_menu.close_settings_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
