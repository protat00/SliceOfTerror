extends Node2D
# Fix the node path - check your actual scene structure
@export var pause_menu : Control  # or whatever the actual node name is
var paused = false
var is_game_over: bool = false

func _ready():
	is_game_over = false
	# Debug: Check if pause_menu was found
	if pause_menu == null:
		print("ERROR: pause_menu node not found! Check the node path.")
	else:
		print("pause_menu found successfully")
		pause_menu.hide()  # Start with menu hidden
	
	# Add game music
func _process(delta):
	if Input.is_action_just_pressed("pause"):
		pauseMenu()
	
func pauseMenu():
	# Add null check to prevent errors
	if pause_menu == null:
		print("pause_menu is null - cannot show/hide")
		return
		
	if paused:
		pause_menu.hide()
		Engine.time_scale = 1
	else:
		pause_menu.show()
		Engine.time_scale = 0
		
	paused = !paused
	
	
	
