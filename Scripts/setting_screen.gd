extends Control
@onready var vbox = $VBoxContainer
var music_button: Button

func _ready():
	# Wait for the scene to be fully loaded
	await get_tree().process_frame
	
	# Create the music button
	music_button = Button.new()
	music_button.name = "MusicButton"
	
	# Set size
	music_button.custom_minimum_size = Vector2(300, 80)  # Adjust size here (width, height)
	
	# Option 1: Add to Control node for free positioning
	add_child(music_button)  # Add directly to the Control node (not VBoxContainer)
	music_button.position = Vector2(100, 50)  # Set position (x, y) relative to parent
	
	# Option 2: If you want to keep it in VBoxContainer, comment out the above and uncomment below
	# vbox.add_child(music_button)
	# vbox.move_child(music_button, 0)  # Move to top
	# music_button.offset = Vector2(20, 10)  # Adjust offset within VBoxContainer
	
	# Set font size
	var font = Theme.new()
	font.set_font_size("font_size", "Button", 24)  # Adjust font size here
	music_button.theme = font
	
	# Connect and setup
	music_button.pressed.connect(_on_music_button_pressed)
	update_music_button_text()
	
	# Connect exit button
	var exit_button = $ExitSettings
	if exit_button:
		exit_button.pressed.connect(_on_exit_settings_pressed)
	else:
		print("ExitSettings button not found!")

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
