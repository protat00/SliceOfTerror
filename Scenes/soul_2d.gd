# InteractableItem.gd
# Attach this to your Area2D node
extends Area2D

@export var item_name: String = "Item"
@export var interaction_text: String = "Press E to pick up"
@export var ui_background_texture: Texture2D  # Drag your image here in the inspector
@export var ui_size: Vector2 = Vector2(200, 50)  # Adjustable UI size
@export var ui_offset_distance: float = 80.0  # Distance from item center
@export var ui_height_offset: float = -60.0  # Base height offset (negative = above item)
@export var arc_intensity: float = 30.0  # How much the UI arcs around the item
@export var smooth_follow_speed: float = 8.0  # How quickly UI follows player movement
@export var idle_bob_speed: float = 2.0  # Speed of the idle bobbing animation
@export var idle_bob_amount: float = 10.0  # How much the UI bobs up and down
@export var idle_detection_threshold: float = 5.0  # How still the player needs to be to start bobbing

# Score settings
@export var score_value: int = 1  # How many points this item is worth
@export var score_ui_node: CanvasLayer  # Drag your ScoreUI here in the inspector
@export var score_ui_path: String = ""  # Alternative: manual path (leave empty if using node reference)

# SOUL SYSTEM - NEW ADDITION
@export var soul_value: int = 1  # How many souls this item gives
@export var is_soul_item: bool = true  # Set to true if this is a soul pickup

var player_nearby: bool = false
var player_ref: Node2D = null
var last_player_position: Vector2
var player_idle_time: float = 0.0
var bob_timer: float = 0.0
var has_been_picked_up: bool = false  # Prevent double pickup

# UI nodes - created as children of this node
var ui_canvas: CanvasLayer
var ui_control: Control
var ui_panel: Panel
var ui_label: Label

# Score UI reference
var score_ui: CanvasLayer

func _ready():
	# Connect area signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Get reference to score UI - try multiple methods
	if score_ui_node:
		# Use the node reference if assigned in inspector
		score_ui = score_ui_node
		print("Found ScoreUI via node reference")
	elif score_ui_path != "":
		# Use manual path if provided
		score_ui = get_node_or_null(score_ui_path)
		if score_ui:
			print("Found ScoreUI at path: ", score_ui_path)
		else:
			print("Warning: Could not find ScoreUI at path: ", score_ui_path)
	else:
		# Try to find it automatically
		score_ui = find_score_ui()
	
	if not score_ui:
		print("Warning: ScoreUI not found! Score will not be added when items are picked up.")
	
	# Wait one frame to ensure scene is ready
	await get_tree().process_frame
	
	# Create UI
	create_ui()
	
	# Debug print
	print("InteractableItem ready. Texture assigned: ", ui_background_texture != null)
	print("Soul item: ", is_soul_item, " | Soul value: ", soul_value)

func find_score_ui() -> CanvasLayer:
	# Try common locations for ScoreUI
	var possible_paths = [
		"/root/ScoreUI",
		"/root/Main/ScoreUI", 
		"/root/Game/ScoreUI",
		"/root/Level/ScoreUI"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and node is CanvasLayer:
			print("Auto-found ScoreUI at: ", path)
			return node
	
	# Try searching the scene tree
	var root = get_tree().root
	var found_ui = search_for_score_ui(root)
	if found_ui:
		print("Found ScoreUI via tree search: ", found_ui.get_path())
		return found_ui
	
	return null

func search_for_score_ui(node: Node) -> CanvasLayer:
	# Check if this node is a CanvasLayer with ScoreUI-like name
	if node is CanvasLayer and ("score" in node.name.to_lower() or "ui" in node.name.to_lower()):
		# Check if it has the add_score method
		if node.has_method("add_score"):
			return node
	
	# Search children
	for child in node.get_children():
		var result = search_for_score_ui(child)
		if result:
			return result
	
	return null

func create_ui():
	# Create CanvasLayer as child of this node
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100  # High layer to ensure visibility
	add_child(ui_canvas)
	
	# Create Control node
	ui_control = Control.new()
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_canvas.add_child(ui_control)
	
	# Create panel
	ui_panel = Panel.new()
	ui_panel.size = ui_size
	ui_panel.position = -ui_size / 2  # Center the panel
	
	# Apply custom texture if provided
	if ui_background_texture:
		var style = StyleBoxTexture.new()
		style.texture = ui_background_texture
		ui_panel.add_theme_stylebox_override("panel", style)
		print("Applied texture to UI panel")
	else:
		# Fallback style
		create_fallback_style()
		print("Using fallback style")
	
	ui_control.add_child(ui_panel)
	
	# Create label
	ui_label = Label.new()
	ui_label.text = interaction_text
	ui_label.position = Vector2(10, 10)
	ui_label.size = Vector2(ui_size.x - 20, ui_size.y - 20)
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_label.add_theme_color_override("font_color", Color.WHITE)
	ui_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui_label.add_theme_constant_override("shadow_offset_x", 2)
	ui_label.add_theme_constant_override("shadow_offset_y", 2)
	ui_panel.add_child(ui_label)
	
	# Hide UI initially
	ui_canvas.visible = false
	
	print("UI created successfully")

func create_fallback_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	ui_panel.add_theme_stylebox_override("panel", style)

func _process(delta):
	if player_nearby and player_ref and ui_canvas and ui_canvas.visible:
		# Check if player is idle
		check_player_idle_state(delta)
		update_ui_position(delta)

func check_player_idle_state(delta):
	if not player_ref:
		return
	
	var current_player_pos = player_ref.global_position
	var player_movement = current_player_pos.distance_to(last_player_position)
	
	if player_movement < idle_detection_threshold * delta:
		# Player is standing still
		player_idle_time += delta
	else:
		# Player is moving
		player_idle_time = 0.0
		bob_timer = 0.0
	
	last_player_position = current_player_pos

func update_ui_position(delta):
	if not ui_control:
		return
		
	# Get the direction from item to player
	var item_to_player = (player_ref.global_position - global_position).normalized()
	
	# Calculate the angle around the item
	var angle = atan2(item_to_player.y, item_to_player.x)
	
	# Create arc effect - UI appears on the opposite side of where player is
	var arc_angle = angle + PI  # Opposite side
	
	# Calculate UI position with arc in world space
	var ui_world_pos = global_position + Vector2(
		cos(arc_angle) * ui_offset_distance,
		sin(arc_angle) * ui_offset_distance + ui_height_offset
	)
	
	# Add some vertical variation based on player's relative height
	var height_difference = player_ref.global_position.y - global_position.y
	var additional_arc = clamp(height_difference / 100.0, -1.0, 1.0) * arc_intensity
	ui_world_pos.y += additional_arc
	
	# Add idle bobbing animation when player is standing still
	if player_idle_time > 0.5:  # Start bobbing after 0.5 seconds of being idle
		bob_timer += delta
		var bob_offset = sin(bob_timer * idle_bob_speed) * idle_bob_amount
		ui_world_pos.y += bob_offset
	
	# Simple world-to-screen conversion
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	
	var screen_pos: Vector2
	if camera:
		# Convert world position to screen position
		screen_pos = ui_world_pos - camera.global_position + viewport.get_visible_rect().size / 2
	else:
		# No camera, use world position directly
		screen_pos = ui_world_pos
	
	# Smooth follow movement
	ui_control.global_position = ui_control.global_position.lerp(screen_pos, smooth_follow_speed * delta)

func _on_body_entered(body):
	if has_been_picked_up:
		return
		
	if body.is_in_group("Player"):  # Make sure this matches your player group name
		player_nearby = true
		player_ref = body
		last_player_position = body.global_position
		player_idle_time = 0.0
		bob_timer = 0.0
		if ui_canvas:
			ui_canvas.visible = true
			print("UI should now be visible")

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_nearby = false
		player_ref = null
		if ui_canvas:
			ui_canvas.visible = false
			print("UI hidden")

func _input(event):
	if player_nearby and event.is_action_pressed("pick_up") and not has_been_picked_up:
		interact()

func interact():
	if has_been_picked_up:
		return
		
	has_been_picked_up = true
	
	print("Picked up: ", item_name)
	
	# SOUL SYSTEM - Give souls to player
	if is_soul_item and player_ref and player_ref.has_method("add_soul"):
		player_ref.add_soul(soul_value)
		print("✨ Successfully added ", soul_value, " souls to player! ✨")
		print("Player now has ", player_ref.get_soul_count(), " souls total")
	elif is_soul_item:
		print("❌ ERROR: Could not add soul to player - player missing add_soul method or no player reference")
	
	# Add score when item is picked up
	if score_ui and score_ui.has_method("add_score"):
		score_ui.add_score(score_value)
		print("Added ", score_value, " points to score!")
	else:
		print("Warning: Could not add score - ScoreUI not found or missing add_score method")
	
	queue_free()  # Remove the item

func _exit_tree():
	# UI will be automatically freed when this node is freed
	pass
