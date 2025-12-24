extends CanvasLayer

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton

var is_paused: bool = false
var settings_menu_scene = preload("res://scenes/settings_menu.tscn")
var settings_menu_instance = null

func _ready():
	# Hide pause menu by default
	visible = false
	
	# Connect to settings manager to restore settings when resuming
	var settings = get_node_or_null("/root/SettingsManager")
	if settings:
		settings.visual_changed.connect(_on_settings_changed)

func _input(event):
	# Listen for ESC key
	if event.is_action_pressed("ui_cancel"):  # ESC key
		if settings_menu_instance:
			# If settings menu is open, close it
			close_settings_menu()
		elif is_paused:
			# If paused, resume
			resume_game()
		else:
			# If playing, pause
			pause_game()
		
		get_viewport().set_input_as_handled()

func pause_game():
	is_paused = true
	visible = true
	get_tree().paused = true
	print("⏸️ Game paused")

func resume_game():
	is_paused = false
	visible = false
	get_tree().paused = false
	print("▶️ Game resumed")

func _on_resume_pressed():
	resume_game()

func _on_settings_pressed():
	print("⚙️ Opening settings from pause menu")
	
	# Create settings menu instance
	settings_menu_instance = settings_menu_scene.instantiate()
	add_child(settings_menu_instance)
	
	# Move it to be on top
	move_child(settings_menu_instance, get_child_count() - 1)
	
	# Hide pause menu buttons (but keep the overlay/blur)
	$CenterContainer.visible = false

func close_settings_menu():
	if settings_menu_instance:
		settings_menu_instance.queue_free()
		settings_menu_instance = null
		
		# Show pause menu buttons again
		$CenterContainer.visible = true
		
		print("⚙️ Settings closed, back to pause menu")

func _on_settings_changed():
	# Settings were changed, nothing special needed since settings are auto-applied
	pass

func _on_menu_pressed():
	print("🏠 Returning to main menu")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Go to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
