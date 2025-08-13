# LifeManager.gd
# This should be set up as an Autoload/Singleton
# Go to Project > Project Settings > Autoload and add this script
extends Node

signal life_lost(current_lives: int)
signal life_gained(current_lives: int)
signal game_over
signal player_died

@export var max_lives: int = 3
@export var game_over_scene_path: String = "res://death_screen.tscn"  # Your death scene path
@export var game_over_delay: float = 1.5  # Delay before switching to death scene
@export var fade_duration: float = 1.0  # Duration of fade transition
@export var enable_death_sound: bool = true
@export var death_sound: AudioStream  # Optional death sound effect

var current_lives: int
var hearts: Array[AnimatedSprite2D] = []
var total_deaths: int = 0  # Track total deaths for stats
var deaths_this_level: int = 0
var audio_player: AudioStreamPlayer

# Fade transition
var fade_overlay: ColorRect
var is_transitioning: bool = false

# Game session stats
var session_start_time: float
var session_souls_collected: int = 0
var session_levels_completed: int = 0

func _ready():
	current_lives = max_lives
	session_start_time = Time.get_ticks_msec() / 1000.0
	
	# Create audio player for death sounds
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.bus = "SFX"
	
	# Create fade overlay
	create_fade_overlay()

# Create the fade overlay that will be used for transitions
func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire screen
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 1000  # Ensure it's on top
	
	# Add to scene tree (we'll move it to current scene when needed)
	add_child(fade_overlay)

# Update fade overlay to current scene
func update_fade_overlay_parent():
	if not fade_overlay:
		create_fade_overlay()
		return
	
	# Remove from current parent if it has one
	if fade_overlay.get_parent():
		fade_overlay.get_parent().remove_child(fade_overlay)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(fade_overlay)
		# Wait a frame to ensure it's properly added to scene tree
		await get_tree().process_frame
		# Now safely set the preset
		fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_overlay.z_index = 1000

# Call this to initialize hearts when the UI scene loads
func initialize_hearts():
	hearts.clear()
	await update_fade_overlay_parent()  # Make sure fade overlay is in current scene
	
	# Find heart nodes in the current scene
	var scene_root = get_tree().current_scene
	
	# Look for hearts named Heart1, Heart2, Heart3
	for i in range(max_lives):
		var heart = scene_root.find_child("Heart" + str(i + 1), true, false) as AnimatedSprite2D
		if heart:
			hearts.append(heart)
			# Set up animation finished signal
			if not heart.animation_finished.is_connected(_on_heart_animation_finished):
				heart.animation_finished.connect(_on_heart_animation_finished.bind(heart))
			# Start with idle animation
			heart.play("idle")
		else:
			print("Warning: Heart", i + 1, " not found in scene!")

# Call this function when the player takes damage
func lose_life():
	if current_lives > 0 and not is_transitioning:
		current_lives -= 1
		total_deaths += 1
		deaths_this_level += 1
		
		# Play death sound
		if enable_death_sound and death_sound and audio_player:
			audio_player.stream = death_sound
			audio_player.play()
		
		# Play death animation on the heart (right to left)
		if hearts.size() > current_lives:
			var heart_to_lose = hearts[current_lives]
			heart_to_lose.play("death")
		
		player_died.emit()
		life_lost.emit(current_lives)
		
		if current_lives <= 0:
			game_over.emit()
			print("Game Over! Total deaths this session: ", total_deaths)
			# Start game over sequence with fade
			start_game_over_sequence()
		else:
			print("Lives remaining: ", current_lives)

# Start the game over sequence with fade transition
func start_game_over_sequence():
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Wait for game over delay
	if game_over_delay > 0:
		await get_tree().create_timer(game_over_delay).timeout
	
	# Start fade out
	await fade_to_black()
	
	# Change to death scene
	change_to_death_scene()

# Fade to black
func fade_to_black() -> void:
	if not fade_overlay:
		create_fade_overlay()
	
	await update_fade_overlay_parent()
	
	# Ensure overlay is visible and on top
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input during transition
	
	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	await tween.finished

# Fade from black (call this from the new scene if you want to fade in)
func fade_from_black() -> void:
	if not fade_overlay:
		create_fade_overlay()
	
	await update_fade_overlay_parent()
	
	fade_overlay.color = Color(0, 0, 0, 1)  # Start black
	fade_overlay.visible = true
	
	# Fade to transparent
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0), fade_duration)
	await tween.finished
	
	fade_overlay.visible = false
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false

# Called when heart animation finishes
func _on_heart_animation_finished(heart: AnimatedSprite2D):
	if heart.animation == "death":
		heart.visible = false

# Restore a life (for pickups, etc.)
func gain_life():
	if current_lives < max_lives:
		# Restore the heart at current_lives index
		if hearts.size() > current_lives:
			var heart_to_restore = hearts[current_lives]
			heart_to_restore.visible = true
			heart_to_restore.play("idle")
		
		current_lives += 1
		life_gained.emit(current_lives)

# Reset all lives (for new game, respawn, etc.)
func reset_lives():
	current_lives = max_lives
	is_transitioning = false
	for heart in hearts:
		if heart:
			heart.visible = true
			heart.play("idle")

# Get current lives
func get_current_lives() -> int:
	return current_lives

# Check if player has lives remaining
func has_lives() -> bool:
	return current_lives > 0

# Set max lives (useful for different difficulty levels)
func set_max_lives(new_max: int):
	max_lives = new_max
	if current_lives > max_lives:
		current_lives = max_lives

# Change to death scene
func change_to_death_scene():
	if game_over_scene_path != "":
		if ResourceLoader.exists(game_over_scene_path):
			get_tree().change_scene_to_file(game_over_scene_path)
		else:
			print("ERROR: Death scene not found at: ", game_over_scene_path)
			# Fallback: restart current scene
			restart_current_scene()
	else:
		print("No death scene path set! Restarting current scene...")
		restart_current_scene()

# Restart the current scene with fade
func restart_current_scene():
	reset_level_stats()
	await fade_to_black()
	get_tree().reload_current_scene()

# Set the death scene path
func set_death_scene(scene_path: String):
	game_over_scene_path = scene_path

# Set the delay before death screen
func set_death_delay(delay: float):
	game_over_delay = delay

# Set fade duration
func set_fade_duration(duration: float):
	fade_duration = duration

# Start a new game with fade transition
func start_new_game(gameplay_scene_path: String = ""):
	if is_transitioning:
		return
	
	reset_all_stats()
	reset_lives()
	
	if gameplay_scene_path != "":
		if ResourceLoader.exists(gameplay_scene_path):
			is_transitioning = true
			await fade_to_black()
			get_tree().change_scene_to_file(gameplay_scene_path)
		else:
			print("ERROR: Gameplay scene not found at: ", gameplay_scene_path)
	else:
		print("No gameplay scene path provided for new game")

# Call this from your new scene's _ready() function to fade in
func fade_in_new_scene():
	# Small delay to ensure scene is fully loaded
	await get_tree().process_frame
	fade_from_black()

# Additional stats and utility functions
func add_souls_collected(amount: int):
	session_souls_collected += amount

func complete_level():
	session_levels_completed += 1
	deaths_this_level = 0

func reset_level_stats():
	deaths_this_level = 0

func reset_all_stats():
	total_deaths = 0
	deaths_this_level = 0
	session_souls_collected = 0
	session_levels_completed = 0
	session_start_time = Time.get_ticks_msec() / 1000.0

# Get session statistics
func get_session_time() -> float:
	return (Time.get_ticks_msec() / 1000.0) - session_start_time

func get_total_deaths() -> int:
	return total_deaths

func get_deaths_this_level() -> int:
	return deaths_this_level

func get_session_souls() -> int:
	return session_souls_collected

func get_levels_completed() -> int:
	return session_levels_completed

# Create a stats dictionary for death screen
func get_death_stats() -> Dictionary:
	return {
		"lives_remaining": current_lives,
		"total_deaths": total_deaths,
		"deaths_this_level": deaths_this_level,
		"session_time": get_session_time(),
		"souls_collected": session_souls_collected,
		"levels_completed": session_levels_completed
	}

# Set death sound
func set_death_sound(sound: AudioStream):
	death_sound = sound

# Toggle death sound
func toggle_death_sound(enabled: bool):
	enable_death_sound = enabled
