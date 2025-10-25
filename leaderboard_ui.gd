extends CanvasLayer

@onready var leaderboard_container = $Panel/VBoxContainer/ScrollContainer/LeaderboardMargin/LeaderboardContainer
@onready var loading_label = $Panel/VBoxContainer/ScrollContainer/LeaderboardMargin/LoadingLabel
@onready var refresh_button = $Panel/VBoxContainer/BottomMargin/RefreshButton

const LeaderboardEntry = preload("res://ui/leaderboard_entry.tscn")

var steam_manager
var current_player_steam_id: int = 0

func _ready():
	print("🎮 Leaderboard UI: Starting initialization...")
	
	# Verify nodes exist
	if not leaderboard_container:
		print("❌ ERROR: leaderboard_container not found!")
		return
	if not loading_label:
		print("❌ ERROR: loading_label not found!")
		return
		
	print("✅ All UI nodes found successfully")
	
	steam_manager = get_node_or_null("/root/SteamManager")
	
	if steam_manager:
		steam_manager.leaderboard_downloaded.connect(_on_leaderboard_downloaded)
		steam_manager.steam_initialized.connect(_on_steam_initialized)
		current_player_steam_id = steam_manager.steam_id
		print("✅ Connected to SteamManager")
	else:
		print("⚠️ SteamManager not found")
	
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
	print("🎮 Leaderboard UI: Received ", entries.size(), " entries")
	
	loading_label.visible = false
	
	# Clear old entries
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	if entries.size() == 0:
		show_error("No scores yet! Play to set a score!")
		return
	
	print("📋 Creating leaderboard entries...")
	
	# Show all entries (up to 10)
	for i in range(min(10, entries.size())):
		var entry = entries[i]
		print("  Creating entry ", i + 1, ": ", entry.username, " - ", entry.score)
		create_entry(entry, i == 0, entry.steam_id == current_player_steam_id)
	
	# Force update
	await get_tree().process_frame
	print("✅ Leaderboard populated with ", leaderboard_container.get_child_count(), " entries")

func create_entry(entry: Dictionary, is_first: bool, is_current: bool):
	var entry_node = LeaderboardEntry.instantiate()
	leaderboard_container.add_child(entry_node)
	
	# Make sure it's visible
	entry_node.visible = true
	entry_node.modulate.a = 1.0
	
	entry_node.set_data(entry.global_rank, entry.username, entry.score, is_first, is_current)
	print("    ✓ Entry node created and visible")

func show_loading(message: String = "Loading leaderboard..."):
	print("📊 Showing loading: ", message)
	loading_label.text = message
	loading_label.visible = true
	for child in leaderboard_container.get_children():
		child.queue_free()

func show_error(msg: String):
	print("❌ Error: ", msg)
	loading_label.text = msg
	loading_label.visible = true
