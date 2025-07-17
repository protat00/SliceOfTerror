extends Node

var music_player: AudioStreamPlayer
var music_enabled: bool = true
var current_music_stream: AudioStream

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Load the saved music setting
	load_music_setting()

func play_music(stream: AudioStream, volume: float = 0.0):
	current_music_stream = stream
	if music_enabled:
		music_player.stream = stream
		music_player.volume_db = volume
		music_player.play()

func stop_music():
	music_player.stop()

func set_music_enabled(enabled: bool):
	music_enabled = enabled
	
	if enabled:
		# Turn music back on
		if current_music_stream and not music_player.playing:
			music_player.stream = current_music_stream
			music_player.play()
	else:
		# Turn music off
		music_player.stop()
	
	# Save the setting
	save_music_setting()

func save_music_setting():
	var config = ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.save("user://settings.cfg")

func load_music_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		music_enabled = config.get_value("audio", "music_enabled", true)
