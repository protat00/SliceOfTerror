extends Control

func _ready():
	var bg_music = load("res://Audio/main_menu_music.mp3")
	# Third parameter is volume in decibels (0.0 = full volume, negative = quieter)
	MusicManager.play_music_for_scene(bg_music, "MainMenu", -10.0)
