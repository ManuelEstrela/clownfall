extends Control

# Reference to settings manager
var settings: Node

# Current selected category
var current_category: String = "audio"

# Keybind listening state
var listening_for_key: bool = false
var listening_slot: String = ""

# Track if opened from pause menu
var opened_from_pause_menu: bool = false

# UI References
var background: TextureRect
var back_button: Button

# Category buttons (right side, vertical)
var audio_button: Button
var visual_button: Button
var gameplay_button: Button
var statistics_button: Button

# Content panels (left side)
var content_container: Control
var audio_panel: VBoxContainer
var visual_panel: VBoxContainer
var gameplay_panel: VBoxContainer
var statistics_panel: VBoxContainer

func _ready():
	# Check if we're in a paused game
	opened_from_pause_menu = get_tree().paused
	
	settings = get_node("/root/SettingsManager")
	
	# Create UI
	setup_background()
	setup_category_buttons()
	setup_content_panels()
	setup_back_button()
	
	# Setup all panels
	setup_audio_panel()
	setup_visual_panel()
	setup_gameplay_panel()
	setup_statistics_panel()
	
	# Show audio panel by default
	switch_category("audio")
	
	print("✅ Settings menu ready (new layout)")

func _input(event):
	# If opened from pause menu, ESC closes settings
	if opened_from_pause_menu and event.is_action_pressed("ui_cancel"):
		if not listening_for_key:
			_on_back_pressed()
			get_viewport().set_input_as_handled()

func setup_background():
	# Create fullscreen background
	background = TextureRect.new()
	background.texture = load("res://assets/images/settings_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = get_viewport_rect().size
	add_child(background)

func setup_category_buttons():
	# Right panel - Vertical category buttons inside the "CLOWN FALL" frame
	# Position buttons below the "CLOWN FALL" text
	
	var viewport_size = get_viewport_rect().size
	var button_width = 200
	var button_height = 50
	var button_spacing = 20
	var start_x = viewport_size.x - 298  # Right side positioning
	var start_y = 302  # Below the CLOWN FALL header
	
	# Audio button
	audio_button = create_category_button("AUDIO", Vector2(start_x, start_y))
	audio_button.pressed.connect(func(): switch_category("audio"))
	
	# Visual button
	visual_button = create_category_button("VISUAL", Vector2(start_x, start_y + button_height + button_spacing))
	visual_button.pressed.connect(func(): switch_category("visual"))
	
	# Gameplay button
	gameplay_button = create_category_button("GAMEPLAY", Vector2(start_x, start_y + (button_height + button_spacing) * 2))
	gameplay_button.pressed.connect(func(): switch_category("gameplay"))
	
	# Statistics button
	statistics_button = create_category_button("STATISTICS", Vector2(start_x, start_y + (button_height + button_spacing) * 3))
	statistics_button.pressed.connect(func(): switch_category("statistics"))

func create_category_button(text: String, pos: Vector2) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 60)
	button.position = pos
	
	# Style
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 0.84, 0))
	
	# Button background style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.15, 0.25, 0.8)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.4, 0.3, 0.5)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.25, 0.35, 0.9)
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color(1, 0.84, 0)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("hover", hover_style)
	
	add_child(button)
	return button

func setup_content_panels():
	# Left panel - Content area
	var viewport_size = get_viewport_rect().size
	
	content_container = Control.new()
	content_container.position = Vector2(130, 200)  # Inside left frame
	content_container.size = Vector2(900, 500)  # Fit within left rectangle
	add_child(content_container)
	
	# Create all panels (hidden by default)
	audio_panel = VBoxContainer.new()
	audio_panel.add_theme_constant_override("separation", 15)
	audio_panel.visible = false
	content_container.add_child(audio_panel)
	
	visual_panel = VBoxContainer.new()
	visual_panel.add_theme_constant_override("separation", 15)
	visual_panel.visible = false
	content_container.add_child(visual_panel)
	
	gameplay_panel = VBoxContainer.new()
	gameplay_panel.add_theme_constant_override("separation", 15)
	gameplay_panel.visible = false
	content_container.add_child(gameplay_panel)
	
	statistics_panel = VBoxContainer.new()
	statistics_panel.add_theme_constant_override("separation", 15)
	statistics_panel.visible = false
	content_container.add_child(statistics_panel)

func setup_back_button():
	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(150, 50)
	back_button.position = Vector2(50, get_viewport_rect().size.y - 100)
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.add_theme_color_override("font_color", Color(1, 1, 1))
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

func switch_category(category: String):
	current_category = category
	
	# Hide all panels
	audio_panel.visible = false
	visual_panel.visible = false
	gameplay_panel.visible = false
	statistics_panel.visible = false
	
	# Reset button colors
	audio_button.modulate = Color.WHITE
	visual_button.modulate = Color.WHITE
	gameplay_button.modulate = Color.WHITE
	statistics_button.modulate = Color.WHITE
	
	# Show selected panel and highlight button
	match category:
		"audio":
			audio_panel.visible = true
			audio_button.modulate = Color(1, 0.84, 0)
		"visual":
			visual_panel.visible = true
			visual_button.modulate = Color(1, 0.84, 0)
		"gameplay":
			gameplay_panel.visible = true
			gameplay_button.modulate = Color(1, 0.84, 0)
		"statistics":
			statistics_panel.visible = true
			statistics_button.modulate = Color(1, 0.84, 0)
			update_statistics_display()

# ====== AUDIO PANEL SETUP ======

func setup_audio_panel():
	add_setting_header(audio_panel, "MASTER VOLUME")
	var master_slider = add_slider(audio_panel, settings.master_volume)
	master_slider.value_changed.connect(func(value): 
		settings.set_master_volume(value)
		settings.save_settings()
	)
	
	add_setting_header(audio_panel, "MUSIC VOLUME")
	var music_slider = add_slider(audio_panel, settings.music_volume)
	music_slider.value_changed.connect(func(value): 
		settings.set_music_volume(value)
		settings.save_settings()
	)
	
	add_setting_header(audio_panel, "SFX VOLUME")
	var sfx_slider = add_slider(audio_panel, settings.sfx_volume)
	sfx_slider.value_changed.connect(func(value): 
		settings.set_sfx_volume(value)
		settings.save_settings()
	)
	
	add_setting_header(audio_panel, "MUTE WHEN TABBED OUT")
	var mute_checkbox = add_checkbox(audio_panel, settings.mute_when_tabbed)
	mute_checkbox.toggled.connect(func(pressed):
		settings.set_mute_when_tabbed(pressed)
		settings.save_settings()
	)

# ====== VISUAL PANEL SETUP ======

func setup_visual_panel():
	add_setting_header(visual_panel, "SCREEN MODE")
	var screen_container = add_option_selector(visual_panel, settings.get_screen_mode_name())
	var screen_left = screen_container.get_child(0)
	var screen_right = screen_container.get_child(2)
	var screen_label = screen_container.get_child(1)
	
	screen_left.pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode - 1 + 3) % 3)
		screen_label.text = settings.get_screen_mode_name()
		settings.save_settings()
	)
	screen_right.pressed.connect(func():
		settings.set_screen_mode((settings.screen_mode + 1) % 3)
		screen_label.text = settings.get_screen_mode_name()
		settings.save_settings()
	)
	
	add_setting_header(visual_panel, "VSYNC")
	var vsync_checkbox = add_checkbox(visual_panel, settings.vsync_enabled)
	vsync_checkbox.toggled.connect(func(pressed):
		settings.set_vsync(pressed)
		settings.save_settings()
	)
	
	add_setting_header(visual_panel, "FPS CAP")
	var fps_container = add_option_selector(visual_panel, settings.get_fps_cap_name())
	var fps_left = fps_container.get_child(0)
	var fps_right = fps_container.get_child(2)
	var fps_label = fps_container.get_child(1)
	
	fps_left.pressed.connect(func():
		cycle_fps_cap(-1, fps_label)
	)
	fps_right.pressed.connect(func():
		cycle_fps_cap(1, fps_label)
	)
	
	add_setting_header(visual_panel, "COLORBLIND MODE")
	var colorblind_container = add_option_selector(visual_panel, settings.get_colorblind_mode_name())
	var colorblind_left = colorblind_container.get_child(0)
	var colorblind_right = colorblind_container.get_child(2)
	var colorblind_label = colorblind_container.get_child(1)
	
	colorblind_left.pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode - 1 + 4) % 4)
		colorblind_label.text = settings.get_colorblind_mode_name()
		settings.save_settings()
	)
	colorblind_right.pressed.connect(func():
		settings.set_colorblind_mode((settings.colorblind_mode + 1) % 4)
		colorblind_label.text = settings.get_colorblind_mode_name()
		settings.save_settings()
	)

func cycle_fps_cap(direction: int, label: Label):
	var fps_options = [30, 60, 120, 0]
	var current_index = fps_options.find(settings.fps_cap)
	if current_index == -1:
		current_index = 1
	
	current_index = (current_index + direction + fps_options.size()) % fps_options.size()
	settings.set_fps_cap(fps_options[current_index])
	label.text = settings.get_fps_cap_name()
	settings.save_settings()

# ====== GAMEPLAY PANEL SETUP ======

func setup_gameplay_panel():
	add_setting_header(gameplay_panel, "DROP ASSIST (VERTICAL LINE)")
	var drop_assist_checkbox = add_checkbox(gameplay_panel, settings.drop_assist_enabled)
	drop_assist_checkbox.toggled.connect(func(pressed):
		settings.set_drop_assist(pressed)
		settings.save_settings()
	)
	
	add_setting_header(gameplay_panel, "DROP KEY")
	var drop_key_button = add_keybind_button(gameplay_panel, settings.get_key_name(settings.drop_key))
	drop_key_button.pressed.connect(func():
		start_listening_for_key("drop", drop_key_button)
	)
	
	add_setting_header(gameplay_panel, "POWERUP SLOT 1")
	var powerup1_button = add_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_1))
	powerup1_button.pressed.connect(func():
		start_listening_for_key("powerup_1", powerup1_button)
	)
	
	add_setting_header(gameplay_panel, "POWERUP SLOT 2")
	var powerup2_button = add_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_2))
	powerup2_button.pressed.connect(func():
		start_listening_for_key("powerup_2", powerup2_button)
	)
	
	add_setting_header(gameplay_panel, "POWERUP SLOT 3")
	var powerup3_button = add_keybind_button(gameplay_panel, settings.get_key_name(settings.powerup_key_3))
	powerup3_button.pressed.connect(func():
		start_listening_for_key("powerup_3", powerup3_button)
	)

func start_listening_for_key(slot: String, button: Button):
	listening_for_key = true
	listening_slot = slot
	button.text = "Press any key..."
	button.modulate = Color(1, 1, 0)

func _unhandled_input(event):
	if not listening_for_key:
		return
	
	if event is InputEventKey and event.pressed:
		var new_key = event.keycode
		
		var button: Button = null
		match listening_slot:
			"drop":
				button = gameplay_panel.get_node_or_null("DropKeyButton")
				settings.set_drop_key(new_key)
			"powerup_1":
				button = gameplay_panel.get_node_or_null("Powerup1Button")
				settings.set_powerup_key(1, new_key)
			"powerup_2":
				button = gameplay_panel.get_node_or_null("Powerup2Button")
				settings.set_powerup_key(2, new_key)
			"powerup_3":
				button = gameplay_panel.get_node_or_null("Powerup3Button")
				settings.set_powerup_key(3, new_key)
		
		if button:
			button.text = settings.get_key_name(new_key)
			button.modulate = Color.WHITE
		
		listening_for_key = false
		listening_slot = ""
		settings.save_settings()
		get_viewport().set_input_as_handled()

# ====== STATISTICS PANEL SETUP ======

func setup_statistics_panel():
	add_stat_row(statistics_panel, "BEST SCORE:", "0", "BestScore")
	add_stat_row(statistics_panel, "TOTAL RUNS:", "0", "TotalRuns")
	add_stat_row(statistics_panel, "TOTAL CLOWNS DROPPED:", "0", "ClownsDropped")
	add_stat_row(statistics_panel, "HIGHEST TIER CREATED:", "None", "HighestTier")
	add_stat_row(statistics_panel, "TOTAL CURRENCY EARNED:", "0", "Currency")
	add_stat_row(statistics_panel, "TIME PLAYED:", "0h 0m", "TimePlayed")

func update_statistics_display():
	update_stat_value(statistics_panel, "BestScore", str(settings.best_score))
	update_stat_value(statistics_panel, "TotalRuns", str(settings.total_runs))
	update_stat_value(statistics_panel, "ClownsDropped", str(settings.total_clowns_dropped))
	
	var clown_names = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel", "Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]
	var tier_text = "None"
	if settings.highest_tier_created < clown_names.size():
		tier_text = clown_names[settings.highest_tier_created]
	update_stat_value(statistics_panel, "HighestTier", tier_text)
	
	update_stat_value(statistics_panel, "Currency", str(settings.total_currency_earned))
	update_stat_value(statistics_panel, "TimePlayed", settings.format_time_played())

# ====== UI HELPER FUNCTIONS ======

func add_setting_header(parent: Control, text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	parent.add_child(label)

func add_slider(parent: Control, initial_value: float) -> HSlider:
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(400, 30)
	parent.add_child(slider)
	return slider

func add_checkbox(parent: Control, initial_state: bool) -> CheckBox:
	var checkbox = CheckBox.new()
	checkbox.text = "Enabled"
	checkbox.button_pressed = initial_state
	checkbox.add_theme_font_size_override("font_size", 18)
	parent.add_child(checkbox)
	return checkbox

func add_option_selector(parent: Control, initial_text: String) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	
	var left_button = Button.new()
	left_button.text = "<"
	left_button.custom_minimum_size = Vector2(50, 40)
	left_button.add_theme_font_size_override("font_size", 24)
	container.add_child(left_button)
	
	var label = Label.new()
	label.text = initial_text
	label.custom_minimum_size = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	container.add_child(label)
	
	var right_button = Button.new()
	right_button.text = ">"
	right_button.custom_minimum_size = Vector2(50, 40)
	right_button.add_theme_font_size_override("font_size", 24)
	container.add_child(right_button)
	
	parent.add_child(container)
	return container

func add_keybind_button(parent: Control, initial_text: String) -> Button:
	var button = Button.new()
	button.text = initial_text
	button.custom_minimum_size = Vector2(200, 40)
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	return button

func add_stat_row(parent: Control, label_text: String, value_text: String, stat_name: String):
	var container = HBoxContainer.new()
	container.name = stat_name + "Container"
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	container.add_child(label)
	
	var value = Label.new()
	value.name = stat_name + "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(1, 1, 1))
	container.add_child(value)
	
	parent.add_child(container)

func update_stat_value(parent: Control, stat_name: String, new_value: String):
	var value_label = parent.get_node_or_null(stat_name + "Container/" + stat_name + "Value")
	if value_label:
		value_label.text = new_value

func _on_back_pressed():
	settings.save_settings()
	
	if opened_from_pause_menu:
		var pause_menu = get_parent()
		if pause_menu and pause_menu.has_method("close_settings_menu"):
			pause_menu.close_settings_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
