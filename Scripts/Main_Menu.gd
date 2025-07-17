extends Control

func _ready():
	# Load and play your background music
 # In AudioManager.gd
	const MAIN_MENU_MUSIC = preload("res://audio/main_menu_music.ogg")
	const GAME_MUSIC = preload("res://audio/game_music.ogg")
	const BOSS_MUSIC = preload("res://audio/boss_music.ogg")

func play_main_menu_music():
	play_music(MAIN_MENU_MUSIC)

func _on_settings_button_pressed():
	# The music will continue playing when you load the settings scene
	get_tree().change_scene_to_file("res://scenes/SettingsMenu.tscn")
