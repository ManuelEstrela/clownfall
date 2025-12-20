extends CanvasLayer

# Theme manager
var theme_manager = preload("res://scripts/theme_manager.gd").new()

# ====== LEADERBOARD POSITIONING & SIZING ======
var leaderboard_x: float = 200          # Left-right position
var leaderboard_y: float = 430          # Up-down position (center point)
var leaderboard_scale: float = 0.65      # Size multiplier

# Entry positioning (relative to leaderboard sprite)
var entries_start_y: float = -80        # Where first entry starts (relative to center)
var entry_spacing: float = 38           # Vertical space between entries
var entry_x_offset: float = 0           # Horizontal offset from center

# Text settings
var rank_x: float = -120                # Rank text position
var name_x: float = -20                 # Name text position  
var score_x: float = 100                # Score text position
var font_size: int = 16
# ============================================

var steam_manager
var current_player_steam_id: int = 0
var leaderboard_sprite: Sprite2D = null
var entry_labels: Array = []  # Store all label nodes

func _ready():
	print("🎮 Leaderboard UI: Starting initialization...")
	
	# Create the leaderboard sprite
	leaderboard_sprite = Sprite2D.new()
	leaderboard_sprite.texture = theme_manager.get_leaderboard_texture()
	leaderboard_sprite.z_index = 200
	add_child(leaderboard_sprite)
	leaderboard_sprite.position = Vector2(leaderboard_x, leaderboard_y)
	leaderboard_sprite.scale = Vector2(leaderboard_scale, leaderboard_scale)
	
	print("🎨 Leaderboard sprite created")
	
	steam_manager = get_node_or_null("/root/SteamManager")
	
	if steam_manager:
		steam_manager.leaderboard_downloaded.connect(_on_leaderboard_downloaded)
		steam_manager.steam_initialized.connect(_on_steam_initialized)
		current_player_steam_id = steam_manager.steam_id
		print("✅ Connected to SteamManager")
	else:
		print("⚠️ SteamManager not found")
	
	# Wait a moment for Steam to initialize, then load
	await get_tree().create_timer(1.0).timeout
	refresh_leaderboard()

func _on_steam_initialized(success: bool):
	if success:
		current_player_steam_id = steam_manager.steam_id

func refresh_leaderboard():
	if not steam_manager:
		print("⚠️ Steam Manager not found")
		return
	
	print("📊 Requesting leaderboard data...")
	steam_manager.download_leaderboard_top(10)

func _on_leaderboard_downloaded(entries: Array):
	print("🎮 Leaderboard UI: Received ", entries.size(), " entries")
	
	# Clear old entry labels
	for label in entry_labels:
		label.queue_free()
	entry_labels.clear()
	
	if entries.size() == 0:
		print("⚠️ No scores yet!")
		return
	
	print("📋 Creating leaderboard entries...")
	
	# Show entries (up to 4 to match your leaderboard design)
	for i in range(min(4, entries.size())):
		var entry = entries[i]
		create_entry_labels(entry, i)
	
	await get_tree().process_frame
	print("✅ Leaderboard populated with ", entry_labels.size() / 3, " entries")

func create_entry_labels(entry: Dictionary, index: int):
	var y_pos = entries_start_y + (index * entry_spacing)
	var is_current_player = (entry.steam_id == current_player_steam_id)
	
	# Color for text
	var text_color = Color(1, 1, 1) if not is_current_player else Color(1, 0.9, 0.3)
	
	# Rank label
	var rank_label = Label.new()
	leaderboard_sprite.add_child(rank_label)
	rank_label.add_theme_font_size_override("font_size", font_size)
	rank_label.add_theme_color_override("font_color", text_color)
	rank_label.text = get_rank_text(entry.global_rank)
	rank_label.position = Vector2(rank_x, y_pos)
	entry_labels.append(rank_label)
	
	# Name label
	var name_label = Label.new()
	leaderboard_sprite.add_child(name_label)
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.add_theme_color_override("font_color", text_color)
	name_label.text = entry.username
	name_label.position = Vector2(name_x, y_pos)
	entry_labels.append(name_label)
	
	# Score label
	var score_label = Label.new()
	leaderboard_sprite.add_child(score_label)
	score_label.add_theme_font_size_override("font_size", font_size)
	score_label.add_theme_color_override("font_color", text_color)
	score_label.text = str(entry.score)
	score_label.position = Vector2(score_x, y_pos)
	entry_labels.append(score_label)
	
	print("  ✓ Entry ", index + 1, ": ", entry.username, " - ", entry.score)

func get_rank_text(rank: int) -> String:
	match rank:
		1: return "🥇"
		2: return "🥈"
		3: return "🥉"
		4: return "#4"
		_: return "#" + str(rank)
