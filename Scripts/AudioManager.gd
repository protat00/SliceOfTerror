extends Node

var music_player: AudioStreamPlayer

func _ready():
	# Create the music player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Set it to loop if you want
	music_player.finished.connect(_on_music_finished)

func play_music(stream: AudioStream, volume: float = 0.0):
	if music_player.stream != stream:
		music_player.stream = stream
		music_player.volume_db = volume
		music_player.play()

func stop_music():
	music_player.stop()

func pause_music():
	music_player.stream_paused = true

func resume_music():
	music_player.stream_paused = false

func set_music_volume(volume: float):
	music_player.volume_db = volume

func _on_music_finished():
	# Restart the music if you want it to loop
	music_player.play()
