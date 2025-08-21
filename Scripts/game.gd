extends Node2D

# Fix the node path - check your actual scene structure
@export var pause_menu : Control  # or whatever the actual node name is
@export var tilemap : TileMapLayer  # Add this - drag your TileMapLayer node here in inspector
@export var path_button : TextureButton  # For PNG button - or use Button for regular button

var paused = false
var is_game_over: bool = false

# Path reveal variables
var path_positions = []
var reveal_tween: Tween
var path_revealed = false

func _ready():
	get_tree().paused = false
	is_game_over = false
	
	# Debug: Check if pause_menu was found
	if pause_menu == null:
		print("ERROR: pause_menu node not found! Check the node path.")
	else:
		print("pause_menu found successfully")
		pause_menu.hide()  # Start with menu hidden
	
	# Debug: Check if TileMapLayer was found
	if tilemap == null:
		print("ERROR: TileMapLayer node not found! Check the node path.")
	else:
		print("TileMapLayer found successfully")
	
	# Debug: Check if path_button was found
	if path_button == null:
		print("ERROR: path_button node not found! Check the node path.")
	else:
		print("path_button found successfully")
		# Connect the button's pressed signal to our function
		path_button.pressed.connect(_on_path_button_pressed)
	
	# Define your path coordinates (adjust these to your needs)
	# These are tile coordinates, not pixel coordinates
	path_positions = [
		Vector2i(5, 10),
		Vector2i(6, 10),
		Vector2i(7, 10),
		Vector2i(8, 10),
		Vector2i(9, 10),
		Vector2i(10, 10),
		Vector2i(11, 10)
	]
	
	# Add game music

func _process(delta):
	if Input.is_action_just_pressed("pause"):
		pauseMenu()
	
	# Removed keyboard input for path - now using button instead

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

# Button callback function
func _on_path_button_pressed():
	toggle_path()

# Path reveal functions
func toggle_path():
	if tilemap == null:
		print("TileMapLayer is null - cannot show path")
		return
	
	if path_revealed:
		hide_path()
	else:
		animate_path_reveal()

func animate_path_reveal():
	if reveal_tween:
		reveal_tween.kill()
	
	reveal_tween = create_tween()
	path_revealed = true
	
	# Reveal each tile with a small delay for animation effect
	for i in range(path_positions.size()):
		reveal_tween.tween_callback(reveal_tile.bind(i)).set_delay(0.15 * i)

func reveal_tile(index: int):
	if index < path_positions.size():
		var source_id = 0  # Adjust this to match your tileset source ID
		var atlas_coords = Vector2i(1, 0)  # Adjust these coordinates to your path tile in the tileset
		
		tilemap.set_cell(path_positions[index], source_id, atlas_coords)

func hide_path():
	if tilemap == null:
		return
	
	# Remove all path tiles
	for pos in path_positions:
		tilemap.erase_cell(pos)
	
	path_revealed = false
