extends Node
var music_player: AudioStreamPlayer
var music_enabled: bool = true
var current_music_stream: AudioStream
var current_music_scene: String = ""  # Track which scene's music is playing

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Load the saved music setting
	load_music_setting()

func play_music_for_scene(stream: AudioStream, scene_name: String, volume: float = 0.0):
	# Only change music if we're switching to a different scene's music
	if current_music_scene != scene_name or not music_player.playing:
		current_music_scene = scene_name
		current_music_stream = stream
		
		if music_enabled:
			# Stop any currently playing music first
			if music_player.playing:
				music_player.stop()
			
			music_player.stream = stream
			music_player.volume_db = volume
			music_player.play()

func play_music(stream: AudioStream, volume: float = 0.0):
	# Stop any currently playing music first
	if music_player.playing:
		music_player.stop()
	
	current_music_stream = stream
	current_music_scene = ""  # Clear scene tracking for direct music calls
	
	if music_enabled:
		music_player.stream = stream
		music_player.volume_db = volume
		music_player.play()

func stop_music():
	music_player.stop()
	current_music_scene = ""

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

# Added method to check if specific music is already playing
func is_playing_music(music_resource: AudioStream) -> bool:
	if music_player and music_player.playing and current_music_stream:
		return current_music_stream == music_resource
	return false
	
# Add to your MusicManager autoload
func set_volume(volume_db: float):
	music_player.volume_db = volume_db

func get_volume() -> float:
	return music_player.volume_db

func fade_volume(target_volume: float, duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", target_volume, duration)
