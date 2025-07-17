extends Control

@onready var music_button = $MusicButton

func _ready():
	update_music_button_text()
	music_button.pressed.connect(_on_music_button_pressed)

func _on_music_button_pressed():
	AudioManager.set_music_enabled(not AudioManager.music_enabled)
	update_music_button_text()

func update_music_button_text():
	if AudioManager.music_enabled:
		music_button.text = "Music: ON"
	else:
		 music_button.text = "Music: OFF"


func _on_back_button_pressed():
	# Go back to main menu - the music will resume automatically
	get_tree().change_scene_to_file("res://path/to/your/main_menu.tscn")
