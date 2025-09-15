extends Area2D

# Reference to the fade overlay
var fade_overlay: ColorRect
var is_teleporting = false

func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Create the fade overlay
	create_fade_overlay()

func create_fade_overlay():
	# Create a ColorRect that covers the entire screen
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the full screen
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Start completely transparent
	fade_overlay.modulate.a = 0.0
	
	# Add it to the scene tree at the highest layer
	# We add it to the current scene's CanvasLayer or create one
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to ensure it's on top
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(fade_overlay)

func _on_body_entered(body):
	# Check if the body is the player and we're not already teleporting
	if body.is_in_group("player") and not is_teleporting:
		is_teleporting = true
		teleport_to_level_2()

func teleport_to_level_2():
	# Create fade out tween
	var tween = create_tween()
	
	# Optional: Disable player movement during transition
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
	
	# Fade to black over 0.5 seconds
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	
	# Wait for fade out to complete, then change scene
	await tween.finished
	
	# Change to the new scene
	get_tree().change_scene_to_file("res://Scenes/level_2.tscn")

# Alternative version with additional effects
func teleport_to_level_2_with_effects():
	# Create fade out tween with easing
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
	
	# Optional: Disable player movement
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
	
	# Fade to black with smooth easing
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.8)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	
	# Optional: Add a slight scale effect to the fade overlay for extra smoothness
	fade_overlay.pivot_offset = fade_overlay.size / 2
	tween.tween_property(fade_overlay, "scale", Vector2(1.1, 1.1), 0.8)
	
	# Wait for fade out to complete
	await tween.finished
	
	# Small delay for dramatic effect (optional)
	await get_tree().create_timer(0.2).timeout
	
	# Change to the new scene
	get_tree().change_scene_to_file("res://scenes/level_2.tscn")
