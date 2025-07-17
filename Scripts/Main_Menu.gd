extends Control

func _ready():
	# Load and play your background music
	var bg_music = load("res://Audio/main_menu_music.mp3")  # Use your actual file name
	AudioManager.play_music(bg_music)

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://scenes/SettingsMenu.tscn")
