extends Control

@onready var vbox = $VBoxContainer
@onready var music_button: Button

func _ready():
	# Create the music button
	music_button = Button.new()
	music_button.name = "MusicButton"
	
	# Add it to the VBoxContainer
	vbox.add_child(music_button)
	vbox.move_child(music_button, 0)  # Move to top
	
	# Connect and setup
	update_music_button_text()
	music_button.pressed.connect(_on_music_button_pressed)
	
	# Connect exit button - it's directly under root, not in VBoxContainer
	var exit_button = $ExitSettings
	exit_button.pressed.connect(_on_exit_settings_pressed)

func _on_music_button_pressed():
	AudioManager.set_music_enabled(not AudioManager.music_enabled)
	update_music_button_text()

func update_music_button_text():
	if AudioManager.music_enabled:
		music_button.text = "Music: ON"
	else:
		music_button.text = "Music: OFF"


func _on_exit_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Title_screen.tscn")
