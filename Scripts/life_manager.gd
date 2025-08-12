# LifeManager.gd
# This should be set up as an Autoload/Singleton
# Go to Project > Project Settings > Autoload and add this script

extends Node

signal life_lost(current_lives: int)
signal life_gained(current_lives: int)
signal game_over

@export var max_lives: int = 3
var current_lives: int
var hearts: Array[AnimatedSprite2D] = []

func _ready():
	current_lives = max_lives

# Call this to initialize hearts when the UI scene loads
func initialize_hearts():
	hearts.clear()
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
	if current_lives > 0:
		current_lives -= 1
		
		# Play death animation on the heart (right to left)
		if hearts.size() > current_lives:
			var heart_to_lose = hearts[current_lives]
			heart_to_lose.play("death")
		
		life_lost.emit(current_lives)
		
		if current_lives <= 0:
			game_over.emit()
			print("Game Over!")

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
