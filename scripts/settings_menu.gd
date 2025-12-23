extends Control

# Category buttons (these will have different states when you get your assets)
@onready var audio_button: Button = $CategoryButtons/AudioButton
@onready var visual_button: Button = $CategoryButtons/VisualButton
@onready var gameplay_button: Button = $CategoryButtons/GameplayButton
@onready var statistics_button: Button = $CategoryButtons/StatisticsButton
@onready var back_button: Button = $BackButton

# Category panels (only one visible at a time)
@onready var audio_panel: Control = $ContentArea/AudioPanel
@onready var visual_panel: Control = $ContentArea/VisualPanel
@onready var gameplay_panel: Control = $ContentArea/GameplayPanel
@onready var statistics_panel: Control = $ContentArea/StatisticsPanel

# Reference to settings manager
var settings: Node

# Current selected category
var current_category: String = "audio"

# Keybind listening state
var listening_for_key: bool = false
var listening_slot: String = ""  # "drop", "powerup_1", "powerup_2", "powerup_3"

func _ready():
	settings = get_node("/root/SettingsManager")
	
	# Connect category buttons
	audio_button.pressed.connect(func(): switch_category("audio"))
	visual_button.pressed.connect(func(): switch_category("visual"))
	gameplay_button.pressed.connect(func(): switch_category("gameplay"))
	statistics_button.pressed.connect(func(): switch_category("statistics"))
	back_button.pressed.connect(_on_back_pressed)
	
	# Setup all panels
	setup_audio_panel()
	setup_visual_panel()
	setup_gameplay_panel()
	setup_statistics_panel()
	
	# Show audio panel by default
	switch_category("audio")
	
	print("✅ Settings menu ready")

func switch_category(category: String):
	current_category = category
	
	# Hide all panels
	audio_panel.visible = false
	visual_panel.visible = false
	gameplay_panel.visible = false
	statistics_panel.visible = false
	
	# Update button states (you'll replace this with texture swaps when you have assets)
	audio_button.modulate = Color.WHITE
	visual_button.modulate = Color.WHITE
	gameplay_button.modulate = Color.WHITE
	statistics_button.modulate = Color.WHITE
	
	# Show selected panel and highlight button
	match category:
		"audio":
			audio_panel.visible = true
			audio_button.modulate = Color(1, 0.84, 0)  # Gold = selected
		"visual":
			visual_panel.visible = true
			visual_button.modulate = Color(1, 0.84, 0)
		"gameplay":
			gameplay_panel.visible = true
			gameplay_button.modulate = Color(1, 0.84, 0)
		"statistics":
			statistics_panel.visible = true
			statistics_button.modulate = Color(1, 0.84, 0)

# ====== AUDIO PANEL SETUP ======

func setup_audio_panel():
	var master_slider = audio_panel.get_node("MasterSlider")
	var music_slider = audio_panel.get_node("MusicSlider")
	var sfx_slider = audio_panel.get_node("SFXSlider")
	var mute_checkbox = audio_panel.get_node("MuteCheckbox")
	
	# Set initial values
	master_slider.value = settings.master_volume
	music_slider.value = settings.music_volume
	sfx_slider.value = settings.sfx_volume
	mute_checkbox.button_pressed = settings.mute_when_tabbed
	
	# Connect signals
	master_slider.value_changed.connect(func(value): 
		settings.set_master_volume(value)
		settings.save_settings()
	)
	music_slider.value_changed.connect(func(value): 
		settings.set_music_volume(value)
		settings.save_settings()
	)
	sfx_slider.value_changed.connect(func(value): 
		settings.set_sfx_volume(value)
		settings.save_settings()
	)
	mute_checkbox.toggled.connect(func(pressed):
		settings.set_mute_when_tabbed(pressed)
		settings.save_settings()
	)

# ====== VISUAL PANEL SETUP ======

func setup_visual_panel():
	# FIXED: Correct node paths - they're inside containers
	var screen_left = visual_panel.get_node("ScreenModeContainer/ScreenModeLeft")
	var screen_right = visual_panel.get_node("ScreenModeContainer/ScreenModeRight")
	var screen_label = visual_panel.get_node("ScreenModeContainer/ScreenModeLabel")
	var vsync_checkbox = visual_panel.get_node("VsyncCheckbox")
	var fps_left = visual_panel.get_node("FPSContainer/FPSLeft")
	var fps_right = visual_panel.get_node("FPSContainer/FPSRight")
	var fps_label = visual_panel.get_node("FPSContainer/FPSLabel")
	var colorblind_left = visual_panel.get_node("ColorblindContainer/ColorblindLeft")
	var colorblind_right = visual_panel.get_node("ColorblindContainer/ColorblindRight")
	var colorblind_label = visual_panel.get_node("ColorblindContainer/ColorblindLabel")
	
	# Set initial values
	screen_label.text = settings.get_screen_mode_name()
	vsync_checkbox.button_pressed = settings.vsync_enabled
	fps_label.text = settings.get_fps_cap_name()
	colorblind_label.text = settings.get_colorblind_mode_name()
	
	# Screen mode
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
	
	# VSync
	vsync_checkbox.toggled.connect(func(pressed):
		settings.set_vsync(pressed)
		settings.save_settings()
	)
	
	# FPS Cap
	fps_left.pressed.connect(func():
		cycle_fps_cap(-1, fps_label)
	)
	fps_right.pressed.connect(func():
		cycle_fps_cap(1, fps_label)
	)
	
	# Colorblind mode
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
	var fps_options = [30, 60, 120, 0]  # 0 = unlimited
	var current_index = fps_options.find(settings.fps_cap)
	if current_index == -1:
		current_index = 1  # Default to 60
	
	current_index = (current_index + direction + fps_options.size()) % fps_options.size()
	settings.set_fps_cap(fps_options[current_index])
	label.text = settings.get_fps_cap_name()
	settings.save_settings()

# ====== GAMEPLAY PANEL SETUP ======

func setup_gameplay_panel():
	var drop_assist_checkbox = gameplay_panel.get_node("DropAssistCheckbox")
	var drop_key_button = gameplay_panel.get_node("DropKeyButton")
	var powerup1_button = gameplay_panel.get_node("Powerup1Button")
	var powerup2_button = gameplay_panel.get_node("Powerup2Button")
	var powerup3_button = gameplay_panel.get_node("Powerup3Button")
	
	# Set initial values
	drop_assist_checkbox.button_pressed = settings.drop_assist_enabled
	update_keybind_button_text(drop_key_button, settings.drop_key)
	update_keybind_button_text(powerup1_button, settings.powerup_key_1)
	update_keybind_button_text(powerup2_button, settings.powerup_key_2)
	update_keybind_button_text(powerup3_button, settings.powerup_key_3)
	
	# Drop assist
	drop_assist_checkbox.toggled.connect(func(pressed):
		settings.set_drop_assist(pressed)
		settings.save_settings()
	)
	
	# Keybind buttons
	drop_key_button.pressed.connect(func():
		start_listening_for_key("drop", drop_key_button)
	)
	powerup1_button.pressed.connect(func():
		start_listening_for_key("powerup_1", powerup1_button)
	)
	powerup2_button.pressed.connect(func():
		start_listening_for_key("powerup_2", powerup2_button)
	)
	powerup3_button.pressed.connect(func():
		start_listening_for_key("powerup_3", powerup3_button)
	)

func start_listening_for_key(slot: String, button: Button):
	listening_for_key = true
	listening_slot = slot
	button.text = "Press any key..."
	button.modulate = Color(1, 1, 0)  # Yellow = listening

func update_keybind_button_text(button: Button, key: int):
	button.text = settings.get_key_name(key)
	button.modulate = Color.WHITE

func _input(event):
	if not listening_for_key:
		return
	
	if event is InputEventKey and event.pressed:
		var new_key = event.keycode
		
		# Find the button we're updating
		var button: Button = null
		match listening_slot:
			"drop":
				button = gameplay_panel.get_node("DropKeyButton")
				settings.set_drop_key(new_key)
			"powerup_1":
				button = gameplay_panel.get_node("Powerup1Button")
				settings.set_powerup_key(1, new_key)
			"powerup_2":
				button = gameplay_panel.get_node("Powerup2Button")
				settings.set_powerup_key(2, new_key)
			"powerup_3":
				button = gameplay_panel.get_node("Powerup3Button")
				settings.set_powerup_key(3, new_key)
		
		if button:
			update_keybind_button_text(button, new_key)
		
		listening_for_key = false
		listening_slot = ""
		settings.save_settings()
		
		# Consume the event so it doesn't trigger anything else
		get_viewport().set_input_as_handled()

# ====== STATISTICS PANEL SETUP ======

func setup_statistics_panel():
	# Statistics are read-only, just update the labels
	update_statistics_display()

func update_statistics_display():
	statistics_panel.get_node("BestScoreContainer/BestScoreValue").text = str(settings.best_score)
	statistics_panel.get_node("TotalRunsContainer/TotalRunsValue").text = str(settings.total_runs)
	statistics_panel.get_node("ClownsDroppedContainer/ClownsDroppedValue").text = str(settings.total_clowns_dropped)
	
	# Clown name for highest tier
	var clown_names = ["Tessa", "Twinkles", "Reina", "Osvaldo", "Hazel", "Mumbles", "Sneaky", "Wendy", "Chatty", "Cups", "Kirk"]
	var tier_text = "None"
	if settings.highest_tier_created < clown_names.size():
		tier_text = clown_names[settings.highest_tier_created]
	statistics_panel.get_node("HighestTierContainer/HighestTierValue").text = tier_text
	
	statistics_panel.get_node("CurrencyContainer/CurrencyValue").text = str(settings.total_currency_earned)
	statistics_panel.get_node("TimePlayedContainer/TimePlayedValue").text = settings.format_time_played()

func _on_back_pressed():
	# Save settings before leaving
	settings.save_settings()
	
	# Go back to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
