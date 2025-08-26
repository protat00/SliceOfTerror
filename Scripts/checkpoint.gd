extends Area2D

@export var checkpoint_id: String = ""  # Unique identifier for this checkpoint
@export var is_active: bool = false  # Whether this checkpoint has been activated
@export var activation_sound: AudioStream  # Sound to play when activated
@export var checkpoint_texture_inactive: Texture2D  # Visual when inactive
@export var checkpoint_texture_active: Texture2D  # Visual when active

# Message customization
@export_group("Message Settings")
@export var message_text: String = "You have reached a checkpoint!"
@export var message_font: FontFile  # Custom font
@export var message_font_size: int = 24
@export var message_color: Color = Color.WHITE
@export var message_position_y: int = 50  # How far down from center (negative = up, positive = down)
@export var message_duration: float = 2.5  # How long to show the message

@export_group("Box Style")
@export var use_gradient: bool = true  # Use gradient or solid color
@export var box_color: Color = Color(0.4, 0.2, 0.6, 0.9)  # Solid color (used if gradient disabled)
@export var gradient_color_top: Color = Color(0.6, 0.3, 0.8, 0.9)  # Top gradient color
@export var gradient_color_bottom: Color = Color(0.2, 0.1, 0.4, 0.9)  # Bottom gradient color
@export var box_corner_radius: int = 10  # Rounded corners

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
	
	# Show checkpoint message
	show_checkpoint_message()
	
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

func show_checkpoint_message():
	print("DEBUG: Showing checkpoint message...")
	
	# Check if there's already a message showing to prevent overlaps
	var existing_message = get_tree().get_first_node_in_group("checkpoint_message")
	if existing_message:
		print("DEBUG: Message already showing, skipping")
		return
	
	# Create the message overlay
	var message_overlay = Control.new()
	message_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_overlay.name = "CheckpointMessage"
	message_overlay.add_to_group("checkpoint_message")  # Add to group to prevent duplicates
	
	# Create the message box background (with gradient or solid color)
	var message_box: Control
	
	if use_gradient:
		# Create a ColorRect with gradient background
		var gradient_box = ColorRect.new()
		
		# Create the gradient
		var gradient = Gradient.new()
		gradient.add_point(0.0, gradient_color_top)
		gradient.add_point(1.0, gradient_color_bottom)
		
		# Create gradient texture
		var gradient_texture = GradientTexture2D.new()
		gradient_texture.gradient = gradient
		gradient_texture.width = 400
		gradient_texture.height = 100
		gradient_texture.fill_from = Vector2(0, 0)  # Top
		gradient_texture.fill_to = Vector2(0, 1)    # Bottom (vertical gradient)
		
		# Use Panel for gradient with rounded corners
		var panel = Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(400, 100)
		panel.position = Vector2(-200, message_position_y)
		panel.z_index = 100
		
		# Create StyleBoxFlat for rounded corners and gradient-like effect
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = gradient_color_top  # We'll use the top color as base
		
		# Add gradient effect by using border
		if box_corner_radius > 0:
			style_box.corner_radius_top_left = box_corner_radius
			style_box.corner_radius_top_right = box_corner_radius  
			style_box.corner_radius_bottom_left = box_corner_radius
			style_box.corner_radius_bottom_right = box_corner_radius
		
		# Create a simple gradient effect with the background
		style_box.bg_color = Color(
			(gradient_color_top.r + gradient_color_bottom.r) / 2,
			(gradient_color_top.g + gradient_color_bottom.g) / 2, 
			(gradient_color_top.b + gradient_color_bottom.b) / 2,
			(gradient_color_top.a + gradient_color_bottom.a) / 2
		)
		
		panel.add_theme_stylebox_override("panel", style_box)
		message_box = panel
	else:
		# Use simple solid color ColorRect
		var solid_box = ColorRect.new()
		solid_box.color = box_color
		solid_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		solid_box.custom_minimum_size = Vector2(400, 100)
		solid_box.position = Vector2(-200, message_position_y)
		solid_box.z_index = 100
		
		message_box = solid_box
	
	# Create the text label
	var message_label = Label.new()
	message_label.text = message_text  # Customizable text!
	
	# Set font if provided, otherwise use default
	if message_font:
		message_label.add_theme_font_override("font", message_font)
	
	message_label.add_theme_font_size_override("font_size", message_font_size)  # Customizable size!
	message_label.add_theme_color_override("font_color", message_color)  # Customizable color!
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Assemble the UI
	message_box.add_child(message_label)
	message_overlay.add_child(message_box)
	
	# Find the best place to add the message
	var target_parent = null
	var player = get_tree().get_first_node_in_group("Player")
	
	# Method 1: Try player's camera canvas layer
	if player and player.has_node("Camera2D/CanvasLayer"):
		target_parent = player.get_node("Camera2D/CanvasLayer")
		print("DEBUG: Adding to player's canvas layer")
	
	# Method 2: Create our own CanvasLayer if needed
	if not target_parent:
		print("DEBUG: Creating new CanvasLayer")
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		get_tree().current_scene.add_child(canvas_layer)
		target_parent = canvas_layer
	
	target_parent.add_child(message_overlay)
	print("DEBUG: Message overlay added successfully")
	
	# Start the animation sequence
	await animate_checkpoint_message(message_overlay, message_box)

func animate_checkpoint_message(message_overlay: Control, message_box: Control):  # Changed type from ColorRect to Control
	# Start with message off-screen and invisible (slides in from above)
	var start_y = message_position_y - 100  # Start 100 pixels higher than final position
	message_box.position.y = start_y
	message_overlay.modulate.a = 0.0
	
	# Create the tween
	var message_tween = create_tween()
	message_tween.set_parallel(true)
	
	# Phase 1: Slide in and fade in (0.5 seconds)
	message_tween.tween_property(message_overlay, "modulate:a", 1.0, 0.3)
	message_tween.tween_property(message_box, "position:y", message_position_y, 0.5).set_ease(Tween.EASE_OUT)  # Use custom position
	
	# Phase 2: Hold the message (customizable duration)
	await message_tween.finished
	await get_tree().create_timer(message_duration).timeout
	
	# Phase 3: Slide out and fade out (0.5 seconds)
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(message_overlay, "modulate:a", 0.0, 0.3)
	exit_tween.tween_property(message_box, "position:y", start_y, 0.5).set_ease(Tween.EASE_IN)  # Exit to above screen
	
	# Phase 4: Clean up
	await exit_tween.finished
	
	var parent = message_overlay.get_parent()
	message_overlay.queue_free()
	
	# Clean up the CanvasLayer if we created it
	if parent and parent.get_child_count() == 0 and parent.get_class() == "CanvasLayer":
		parent.queue_free()
	
	print("DEBUG: Message animation completed and cleaned up")
