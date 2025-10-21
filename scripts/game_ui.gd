extends CanvasLayer

@onready var score_label: Label = $ScoreLabel

func update_score(new_score: int):
	score_label.text = "Score: " + str(new_score)

func show_game_over(final_score: int):
	# TODO: Create game over popup
	print("Game Over! Final Score: ", final_score)
