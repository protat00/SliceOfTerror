
# Audio tracks dictionary - replace with your actual audio files

extends Node

# Audio Manager Singleton for Godot 4
# To use: Add this scene as an autoload in Project Settings -> Autoload

@onready var audio_player_1: AudioStreamPlayer = $AudioPlayer1
@onready var audio_player_2: AudioStreamPlayer = $AudioPlayer2

var current_player: AudioStreamPlayer
var fade_player: AudioStreamPlayer
var current_track: String = ""
var is_fading: bool = false
var fade_tween: Tween

# Audio tracks dictionary - replace with your actual audio files
# Format: "track_name": {"stream": AudioStream, "volume": float}

var audio_tracks: Dictionary = {
	"main_menu": {"stream":preload("res://Audio/main_menu_music.mp3"),"volume":1.0},
	"ambient": {"stream":preload("res://Audio/game_ambient_music.mp3"),"volume":0.1},

}


# Fade duration in seconds
var fade_duration: float = 1.0
var master_volume: float = 1.0

func _ready():
	# Initialize the audio players
	current_player = audio_player_1
	fade_player = audio_player_2
	
	# Set initial volumes
	audio_player_1.volume_db = linear_to_db(0.0)
	audio_player_2.volume_db = linear_to_db(0.0)
	
	# Create tween for fading
	fade_tween = create_tween()
	fade_tween.kill()

func play_track(track_name: String, loop: bool = true, fade_in: bool = false) -> void:
	"""Play a track by name. Optionally fade in."""
	if not audio_tracks.has(track_name):
		push_error("Audio track '" + track_name + "' not found!")
		return
	
	# If the same track is already playing, do nothing
	if current_track == track_name and current_player.playing:
		return
	
	# Stop any current fade
	if fade_tween:
		fade_tween.kill()
	
	# Get the audio stream and track volume
	var track_data = audio_tracks[track_name]
	var stream = track_data["stream"]
	var track_volume = track_data.get("volume", 1.0)
	
	current_player.stream = stream
	
	# Set loop mode if the stream supports it
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = loop
	
	var final_volume = master_volume * track_volume
	
	if fade_in:
		current_player.volume_db = linear_to_db(0.0)
		current_player.play()
		
		fade_tween = create_tween()
		fade_tween.tween_method(_set_player_volume, 0.0, final_volume, fade_duration)
	else:
		current_player.volume_db = linear_to_db(final_volume)
		current_player.play()
	
	current_track = track_name

func change_track(new_track_name: String, loop: bool = true) -> void:
	"""Change to a new track with crossfade transition."""
	if not audio_tracks.has(new_track_name):
		push_error("Audio track '" + new_track_name + "' not found!")
		return
	
	# If the same track is requested, do nothing
	if current_track == new_track_name:
		return
	
	# If no track is currently playing, just play the new one
	if not current_player.playing:
		play_track(new_track_name, loop, true)
		return
	
	# Prevent multiple simultaneous fades
	if is_fading:
		return
	
	is_fading = true
	
	# Set up the new track on the fade player
	var track_data = audio_tracks[new_track_name]
	var stream = track_data["stream"]
	var track_volume = track_data.get("volume", 1.0)
	
	fade_player.stream = stream
	
	# Set loop mode if the stream supports it
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = loop
	
	# Start the new track at 0 volume
	fade_player.volume_db = linear_to_db(0.0)
	fade_player.play()
	
	# Stop any current tween
	if fade_tween:
		fade_tween.kill()
	
	# Get current and new track volumes
	var current_track_volume = _get_track_volume(current_track)
	var new_track_volume = track_volume
	
	var current_final_volume = master_volume * current_track_volume
	var new_final_volume = master_volume * new_track_volume
	
	# Create crossfade tween
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out current player
	fade_tween.tween_method(_set_current_player_volume, current_final_volume, 0.0, fade_duration)
	
	# Fade in new player
	fade_tween.tween_method(_set_fade_player_volume, 0.0, new_final_volume, fade_duration)
	
	# When fade completes, swap the players
	fade_tween.tween_callback(_complete_track_change.bind(new_track_name)).set_delay(fade_duration)

func stop_track(fade_out: bool = false) -> void:
	"""Stop the currently playing track. Optionally fade out."""
	if not current_player.playing:
		return
	
	if fade_out:
		if fade_tween:
			fade_tween.kill()
		
		is_fading = true
		var track_volume = _get_track_volume(current_track)
		var current_final_volume = master_volume * track_volume
		
		fade_tween = create_tween()
		fade_tween.tween_method(_set_player_volume, current_final_volume, 0.0, fade_duration)
		fade_tween.tween_callback(_complete_stop)
	else:
		current_player.stop()
		current_track = ""

func stop_all_tracks() -> void:
	"""Immediately stop all audio players."""
	if fade_tween:
		fade_tween.kill()
	
	audio_player_1.stop()
	audio_player_2.stop()
	current_track = ""
	is_fading = false

func set_master_volume(volume: float) -> void:
	"""Set the master volume (0.0 to 1.0)."""
	master_volume = clamp(volume, 0.0, 1.0)
	
	if current_player.playing and not is_fading:
		var track_volume = _get_track_volume(current_track)
		var final_volume = master_volume * track_volume
		current_player.volume_db = linear_to_db(final_volume)

func get_current_track() -> String:
	"""Get the name of the currently playing track."""
	return current_track

func is_track_playing(track_name: String = "") -> bool:
	"""Check if a track is playing. If no track name provided, checks if any track is playing."""
	if track_name == "":
		return current_player.playing
	else:
		return current_track == track_name and current_player.playing

func add_track(track_name: String, audio_stream: AudioStream, volume: float = 1.0) -> void:
	"""Add a new track to the dictionary at runtime."""
	audio_tracks[track_name] = {"stream": audio_stream, "volume": clamp(volume, 0.0, 1.0)}

func remove_track(track_name: String) -> void:
	"""Remove a track from the dictionary."""
	if audio_tracks.has(track_name):
		audio_tracks.erase(track_name)

func set_track_volume(track_name: String, volume: float) -> void:
	"""Set the volume for a specific track (0.0 to 1.0)."""
	if not audio_tracks.has(track_name):
		push_error("Audio track '" + track_name + "' not found!")
		return
	
	var clamped_volume = clamp(volume, 0.0, 1.0)
	audio_tracks[track_name]["volume"] = clamped_volume
	
	# If this track is currently playing, update the player volume
	if current_track == track_name and current_player.playing and not is_fading:
		var final_volume = master_volume * clamped_volume
		current_player.volume_db = linear_to_db(final_volume)

func get_track_volume(track_name: String) -> float:
	"""Get the volume setting for a specific track."""
	if not audio_tracks.has(track_name):
		push_error("Audio track '" + track_name + "' not found!")
		return 0.0
	
	return audio_tracks[track_name].get("volume", 1.0)

# Private helper methods
func _get_track_volume(track_name: String) -> float:
	"""Get the volume for a track, with fallback to 1.0."""
	if track_name == "" or not audio_tracks.has(track_name):
		return 1.0
	return audio_tracks[track_name].get("volume", 1.0)

func _set_player_volume(volume: float) -> void:
	current_player.volume_db = linear_to_db(volume)

func _set_current_player_volume(volume: float) -> void:
	current_player.volume_db = linear_to_db(volume)

func _set_fade_player_volume(volume: float) -> void:
	fade_player.volume_db = linear_to_db(volume)

func _complete_track_change(new_track_name: String) -> void:
	# Stop the old player
	current_player.stop()
	
	# Swap the players
	var temp = current_player
	current_player = fade_player
	fade_player = temp
	
	# Update current track
	current_track = new_track_name
	is_fading = false

func _complete_stop() -> void:
	current_player.stop()
	current_track = ""
	is_fading = false
