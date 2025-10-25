extends PanelContainer

@onready var rank_label: Label = $HBoxContainer/RankLabel
@onready var username_label: Label = $HBoxContainer/UsernameLabel
@onready var score_label: Label = $HBoxContainer/ScoreLabel

func set_data(rank: int, username: String, score: int, is_first: bool = false, is_current_player: bool = false):
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
	
	# Highlight current player with yellow background
	if is_current_player:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.9, 0.5, 0.3)
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_color = Color(1.0, 0.84, 0.0)
		add_theme_stylebox_override("panel", style)
	
	# Make first place extra special
	if is_first and not is_current_player:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.85, 0.0, 0.15)
		add_theme_stylebox_override("panel", style)
