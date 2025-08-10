# LifeManager.gd
# Attach this script to a node that manages your life system
# This version works with individual Heart scripts

extends Node

@export var max_lives: int = 3
var current_lives: int
var hearts: Array[AnimatedSprite2D] = []

# Called when the node enters the scene tree for the first time
func _ready():
	current_lives = max_lives
	# Get references to your heart nodes
	# Assuming your hearts are named "Heart1", "Heart2", "Heart3"
	for i in range(max_lives):
		var heart = get_node("Heart" + str(i + 1)) as AnimatedSprite2D
		if heart:
			hearts.append(heart)
		else:
			print("Warning: Heart", i + 1, " not found!")

# Call this function when the player takes damage
func lose_life():
	if current_lives > 0:
		current_lives -= 1
		# Lose the heart from right to left (index: current_lives)
		# or left to right (index: max_lives - 1 - current_lives)
		lose_heart_at_index(current_lives)
		
		if current_lives <= 0:
			game_over()
	else:
		print("No lives remaining!")

# Lose heart at specific index
func lose_heart_at_index(heart_index: int):
	if heart_index >= 0 and heart_index < hearts.size():
		hearts[heart_index].lose_heart()

# Restore a life (for pickups, etc.)
func gain_life():
	if current_lives < max_lives:
		# Restore the heart at current_lives index
		hearts[current_lives].restore_heart()
		current_lives += 1

# Reset all lives
func reset_lives():
	current_lives = max_lives
	for heart in hearts:
		heart.restore_heart()

# Handle game over
func game_over():
	print("Game Over!")
	# Add your game over logic here
	# get_tree().change_scene_to_file("res://GameOverScene.tscn")

# Get current lives (for UI display, etc.)
func get_current_lives() -> int:
	return current_lives
