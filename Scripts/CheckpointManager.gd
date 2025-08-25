extends Node

# Singleton for managing checkpoints across levels
# Add this as an AutoLoad in Project Settings

var current_checkpoint_id: String = ""
var current_checkpoint_position: Vector2 = Vector2.ZERO
var activated_checkpoints: Array[String] = []

signal checkpoint_changed(checkpoint_id: String, position: Vector2)

func _ready():
	# Make sure this persists between scene changes
	process_mode = Node.PROCESS_MODE_ALWAYS

# Called when a checkpoint is activated
func _on_checkpoint_activated(position: Vector2, checkpoint_id: String):
	# Only update if this is a new checkpoint or the first one
	if checkpoint_id != current_checkpoint_id:
		current_checkpoint_id = checkpoint_id
		current_checkpoint_position = position
		
		# Add to activated checkpoints if not already there
		if checkpoint_id not in activated_checkpoints:
			activated_checkpoints.append(checkpoint_id)
		
		# Emit signal for UI updates or other systems
		checkpoint_changed.emit(checkpoint_id, position)
		
		print("Checkpoint Manager: New checkpoint set - ", checkpoint_id)

# Get the current respawn position
func get_current_respawn_position() -> Vector2:
	return current_checkpoint_position

# Get the current checkpoint ID
func get_current_checkpoint_id() -> String:
	return current_checkpoint_id

# Check if a specific checkpoint has been activated
func is_checkpoint_activated(checkpoint_id: String) -> bool:
	return checkpoint_id in activated_checkpoints

# Reset all checkpoints (useful for new game)
func reset_all_checkpoints():
	current_checkpoint_id = ""
	current_checkpoint_position = Vector2.ZERO
	activated_checkpoints.clear()
	print("All checkpoints reset")

# Reset checkpoints for current level only
func reset_level_checkpoints():
	# You might want to implement level-specific logic here
	# For now, just reset the current checkpoint
	current_checkpoint_id = ""
	current_checkpoint_position = Vector2.ZERO

# Load checkpoint data (for save/load system)
func load_checkpoint_data(data: Dictionary):
	current_checkpoint_id = data.get("current_checkpoint_id", "")
	current_checkpoint_position = data.get("current_checkpoint_position", Vector2.ZERO)
	activated_checkpoints = data.get("activated_checkpoints", [])

# Save checkpoint data (for save/load system)
func save_checkpoint_data() -> Dictionary:
	return {
		"current_checkpoint_id": current_checkpoint_id,
		"current_checkpoint_position": current_checkpoint_position,
		"activated_checkpoints": activated_checkpoints
	}

# Restore checkpoints when loading a level
func restore_checkpoints_in_level():
	# Find all checkpoints in the current scene and restore their state
	var checkpoints = get_tree().get_nodes_in_group("checkpoints")
	
	for checkpoint in checkpoints:
		if checkpoint.has_method("reset_checkpoint"):
			checkpoint.reset_checkpoint()
		
		# Activate if it was previously activated
		if checkpoint.checkpoint_id in activated_checkpoints:
			if checkpoint.has_method("force_activate"):
				checkpoint.force_activate()
	
	# Set player respawn point to current checkpoint
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_respawn_point") and current_checkpoint_position != Vector2.ZERO:
		player.set_respawn_point(current_checkpoint_position)
