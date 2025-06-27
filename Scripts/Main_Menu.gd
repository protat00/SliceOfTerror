extends Control

@onready var background_music = $background_music

func _ready():
	# If returning from settings, restore music
	if GameGlobal.was_music_playing and GameGlobal.music_resource:
		background_music.stream = GameGlobal.music_resource
		background_music.play()
		background_music.seek(GameGlobal.music_position)
		# Reset the flag
		GameGlobal.was_music_playing = false
	else:
		# First time loading, start music normally
		background_music.play()

func _on_settings_button_pressed():
	# Save current music state before leaving
	GameGlobal.music_position = background_music.get_playback_position()
	GameGlobal.was_music_playing = background_music.playing
	GameGlobal.music_resource = background_music.stream
	
	# Change to settings scene
	get_tree().change_scene_to_file("res://path/to/your/settings.tscn")
