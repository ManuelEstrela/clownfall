extends Node

var is_on_steam: bool = false
var steam_id: int = 0
var steam_username: String = ""

var leaderboard_name: String = "HighScores"
var leaderboard_handle: int = 0

# DEVELOPMENT MODE - Set to false when you have your real Steam App ID
var use_placeholder_data: bool = true

signal steam_initialized(success: bool)
signal leaderboard_found(handle: int)
signal leaderboard_uploaded(success: bool)
signal leaderboard_downloaded(entries: Array)

func _ready():
	initialize_steam()

func initialize_steam():
	print("=== Initializing Steam ===")
	
	if not Steam.steamInit():
		print("❌ Steam not available")
		is_on_steam = false
		steam_initialized.emit(false)
		return
	
	is_on_steam = true
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	print("✅ Steam ready: ", steam_username)
	
	Steam.leaderboard_find_result.connect(_on_leaderboard_find_result)
	Steam.leaderboard_score_uploaded.connect(_on_leaderboard_score_uploaded)
	Steam.leaderboard_scores_downloaded.connect(_on_leaderboard_scores_downloaded)
	
	steam_initialized.emit(true)
	find_leaderboard()

func _process(_delta):
	if is_on_steam:
		Steam.run_callbacks()

func find_leaderboard():
	if not is_on_steam:
		return
	print("🔍 Finding leaderboard:", leaderboard_name)
	Steam.findLeaderboard(leaderboard_name)

func _on_leaderboard_find_result(handle: int, found: int):
	if found == 1:
		leaderboard_handle = handle
		print("✅ Leaderboard found! Handle:", handle)
		leaderboard_found.emit(handle)
	else:
		print("⚠️ Leaderboard not found")
		leaderboard_found.emit(0)

func upload_score(score: int):
	if not is_on_steam:
		print("⚠️ Steam not available - score not uploaded")
		return
		
	if leaderboard_handle == 0:
		print("⚠️ Leaderboard not ready - score not uploaded")
		return
	
	print("⬆️ Uploading score:", score)
	Steam.uploadLeaderboardScore(score, true, [], leaderboard_handle)

func _on_leaderboard_score_uploaded(success: int, _score_changed: int, new_score: int, new_rank: int, _handle: int):
	if success == 1:
		print("✅ Score uploaded! New score:", new_score, "Rank:", new_rank)
		leaderboard_uploaded.emit(true)
	else:
		print("❌ Score upload failed")
		leaderboard_uploaded.emit(false)

func download_leaderboard_top(max_entries: int = 10):
	# USE PLACEHOLDER DATA UNTIL WE HAVE REAL STEAM APP ID
	if use_placeholder_data:
		print("📋 Using placeholder leaderboard (dev mode)")
		generate_placeholder_data()
		return
	
	# Real download (will work with real Steam App ID)
	if not is_on_steam or leaderboard_handle == 0:
		print("⚠️ Can't download - no Steam/leaderboard")
		return
	
	print("⬇️ Downloading top", max_entries)
	Steam.downloadLeaderboardEntries(1, max_entries, 0, leaderboard_handle)

func _on_leaderboard_scores_downloaded(message: String, result: Array):
	print("📥 Real leaderboard data received!")
	
	var entries = []
	for entry in result:
		var player_data = {
			"steam_id": entry.get("steam_id", 0),
			"global_rank": entry.get("global_rank", 0),
			"score": entry.get("score", 0),
			"username": Steam.getFriendPersonaName(entry.get("steam_id", 0))
		}
		entries.append(player_data)
	
	leaderboard_downloaded.emit(entries)

func generate_placeholder_data():
	var placeholder_entries = [
		{"steam_id": steam_id, "global_rank": 1, "score": 500, "username": steam_username},
		{"steam_id": 123456, "global_rank": 2, "score": 350, "username": "ClownMaster99"},
		{"steam_id": 789012, "global_rank": 3, "score": 280, "username": "JugglingPro"},
		{"steam_id": 345678, "global_rank": 4, "score": 220, "username": "CircusStar"},
	]
	
	# Simulate network delay
	await get_tree().create_timer(0.5).timeout
	print("✅ Placeholder data ready!")
	leaderboard_downloaded.emit(placeholder_entries)
