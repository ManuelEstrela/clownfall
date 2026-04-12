extends Control

# Reference to settings manager
var settings: Node

# Current selected category
var current_category: String = "audio"

# Keybind listening state
var listening_for_key: bool = false
var listening_slot: String = ""
var listening_button: Button = null

# Track if opened from pause menu
var opened_from_pause_menu: bool = false

# UI References
var background: TextureRect
var back_button: TextureButton

# Category buttons (right side, vertical nav list)
var category_buttons: Dictionary = {}  # key -> TextureButton
var nav_arrow: Sprite2D = null         # single arrow repositioned on each selection

# Content panels (left side)
var content_container: Control
var audio_panel: Control
var visual_panel: Control
var gameplay_panel: Control
var statistics_panel: Control

# Custom font
var custom_font: Font

# ══════════════════════════════════════════════════════════════
#  LAYOUT CONSTANTS  ← everything you need to tweak is here
# ══════════════════════════════════════════════════════════════

# ── Right-side nav panel ──────────────────────────────────────
# NAV_X        : X of the LEFT edge of each button (screen space)
# NAV_Y_START  : Y of the TOP edge of the FIRST button
# NAV_BTN_W    : rendered width of each button image
# NAV_BTN_H    : rendered height of each button image
# NAV_SPACING  : vertical gap between buttons
# NAV_ARROW_GAP: pixels between the button's right edge and the arrow centre
const NAV_X         := 970.0
const NAV_Y_START   := 318.0
const NAV_BTN_W     := 185.0
const NAV_BTN_H     := 48.0
const NAV_SPACING   := 14.0
const NAV_ARROW_GAP := -5.0   # arrow sits this far past the button's right edge

# ── Left content panel ────────────────────────────────────────
const PANEL_X       := 55.0
const PANEL_Y       := 170.0
const PANEL_W       := 880.0
const PANEL_H       := 480.0

# ── Grid inside left panel ────────────────────────────────────
const COL_L         := 30.0
const COL_R         := 460.0
const ROW_TOP       := 30.0
const ROW_BOT       := 260.0
const LABEL_FONT_SZ := 26
const CTRL_OFFSET_Y := 40.0

# ══════════════════════════════════════════════════════════════

func _ready():
	opened_from_pause_menu = get_tree().paused
	settings = get_node("/root/SettingsManager")
	custom_font = load("res://assets/font/Clownfall-Regular.ttf")

	setup_background()
	setup_nav_buttons()
	setup_content_area()
	setup_back_button()

	setup_audio_panel()
	setup_visual_panel()
	setup_gameplay_panel()
	setup_statistics_panel()

	switch_category("audio")
	print("✅ Settings menu ready")

func _input(event):
	if opened_from_pause_menu and event.is_action_pressed("ui_cancel"):
		if not listening_for_key:
			_on_back_pressed()
			get_viewport().set_input_as_handled()

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
#  RIGHT-SIDE NAV BUTTONS
# ══════════════════════════════════════════════════════════════
func setup_nav_buttons():
	var categories = ["audio", "visual", "gameplay", "statistics"]
	var assets = {
		"audio":      "res://assets/images/settings/audio.png",
		"visual":     "res://assets/images/settings/visuals.png",
		"gameplay":   "res://assets/images/settings/gameplay.png",
		"statistics": "res://assets/images/settings/statistics.png",
	}

	for i in categories.size():
		var cat = categories[i]
		var btn = TextureButton.new()
		btn.texture_normal = load(assets[cat])
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT   # left-aligned, not centered
		btn.ignore_texture_size = true
		btn.custom_minimum_size = Vector2(NAV_BTN_W, NAV_BTN_H)
		btn.pivot_offset = Vector2(0, NAV_BTN_H / 2.0)         # scale from left-centre
		btn.position = Vector2(NAV_X, NAV_Y_START + i * (NAV_BTN_H + NAV_SPACING))
		btn.modulate = Color(1, 1, 1, 0.5)   # dim = unselected
		btn.pressed.connect(func(c = cat): switch_category(c))

		# Hover: full opacity + tiny scale up (only if this button is NOT already selected)
		btn.mouse_entered.connect(func(c = cat, b = btn):
			if c != current_category:
				b.modulate = Color(1, 1, 1, 1.0)
				var tw = create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(b, "scale", Vector2(1.05, 1.05), 0.12)
		)
		btn.mouse_exited.connect(func(c = cat, b = btn):
			if c != current_category:
				b.modulate = Color(1, 1, 1, 0.5)
				var tw = create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.12)
		)

		add_child(btn)
		category_buttons[cat] = btn

	# Single arrow Sprite2D — repositioned by switch_category().
	# centered = true so .position points to the sprite's centre.
	# X is fixed (right of all buttons); Y follows the selected row.
	nav_arrow = Sprite2D.new()
	nav_arrow.texture = load("res://assets/images/settings/arrowcategory.png")
	nav_arrow.centered = true
	nav_arrow.z_index = 20
	nav_arrow.position = _arrow_pos_for_row(0)  # corrected by switch_category("audio")
	add_child(nav_arrow)

# Returns the world-space centre the arrow should sit at for row [i].
func _arrow_pos_for_row(row_index: int) -> Vector2:
	var half_w = 16.0
	if nav_arrow and nav_arrow.texture:
		half_w = nav_arrow.texture.get_width() / 2.0
	var x = NAV_X + NAV_BTN_W + NAV_ARROW_GAP + half_w
	var y = NAV_Y_START + row_index * (NAV_BTN_H + NAV_SPACING) + NAV_BTN_H / 2.0
	return Vector2(x, y)

# ══════════════════════════════════════════════════════════════
#  LEFT CONTENT AREA
# ══════════════════════════════════════════════════════════════
func setup_content_area():
	content_container = Control.new()
	content_container.position = Vector2(PANEL_X, PANEL_Y)
	content_container.size = Vector2(PANEL_W, PANEL_H)
	add_child(content_container)

	for panel_name in ["audio", "visual", "gameplay", "statistics"]:
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
	add_child(back_button)

# ══════════════════════════════════════════════════════════════
#  CATEGORY SWITCH
# ══════════════════════════════════════════════════════════════
func switch_category(category: String):
	current_category = category

	audio_panel.visible      = false
	visual_panel.visible     = false
	gameplay_panel.visible   = false
	statistics_panel.visible = false

	# Dim and reset scale on all buttons
	for cat in category_buttons:
		category_buttons[cat].modulate = Color(1, 1, 1, 0.5)
		var tw = create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(category_buttons[cat], "scale", Vector2(1.0, 1.0), 0.1)

	var row_order = ["audio", "visual", "gameplay", "statistics"]

	match category:
		"audio":
			audio_panel.visible = true
		"visual":
			visual_panel.visible = true
		"gameplay":
			gameplay_panel.visible = true
		"statistics":
			statistics_panel.visible = true
			update_statistics_display()

	# Selected button: full opacity, normal scale
	category_buttons[category].modulate = Color(1, 1, 1, 1.0)
	category_buttons[category].scale = Vector2(1.0, 1.0)

	# Snap arrow to selected row
	var row_index = row_order.find(category)
	if nav_arrow and row_index >= 0:
		nav_arrow.position = _arrow_pos_for_row(row_index)

# ══════════════════════════════════════════════════════════════
#  AUDIO PANEL
# ══════════════════════════════════════════════════════════════
func setup_audio_panel():
	_place_label(audio_panel, "MASTER", COL_L, ROW_TOP)
	var master_s = _place_slider(audio_panel, settings.master_volume, COL_L, ROW_TOP + CTRL_OFFSET_Y)
	master_s.value_changed.connect(func(v): settings.set_master_volume(v); settings.save_settings())

	_place_label(audio_panel, "SFX", COL_L, ROW_BOT)
	var sfx_s = _place_slider(audio_panel, settings.sfx_volume, COL_L, ROW_BOT + CTRL_OFFSET_Y)
	sfx_s.value_changed.connect(func(v): settings.set_sfx_volume(v); settings.save_settings())

	_place_label(audio_panel, "MUSIC", COL_R, ROW_TOP)
	var music_s = _place_slider(audio_panel, settings.music_volume, COL_R, ROW_TOP + CTRL_OFFSET_Y)
	music_s.value_changed.connect(func(v): settings.set_music_volume(v); settings.save_settings())

	_place_label(audio_panel, "MUTE WHEN TAB", COL_R, ROW_BOT)
	var mute_cb = _place_checkbox(audio_panel, settings.mute_when_tabbed, COL_R, ROW_BOT + CTRL_OFFSET_Y)
	mute_cb.toggled.connect(func(p): settings.set_mute_when_tabbed(p); settings.save_settings())

# ══════════════════════════════════════════════════════════════
#  VISUAL PANEL
# ══════════════════════════════════════════════════════════════
func setup_visual_panel():
	_place_label(visual_panel, "SCREEN MODE", COL_L, ROW_TOP)
	var sm = _place_selector(visual_panel, settings.get_screen_mode_name(), COL_L, ROW_TOP + CTRL_OFFSET_Y)
	sm.get_node("Left").pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode - 1 + 3) % 3)
		sm.get_node("ValueLabel").text = settings.get_screen_mode_name()
		settings.save_settings())
	sm.get_node("Right").pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode + 1) % 3)
		sm.get_node("ValueLabel").text = settings.get_screen_mode_name()
		settings.save_settings())

	_place_label(visual_panel, "VSYNC", COL_L, ROW_BOT)
	var vsync_cb = _place_checkbox(visual_panel, settings.vsync_enabled, COL_L, ROW_BOT + CTRL_OFFSET_Y)
	vsync_cb.toggled.connect(func(p): settings.set_vsync(p); settings.save_settings())

	_place_label(visual_panel, "FPS CAP", COL_R, ROW_TOP)
	var fps = _place_selector(visual_panel, settings.get_fps_cap_name(), COL_R, ROW_TOP + CTRL_OFFSET_Y)
	fps.get_node("Left").pressed.connect(func(): _cycle_fps(-1, fps.get_node("ValueLabel")))
	fps.get_node("Right").pressed.connect(func(): _cycle_fps(1, fps.get_node("ValueLabel")))

	_place_label(visual_panel, "COLORBLIND", COL_R, ROW_BOT)
	var cbl = _place_selector(visual_panel, settings.get_colorblind_mode_name(), COL_R, ROW_BOT + CTRL_OFFSET_Y)
	cbl.get_node("Left").pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode - 1 + 4) % 4)
		cbl.get_node("ValueLabel").text = settings.get_colorblind_mode_name()
		settings.save_settings())
	cbl.get_node("Right").pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode + 1) % 4)
		cbl.get_node("ValueLabel").text = settings.get_colorblind_mode_name()
		settings.save_settings())

func _cycle_fps(dir: int, label: Label):
	var opts = [30, 60, 120, 0]
	var idx = opts.find(settings.fps_cap)
	if idx == -1: idx = 1
	idx = (idx + dir + opts.size()) % opts.size()
	settings.set_fps_cap(opts[idx])
	label.text = settings.get_fps_cap_name()
	settings.save_settings()

# ══════════════════════════════════════════════════════════════
#  GAMEPLAY PANEL
# ══════════════════════════════════════════════════════════════
func setup_gameplay_panel():
	var row_h := 120.0

	_place_label(gameplay_panel, "DROP ASSIST", COL_L, ROW_TOP)
	var da = _place_checkbox(gameplay_panel, settings.drop_assist_enabled, COL_L, ROW_TOP + CTRL_OFFSET_Y)
	da.toggled.connect(func(p): settings.set_drop_assist(p); settings.save_settings())

	_place_label(gameplay_panel, "DROP KEY", COL_L, ROW_TOP + row_h)
	var dk = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.drop_key), COL_L, ROW_TOP + row_h + CTRL_OFFSET_Y)
	dk.pressed.connect(func(): _start_listening("drop", dk))

	_place_label(gameplay_panel, "POWERUP SLOT 1", COL_L, ROW_TOP + row_h * 2)
	var p1 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_1), COL_L, ROW_TOP + row_h * 2 + CTRL_OFFSET_Y)
	p1.pressed.connect(func(): _start_listening("powerup_1", p1))

	_place_label(gameplay_panel, "POWERUP SLOT 2", COL_R, ROW_TOP)
	var p2 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_2), COL_R, ROW_TOP + CTRL_OFFSET_Y)
	p2.pressed.connect(func(): _start_listening("powerup_2", p2))

	_place_label(gameplay_panel, "POWERUP SLOT 3", COL_R, ROW_TOP + row_h)
	var p3 = _place_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_3), COL_R, ROW_TOP + row_h + CTRL_OFFSET_Y)
	p3.pressed.connect(func(): _start_listening("powerup_3", p3))

func _start_listening(slot: String, btn: Button):
	listening_for_key = true
	listening_slot    = slot
	listening_button  = btn
	btn.text     = "Press any key..."
	btn.modulate = Color(1, 1, 0)

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
			listening_button.text    = settings.get_key_name(key)
			listening_button.modulate = Color.WHITE
		listening_for_key = false
		listening_slot    = ""
		listening_button  = null
		settings.save_settings()
		get_viewport().set_input_as_handled()

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
	var row_h := 65.0
	for i in rows.size():
		var y = ROW_TOP + i * row_h
		var lbl = _make_label(rows[i][0], 22)
		lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
		lbl.position = Vector2(COL_L, y)
		statistics_panel.add_child(lbl)
		var val = _make_label(rows[i][1], 22)
		val.name = rows[i][2] + "Value"
		val.position = Vector2(COL_L + 360, y)
		statistics_panel.add_child(val)

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
	if custom_font: lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	return lbl

func _place_label(parent: Control, text: String, x: float, y: float) -> Label:
	var lbl = _make_label(text, LABEL_FONT_SZ)
	lbl.position = Vector2(x, y)
	parent.add_child(lbl)
	return lbl

func _place_slider(parent: Control, initial: float, x: float, y: float) -> HSlider:
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.custom_minimum_size = Vector2(340, 44)
	slider.position  = Vector2(x, y)
	var slider_tex = load("res://assets/images/settings/volumeslider.png")
	var knob_tex   = load("res://assets/images/settings/volumeknob.png")
	if slider_tex:
		var sbox = StyleBoxTexture.new()
		sbox.texture = slider_tex
		slider.add_theme_stylebox_override("slider",                 sbox)
		slider.add_theme_stylebox_override("grabber_area",           sbox)
		slider.add_theme_stylebox_override("grabber_area_highlight", sbox)
	if knob_tex:
		slider.add_theme_icon_override("grabber",           knob_tex)
		slider.add_theme_icon_override("grabber_highlight", knob_tex)
	parent.add_child(slider)
	return slider

func _place_checkbox(parent: Control, initial: bool, x: float, y: float) -> TextureButton:
	var cb = TextureButton.new()
	cb.toggle_mode    = true
	cb.button_pressed = initial
	cb.custom_minimum_size = Vector2(44, 44)
	cb.position = Vector2(x, y)
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
	parent.add_child(cb)
	return cb

func _place_selector(parent: Control, initial_text: String, x: float, y: float) -> Control:
	var container = Control.new()
	container.position = Vector2(x, y)
	container.custom_minimum_size = Vector2(320, 50)

	var left_btn = Button.new()
	left_btn.name = "Left"
	left_btn.text = "<"
	if custom_font: left_btn.add_theme_font_override("font", custom_font)
	left_btn.add_theme_font_size_override("font_size", 28)
	left_btn.custom_minimum_size = Vector2(44, 44)
	left_btn.position = Vector2(0, 0)
	container.add_child(left_btn)

	var val_lbl = Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.text = initial_text
	if custom_font: val_lbl.add_theme_font_override("font", custom_font)
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val_lbl.custom_minimum_size  = Vector2(200, 44)
	val_lbl.position             = Vector2(50, 0)
	container.add_child(val_lbl)

	var right_btn = Button.new()
	right_btn.name = "Right"
	right_btn.text = ">"
	if custom_font: right_btn.add_theme_font_override("font", custom_font)
	right_btn.add_theme_font_size_override("font_size", 28)
	right_btn.custom_minimum_size = Vector2(44, 44)
	right_btn.position = Vector2(256, 0)
	container.add_child(right_btn)

	parent.add_child(container)
	return container

func _place_keybind_button(parent: Control, initial_text: String, x: float, y: float) -> Button:
	var btn = Button.new()
	btn.text = initial_text
	if custom_font: btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(180, 44)
	btn.position = Vector2(x, y)
	parent.add_child(btn)
	return btn

# ══════════════════════════════════════════════════════════════
#  BACK
# ══════════════════════════════════════════════════════════════
func _on_back_pressed():
	settings.save_settings()
	if opened_from_pause_menu:
		var pause_menu = get_parent()
		if pause_menu and pause_menu.has_method("close_settings_menu"):
			pause_menu.close_settings_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
