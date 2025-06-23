extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D

var sprite_offset: Vector2
var player_in_range = false
var last_player_reference = null

func _ready():
	# Store the initial offset between sprite and collision 
	sprite_offset = collision_shape.position - animated_sprite.position
	
	# Add ghost's Area2D to Enemy group
	area_2d.add_to_group("Enemy")
	add_to_group("Enemy")
	
	# Connect both signals
	if not area_2d.body_entered.is_connected(_on_area_2d_body_entered):
		area_2d.body_entered.connect(_on_area_2d_body_entered)
	
	if not area_2d.body_exited.is_connected(_on_area_2d_body_exited):
		area_2d.body_exited.connect(_on_area_2d_body_exited)
	
	# print("Ghost ready with reliable collision detection")

func _process(delta):
	# Make collision follow the animated sprite's position
	collision_shape.position = animated_sprite.position + sprite_offset
	
	# Continuously check if player is in range (backup detection)
	if player_in_range and last_player_reference != null:
		if is_instance_valid(last_player_reference) and last_player_reference.has_method("die"):
			# Double-check they're still overlapping
			var overlapping_bodies = area_2d.get_overlapping_bodies()
			if last_player_reference in overlapping_bodies:
				if not last_player_reference.is_dead:  # Only kill if not already dead
					print("💀 Continuous detection - KILLING PLAYER! 💀")
					last_player_reference.die()

func _on_area_2d_body_entered(body):
	print("👻 Ghost detected body entering: ", body.name)
	
	if body.is_in_group("Player") or body.has_method("die"):
		player_in_range = true
		last_player_reference = body
		print("💀 PLAYER ENTERED - KILLING IMMEDIATELY! 💀")
		
		if body.has_method("die"):
			body.die()
		else:
			print("ERROR: Player doesn't have die() method!")

func _on_area_2d_body_exited(body):
	print("👻 Ghost detected body exiting: ", body.name)
	
	if body == last_player_reference:
		player_in_range = false
		last_player_reference = null
		print("Player left ghost area")
