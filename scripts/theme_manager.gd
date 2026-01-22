extends Node

# Change this to switch themes: "blue", "pink", "purple", "red", "yellow", "green"
var current_theme: String = "purple"

# Get themed asset path
func get_themed_asset(category: String) -> String:
	return "res://assets/images/" + category + "/" + category + "_" + current_theme + ".png"

# Load themed textures
func get_balloon_texture() -> Texture2D:
	return load(get_themed_asset("balloon"))

func get_box_texture() -> Texture2D:
	return load(get_themed_asset("box"))

func get_box_square_texture() -> Texture2D:
	return load("res://assets/images/box/square_" + current_theme + ".png")

func get_clown_cycle_texture() -> Texture2D:
	return load(get_themed_asset("clown_cycle"))

func get_leaderboard_texture() -> Texture2D:
	return load(get_themed_asset("leaderboard"))
