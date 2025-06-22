extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D

var sprite_offset: Vector2

func _ready():
	# Store the initial offset between sprite and collision 
	sprite_offset = collision_shape.position - animated_sprite.position
	
	# Add ghost's Area2D to Enemy group
	area_2d.add_to_group("Enemy")
	add_to_group("Enemy")
	
	# Connect the body_entered signal (this is what's working!)
	if not area_2d.body_entered.is_connected(_on_area_2d_body_entered):
		area_2d.body_entered.connect(_on_area_2d_body_entered)
		print("Ghost: Connected body_entered signal")
	
	print("Ghost ready - Area2D groups: ", area_2d.get_groups())

func _process(delta):
	# Make collision follow the animated sprite's position
	collision_shape.position = animated_sprite.position + sprite_offset

# This is the key function - it's already working based on your console output
func _on_area_2d_body_entered(body):
	print("👻 Ghost detected body: ", body.name)
	print("   Body groups: ", body.get_groups())
	
	# Check if it's the player (either by group or by checking if it has the die method)
	if body.is_in_group("Player") or body.has_method("die"):
		print("💀 KILLING PLAYER! 💀")
		if body.has_method("die"):
			body.die()
		else:
			print("ERROR: Player doesn't have die() method!")
	else:
		print("❌ Not the player or player doesn't have die() method")
