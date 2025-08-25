extends Area2D

@export var checkpoint_id: String = ""  # Unique identifier for this checkpoint
@export var is_active: bool = false  # Whether this checkpoint has been activated
@export var activation_sound: AudioStream  # Sound to play when activated
@export var checkpoint_texture_inactive: Texture2D  # Visual when inactive
@export var checkpoint_texture_active: Texture2D  # Visual when active

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

signal checkpoint_activated(checkpoint_position: Vector2, checkpoint_id: String)

func _ready():
	# Connect to player detection
	body_entered.connect(_on_body_entered)
	
	# Set initial visual state
	update_visual_state()
	
	# Connect to checkpoint manager if it exists
	var checkpoint_manager = get_node_or_null("/root/CheckpointManager")
	if checkpoint_manager:
		checkpoint_activated.connect(checkpoint_manager._on_checkpoint_activated)

func _on_body_entered(body: Node2D):
	# Check if the body that entered is the player
	if body.is_in_group("Player") and not is_active:
		activate_checkpoint()

func activate_checkpoint():
	if is_active:
		return  # Already activated
	
	is_active = true
	
	# Update the player's respawn point
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_respawn_point"):
		player.set_respawn_point(global_position)
	
	# Visual and audio feedback
	update_visual_state()
	play_activation_sound()
	play_activation_effect()
	
	# Emit signal for checkpoint manager
	checkpoint_activated.emit(global_position, checkpoint_id)
	
	print("Checkpoint activated: ", checkpoint_id)

func update_visual_state():
	if sprite:
		if is_active and checkpoint_texture_active:
			sprite.texture = checkpoint_texture_active
		elif not is_active and checkpoint_texture_inactive:
			sprite.texture = checkpoint_texture_inactive

func play_activation_sound():
	if activation_sound and audio_player:
		audio_player.stream = activation_sound
		audio_player.play()

func play_activation_effect():
	# Play particle effect if available
	
	
	# Simple tween animation for feedback
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale pulse effect
	var original_scale = sprite.scale
	tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.2).set_delay(0.1)
	
	# Color flash effect
	var original_modulate = sprite.modulate
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.15).set_delay(0.05)

# Method to reset checkpoint (useful for level reset)
func reset_checkpoint():
	is_active = false
	update_visual_state()
	

# Method to force activate (useful for starting checkpoint)
func force_activate():
	activate_checkpoint()
