# LifeManager.gd
# This should be set up as an Autoload/Singleton
# Go to Project > Project Settings > Autoload and add this script
extends Node

signal life_lost(current_lives: int)
signal life_gained(current_lives: int)
signal game_over
signal player_died

@export var max_lives: int = 3
@export var game_over_scene_path: String = "res://Scenes/death_screen.tscn"  # Your death scene path
@export var game_over_delay: float = 0.7 # Delay before switching to death scene
@export var fade_duration: float = 2.0  # Duration of fade transition
@export var screen_shake_enabled: bool = true
@export var screen_shake_intensity: float = 15.0  # How strong the shake is
@export var screen_shake_duration: float = 0.8  # How long the shake lasts
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
	
	# Use the CORRECT death scene path (it's in the Scenes folder!)
	game_over_scene_path = "res://Scenes/death_screen.tscn"
	print("Death scene path set to: ", game_over_scene_path)
	print("Scene exists: ", ResourceLoader.exists(game_over_scene_path))
	
	# Create audio player for death sounds
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.bus = "SFX"
	
	# Create fade overlay
	create_fade_overlay()

# Add this debug function
func debug_scene_paths():
	print("=== DEBUGGING SCENE PATHS ===")
	
	# Test different possible paths
	var possible_paths = [
		"res://death_screen.tscn",
		"res://Scenes/death_screen.tscn",
		"res://scenes/death_screen.tscn", 
		"res://DeathScreen.tscn",
		"res://death_scene.tscn"
	]
	
	for path in possible_paths:
		print("Testing path: ", path)
		print("  Exists: ", ResourceLoader.exists(path))
		print("  File access: ", FileAccess.file_exists(path))
	
	print("\n=== ALL .tscn FILES IN PROJECT ===")
	list_all_tscn_files("res://")
	
func list_all_tscn_files(path: String, indent: String = ""):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path + "/" + file_name if path != "res://" else "res://" + file_name
			if dir.current_is_dir() and not file_name.begins_with("."):
				print(indent + "📁 " + file_name + "/")
				list_all_tscn_files(full_path, indent + "  ")
			elif file_name.ends_with(".tscn"):
				print(indent + "📄 " + full_path)
				if "death" in file_name.to_lower():
					print(indent + "   ⭐ THIS LOOKS LIKE YOUR DEATH SCENE!")
			file_name = dir.get_next()

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
	print("lose_life() called - Current lives: ", current_lives, " - Is transitioning: ", is_transitioning)
	
	if current_lives > 0 and not is_transitioning:
		current_lives -= 1
		total_deaths += 1
		deaths_this_level += 1
		
		print("Life lost! Lives now: ", current_lives)
		
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
			print("GAME OVER TRIGGERED! Starting game over sequence...")
			game_over.emit()
			print("Game Over! Total deaths this session: ", total_deaths)
			# Start game over sequence with fade
			start_game_over_sequence()
		else:
			print("Lives remaining: ", current_lives)
	else:
		print("lose_life() blocked - either no lives left or already transitioning")

# Start the game over sequence with screen shake and fade transition
func start_game_over_sequence():
	print("start_game_over_sequence() called")
	
	if is_transitioning:
		print("Already transitioning, skipping...")
		return
	
	is_transitioning = true
	print("Setting is_transitioning to true")
	
	# Add screen shake effect on game over
	if screen_shake_enabled:
		print("Starting screen shake effect...")
		await add_death_screen_shake()
		print("Screen shake completed")
	
	# Wait for game over delay (reduced since shake takes time)
	var remaining_delay = game_over_delay - (screen_shake_duration if screen_shake_enabled else 0.0)
	if remaining_delay > 0:
		print("Waiting for remaining delay: ", remaining_delay, " seconds")
		await get_tree().create_timer(remaining_delay).timeout
		print("Game over delay finished")
	
	# Start fade out
	print("Starting fade to black...")
	await fade_to_black()
	print("Fade to black completed")
	
	# Change to death scene
	print("Changing to death scene...")
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

# Change to death scene - SIMPLE VERSION
func change_to_death_scene():
	print("=== ATTEMPTING SCENE CHANGE ===")
	print("Current scene: ", get_tree().current_scene.scene_file_path)
	print("Target scene: ", game_over_scene_path)
	
	# Try the simple approach
	var result = get_tree().change_scene_to_file(game_over_scene_path)
	print("Scene change result: ", result)
	
	if result != OK:
		print("Scene change FAILED! Error code: ", result)
		print("Trying to restart current scene as fallback...")
		get_tree().reload_current_scene()

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

# Screen shake effect for game over
func add_death_screen_shake():
	var camera = get_camera()
	
	if camera:
		print("Shaking camera...")
		await shake_camera(camera)
	else:
		print("No camera found, shaking entire scene...")
		await shake_scene()

# Shake the camera
func shake_camera(camera: Camera2D):
	var original_position = camera.global_position
	var tween = create_tween()
	var shake_steps = int(screen_shake_duration * 60)  # 60 FPS
	
	# Create intense shake that gradually decreases
	for i in range(shake_steps):
		var progress = float(i) / float(shake_steps)
		var current_intensity = screen_shake_intensity * (1.0 - progress * 0.7)  # Decrease over time
		
		var shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		tween.tween_property(camera, "global_position", original_position + shake_offset, 1.0 / 60.0)
	
	# Return to original position
	tween.tween_property(camera, "global_position", original_position, 0.1)
	await tween.finished

# Shake the entire scene if no camera found
func shake_scene():
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	var original_position = current_scene.position
	var tween = create_tween()
	var shake_steps = int(screen_shake_duration * 60)
	
	for i in range(shake_steps):
		var progress = float(i) / float(shake_steps)
		var current_intensity = screen_shake_intensity * (1.0 - progress * 0.7)
		
		var shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		tween.tween_property(current_scene, "position", original_position + shake_offset, 1.0 / 60.0)
	
	# Return to original position
	tween.tween_property(current_scene, "position", original_position, 0.1)
	await tween.finished

# Find the camera in the current scene
func get_camera() -> Camera2D:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# Look for Camera2D in the scene
	var camera = current_scene.find_child("Camera2D", true, false) as Camera2D
	if camera:
		return camera
	
	# Look for any node that has a Camera2D
	return find_camera_recursive(current_scene)

func find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node as Camera2D
	
	for child in node.get_children():
		var result = find_camera_recursive(child)
		if result:
			return result
	
	return null

# Set screen shake properties
func set_screen_shake_enabled(enabled: bool):
	screen_shake_enabled = enabled

func set_screen_shake_intensity(intensity: float):
	screen_shake_intensity = intensity

func set_screen_shake_duration(duration: float):
	screen_shake_duration = duration
