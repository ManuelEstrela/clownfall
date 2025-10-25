extends Control

@onready var leaderboard_container = $Panel/VBoxContainer/LeaderboardContainer
@onready var loading_label = $Panel/VBoxContainer/LoadingLabel
@onready var refresh_button = $Panel/VBoxContainer/RefreshButton

const LeaderboardEntry = preload("res://ui/leaderboard_entry.tscn")

var steam_manager
var current_player_steam_id: int = 0

func _ready():
	steam_manager = get_node_or_null("/root/SteamManager")
	
	if steam_manager:
		steam_manager.leaderboard_downloaded.connect(_on_leaderboard_downloaded)
		steam_manager.steam_initialized.connect(_on_steam_initialized)
		current_player_steam_id = steam_manager.steam_id
	
	refresh_button.pressed.connect(refresh_leaderboard)
	
	# Wait a moment for Steam to initialize, then load
	await get_tree().create_timer(1.0).timeout
	refresh_leaderboard()

func _on_steam_initialized(success: bool):
	if success:
		current_player_steam_id = steam_manager.steam_id

func refresh_leaderboard():
	if not steam_manager:
		show_error("Steam Manager not found")
		return
	
	show_loading()
	
	# Request leaderboard data (will use placeholder if not available)
	steam_manager.download_leaderboard_top(10)

func _on_leaderboard_downloaded(entries: Array):
	print("🎮 Leaderboard UI: Received", entries.size(), "entries")
	
	loading_label.visible = false
	
	# Clear old entries
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	if entries.size() == 0:
		show_error("No scores yet! Play to set a score!")
		return
	
	# Show top 3
	var player_in_top_3 = false
	for i in range(min(3, entries.size())):
		var entry = entries[i]
		create_entry(entry, i == 0, entry.steam_id == current_player_steam_id)
		
		if entry.steam_id == current_player_steam_id:
			player_in_top_3 = true
	
	# If player not in top 3, show 4th place OR player's position
	if not player_in_top_3:
		if entries.size() >= 4:
			add_separator()
			# Check if player is 4th or beyond
			var found_player = false
			for entry in entries:
				if entry.steam_id == current_player_steam_id:
					create_entry(entry, false, true)
					found_player = true
					break
			
			# If player not found in results, show 4th place
			if not found_player and entries.size() >= 4:
				create_entry(entries[3], false, false)

func create_entry(entry: Dictionary, is_first: bool, is_current: bool):
	var entry_node = LeaderboardEntry.instantiate()
	leaderboard_container.add_child(entry_node)
	entry_node.set_data(entry.global_rank, entry.username, entry.score, is_first, is_current)

func add_separator():
	var sep = HSeparator.new()
	leaderboard_container.add_child(sep)
	
	var dots = Label.new()
	dots.text = "..."
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_container.add_child(dots)

func show_loading(message: String = "Loading leaderboard..."):
	loading_label.text = message
	loading_label.visible = true
	for child in leaderboard_container.get_children():
		child.queue_free()

func show_error(msg: String):
	loading_label.text = msg
	loading_label.visible = true
