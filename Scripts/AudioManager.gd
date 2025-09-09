extends Node

# Global Audio Manager - Add as AutoLoad singleton
# Handles music playback with smooth fade transitions

# Dictionary to store all music tracks
var music_tracks = {
	"menu": "res://audio/music/menu_theme.ogg",
	"gameplay": "res://audio/music/gameplay_theme.ogg",
	"boss": "res://audio/music/boss_battle.ogg",
	"victory": "res://audio/music/victory_fanfare.ogg",
	"credits": "res://audio/music/credits_theme.ogg",
	"ambient_forest": "res://audio/music/ambient_forest.ogg",
	"dungeon": "res://audio/music/dungeon_theme.ogg"
}

# Audio players for crossfading
@onready var current_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var fade_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Current track info
var current_track: String = ""
var is_playing: bool = false

# Fade settings
var fade_duration: float = 1.0
var master_volume: float = 1.0

# Tween for smooth volume transitions
@onready var tween: Tween = Tween.new()

func _ready():
	# Set initial volumes
	current_player.volume_db = linear_to_db(master_volume)
	fade_player.volume_db = linear_to_db(0.0)

# Play a specific track by name
func play_track(track_name: String, fade_in: bool = true):
	if not music_tracks.has(track_name):
		print("Warning: Track '" + track_name + "' not found in music_tracks dictionary")
		return
	
	# If same track is already playing, do nothing
	if current_track == track_name and is_playing:
		return
	
	var new_stream = load(music_tracks[track_name])
	if not new_stream:
		print("Error: Could not load audio file: " + music_tracks[track_name])
		return
	
	if fade_in and is_playing:
		# Crossfade to new track
		_crossfade_to_track(new_stream, track_name)
	else:
		# Direct play without fade
		current_player.stream = new_stream
		current_player.play()
		current_track = track_name
		is_playing = true
		current_player.volume_db = linear_to_db(master_volume)

# Stop current track
func stop_track(fade_out: bool = true):
	if not is_playing:
		return
	
	if fade_out:
		# Fade out current track
		tween = create_tween()
		tween.tween_property(current_player, "volume_db", 
			linear_to_db(0.0), fade_duration)
		
		# Stop after fade completes
		await tween.finished
		current_player.stop()
	else:
		# Immediate stop
		current_player.stop()
	
	current_track = ""
	is_playing = false

# Change to a different track with crossfade
func change_track(new_track: String):
	if not music_tracks.has(new_track):
		print("Warning: Track '" + new_track + "' not found in music_tracks dictionary")
		return
	
	# If not currently playing, just start the new track
	if not is_playing:
		play_track(new_track, false)
		return
	
	# If same track, do nothing
	if current_track == new_track:
		return
	
	var new_stream = load(music_tracks[new_track])
	if not new_stream:
		print("Error: Could not load audio file: " + music_tracks[new_track])
		return
	
	_crossfade_to_track(new_stream, new_track)

# Internal function to handle crossfading
func _crossfade_to_track(new_stream: AudioStream, track_name: String):
	# Set up the fade player with new track
	fade_player.stream = new_stream
	fade_player.volume_db = linear_to_db(0.0)
	fade_player.play()
	
	# Crossfade: fade out current, fade in new
	tween.parallel().interpolate_property(current_player, "volume_db",
		current_player.volume_db, linear_to_db(0.0), fade_duration,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	
	tween.parallel().interpolate_property(fade_player, "volume_db",
		linear_to_db(0.0), linear_to_db(master_volume), fade_duration,
		Tween.TRANS_SINE, Tween.EASE_IN)
	
	tween.start()
	
	# When fade completes, swap the players
	await tween.finished
	_swap_players()
	current_track = track_name

# Swap current and fade players
func _swap_players():
	var temp = current_player
	current_player = fade_player
	fade_player = temp
	
	# Stop and reset the old player
	fade_player.stop()
	fade_player.volume_db = linear_to_db(0.0)

# Pause current track
func pause_track():
	if is_playing:
		current_player.stream_paused = true

# Resume paused track
func resume_track():
	if is_playing:
		current_player.stream_paused = false

# Set master volume (0.0 to 1.0)
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	if is_playing:
		current_player.volume_db = linear_to_db(master_volume)

# Set fade duration for transitions
func set_fade_duration(duration: float):
	fade_duration = max(duration, 0.1)

# Get current track name
func get_current_track() -> String:
	return current_track

# Check if audio is currently playing
func is_track_playing() -> bool:
	return is_playing and current_player.playing

# Add a new track to the dictionary at runtime
func add_track(track_name: String, file_path: String):
	music_tracks[track_name] = file_path

# Remove a track from the dictionary
func remove_track(track_name: String):
	if music_tracks.has(track_name):
		music_tracks.erase(track_name)

# Get list of available tracks
func get_available_tracks() -> Array:
	return music_tracks.keys()
