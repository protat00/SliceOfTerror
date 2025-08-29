extends CharacterBody2D

# Simple spike that kills the player on contact
@onready var sprite = $Sprite2D
@onready var death_area = $DeathArea
@onready var death_collision = $DeathArea/CollisionShape2D

var player_in_death_range = false
var last_player_reference = null

func _ready():
	# Add spike to Enemy group
	add_to_group("Enemy")
	
	# Connect death area signals
	if death_area and not death_area.body_entered.is_connected(_on_death_area_body_entered):
		death_area.body_entered.connect(_on_death_area_body_entered)
	
	if death_area and not death_area.body_exited.is_connected(_on_death_area_body_exited):
		death_area.body_exited.connect(_on_death_area_body_exited)
	
	print("Spike ready - will kill player on contact")

func _process(_delta):
	# Handle death logic - kill immediately when player touches spike
	if player_in_death_range and last_player_reference != null:
		if is_instance_valid(last_player_reference) and last_player_reference.has_method("die"):
			# Double-check they're still overlapping with death area
			var overlapping_bodies = death_area.get_overlapping_bodies()
			if last_player_reference in overlapping_bodies:
				if not last_player_reference.is_dead:
					print("💀 Spike collision - KILLING PLAYER! 💀")
					last_player_reference.die()

# DEATH AREA SIGNALS
func _on_death_area_body_entered(body):
	print("💀 Spike - body entered: ", body.name)
	
	if body.is_in_group("Player") or body.has_method("die"):
		player_in_death_range = true
		last_player_reference = body
		
		# Kill immediately on contact
		print("💀 SPIKE CONTACT - KILLING IMMEDIATELY! 💀")
		if body.has_method("die") and not body.is_dead:
			body.die()
		else:
			print("ERROR: Player doesn't have die() method or is already dead!")

func _on_death_area_body_exited(body):
	print("💀 Spike - body exited: ", body.name)
	
	if body == last_player_reference:
		player_in_death_range = false
		last_player_reference = null
