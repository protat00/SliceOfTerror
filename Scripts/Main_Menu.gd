extends Control

#func _ready():
	#var bg_music = load("res://Audio/main_menu_music.mp3")
	## Only play music if it's not already playing this track
	## The play_music_for_scene method should handle this, but let's be explicit
	#if not MusicManager.is_playing_music(bg_music):
		#MusicManager.play_music_for_scene(bg_music, "MainMenu", -10.0)
