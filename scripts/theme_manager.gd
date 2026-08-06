extends Node

# Themes: "blue", "pink", "purple", "red", "yellow", "green"
#
# This script is instantiated with .new() rather than being an autoload, so a
# fresh copy is created wherever it's used and it is NOT inside the scene
# tree. That means get_node("/root/SettingsManager") won't work here — we go
# through the main loop's root instead.
#
# The theme used to be a hardcoded default that reset on every instantiation,
# which meant nothing the player unlocked could ever take effect. It now
# mirrors whatever SettingsManager has saved, falling back to the default if
# the autoload isn't available (e.g. running a scene in isolation).
var current_theme: String = "purple"

func _init():
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var settings = loop.root.get_node_or_null("SettingsManager")
		if settings and settings.current_theme != "":
			current_theme = settings.current_theme

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
