extends Control

func _ready():
	# Load and play your background music using the new scene-aware method
	var bg_music = load("res://Audio/main_menu_music.mp3")  # Use your actual file name
	
	# Use the correct autoload name and scene-aware music method
	MusicManager.play_music_for_scene(bg_music, "MainMenu")
