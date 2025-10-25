extends PanelContainer

@onready var rank_label: Label = $MarginContainer/HBoxContainer/RankLabel
@onready var username_label: Label = $MarginContainer/HBoxContainer/UsernameLabel
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel

func set_data(rank: int, username: String, score: int, is_first: bool = false, is_current_player: bool = false):
	print("      Setting entry data: Rank ", rank, " | ", username, " | Score ", score)
	
	# Verify all labels exist
	if not rank_label or not username_label or not score_label:
		print("      ❌ ERROR: One or more labels not found!")
		return
	
	# Set rank with medals for top 3
	var rank_text = ""
	match rank:
		1: rank_text = "🥇 1st"
		2: rank_text = "🥈 2nd"
		3: rank_text = "🥉 3rd"
		_: rank_text = "#" + str(rank)
	
	rank_label.text = rank_text
	username_label.text = username
	score_label.text = str(score)
	
	print("      ✓ Labels set successfully")
	
	# Highlight current player with yellow background
	if is_current_player:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.9, 0.5, 0.4)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.84, 0.0)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		add_theme_stylebox_override("panel", style)
		print("      ✓ Applied current player style")
	# Make first place extra special (only if not current player)
	elif is_first:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.85, 0.0, 0.2)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		add_theme_stylebox_override("panel", style)
		print("      ✓ Applied first place style")
