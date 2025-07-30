extends CanvasLayer
@onready var vbox = $VBoxContainer
@onready var music_button: Button = $VBoxContainer/Button

func _ready():
	# Wait for the scene to be fully loaded
	
	music_button.pressed.connect(_on_music_button_pressed)
	update_music_button_text()
	
	# Connect exit button
	var exit_button = $ExitSettings
	if exit_button:
		exit_button.pressed.connect(_on_exit_settings_pressed)
	else:
		print("ExitSettings button not found!")

func _on_music_button_pressed():
	MusicManager.set_music_enabled(not MusicManager.music_enabled)
	update_music_button_text()

func update_music_button_text():
	if MusicManager.music_enabled:
		music_button.text = "Music: ON"
	else:
		music_button.text = "Music: OFF"

func _on_exit_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Title_screen.tscn")
