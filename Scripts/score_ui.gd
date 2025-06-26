extends CanvasLayer

# Export values for customization
@export var float_amplitude: float = 5.0   # How high/low it floats
@export var float_speed: float = 1.0       # How fast it floats
@export var horizontal_drift: float = 2.0  # Side-to-side drift
@export var drift_speed: float = 0.8       # Speed of horizontal drift

# Score management
@export var current_score: int = 0
@export var score_increment: int = 10

# Item display settings
@export var item_texture: Texture2D  # Drag your soul/item image here
@export var show_image: bool = true  # Toggle between image and text display
@export var image_scale: float = 1.0  # Scale for the item image

# Internal variables
var time_passed: float = 0.0
var original_position: Vector2
var score_container: Control
var score_label: Label
var item_icon: TextureRect

func _ready():
	# Get references to the UI elements
	score_container = $ScoreContainer
	score_label = $ScoreContainer/ScoreLabel
	
	# Create item icon if we want to show images
	if show_image:
		create_item_icon()
	
	# Store the original position
	original_position = score_container.position
	
	# Initialize score display
	update_score_display()

func create_item_icon():
	# Create TextureRect for the item image
	item_icon = TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.texture = item_texture
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.custom_minimum_size = Vector2(32, 32)  # Minimum size for visibility
	item_icon.scale = Vector2(image_scale, image_scale)
	
	# Add to score container
	score_container.add_child(item_icon)
	
	# Position it to the left of the text
	item_icon.position = Vector2(-40, 0)  # Adjust as needed

func _process(delta):
	time_passed += delta
	
	# Calculate floating motion using sine waves
	var vertical_offset = sin(time_passed * float_speed) * float_amplitude
	var horizontal_offset = sin(time_passed * drift_speed) * horizontal_drift
	
	# Apply the floating animation
	score_container.position = original_position + Vector2(horizontal_offset, vertical_offset)

# Function to add score
func add_score(points: int = 0):
	if points == 0:
		points = score_increment
	
	current_score += points
	update_score_display()
	
	# Optional: Add a little bounce effect when score increases
	create_score_bounce()

# Function to set score directly
func set_score(new_score: int):
	current_score = new_score
	update_score_display()

# Update the score text display
func update_score_display():
	if score_label:
		if show_image and item_texture:
			# Show just the number when using image display
			score_label.text = str(current_score)
		else:
			# Show "Score: X" when not using image
			score_label.text = "Score: " + str(current_score)

# Create a subtle bounce effect when score increases
func create_score_bounce():
	var tween = create_tween()
	var original_scale = score_container.scale
	
	# Quick scale up then back down
	tween.tween_property(score_container, "scale", original_scale * 1.1, 0.1)
	tween.tween_property(score_container, "scale", original_scale, 0.1)

# Reset score to zero
func reset_score():
	current_score = 0
	update_score_display()

# Get current score (useful for other scripts)
func get_score() -> int:
	return current_score
