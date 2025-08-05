extends Area2D

# UI Positioning Settings
@export_group("UI Positioning")
@export var ui_offset: Vector2 = Vector2(0, -60)  ## X and Y offset from player (+ = right/down, - = left/up)
@export var show_position_preview: bool = false  ## Shows a yellow circle in editor to preview UI position
@export var adaptive_positioning: bool = true  ## Automatically prevents UI from covering player
@export var min_distance_from_player: float = 80.0  ## Minimum distance to maintain from player center

# Text display settings
@export_group("Text Content")
@export_multiline var display_text: String = "Press E to interact with souls\nWASD to move"
@export var ui_size: Vector2 = Vector2(200, 50)
@export var ui_font: Font
@export var ui_font_size: int = 16

# Background style
@export_group("Background Style")
@export var background_color: Color = Color(0.6, 0.2, 0.8, 0.9)  # Purple background

# Arc following settings
@export_group("Movement")
@export var follow_smoothness: float = 5.0
@export var arc_intensity: float = 30.0

# Bobbing animation settings
@export_group("Bobbing Animation")
@export var bobbing_intensity: float = 8.0
@export var bobbing_speed: float = 2.0

# Fade settings
@export_group("Fade Effect")
@export var fade_distance: float = 150.0  # Distance at which fading starts
@export var max_fade_distance: float = 250.0  # Distance at which UI is completely invisible
@export var fade_smoothness: float = 8.0

# UI nodes
var ui_canvas: CanvasLayer
var ui_control: Control
var ui_panel: Panel
var ui_label: Label

var player_in_range = false
var current_player: CharacterBody2D = null

# Animation variables
var bobbing_time: float = 0.0
var base_ui_position: Vector2
var target_alpha: float = 1.0

func _ready():
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create the UI
	create_text_ui()

# Debug visualization in editor
func _draw():
	if Engine.is_editor_hint() and show_position_preview:
		# Draw a small circle showing where the UI will appear relative to this trigger
		var preview_pos = ui_offset
		draw_circle(preview_pos, 8, Color.YELLOW)
		draw_circle(preview_pos, 4, Color.BLACK)
		
		# Draw the minimum distance circle
		draw_circle(Vector2.ZERO, min_distance_from_player, Color.YELLOW, false, 1.5)
		
		# Draw a line from center to UI position
		draw_line(Vector2.ZERO, preview_pos, Color.YELLOW, 2.0)
		
		# Draw UI box preview
		var box_pos = preview_pos - ui_size / 2
		draw_rect(Rect2(box_pos, ui_size), Color.YELLOW, false, 1.0)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		current_player = body
		if ui_canvas:
			ui_canvas.visible = true
			# Reset bobbing animation when UI becomes visible
			bobbing_time = 0.0

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		current_player = null
		# Don't immediately hide - let fade effect handle it

func _process(delta):
	# Always update if we have a player reference, even when out of range for fade effect
	if current_player and ui_canvas and ui_canvas.visible:
		update_ui_position_with_arc_and_bob(delta)
		update_fade_effect(delta)
	elif not current_player and ui_canvas:
		# Hide UI if no player reference
		ui_canvas.visible = false

func create_text_ui():
	# Create CanvasLayer as child of this node
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100
	add_child(ui_canvas)
	
	# Create Control node
	ui_control = Control.new()
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_canvas.add_child(ui_control)
	
	# Create the purple panel and text
	create_panel_with_text()
	
	# Hide UI initially
	ui_canvas.visible = false

func create_panel_with_text():
	# Create panel with purple style
	ui_panel = Panel.new()
	ui_panel.size = ui_size
	ui_panel.position = -ui_size / 2
	create_panel_style()
	ui_control.add_child(ui_panel)
	
	# Create label with text
	ui_label = Label.new()
	ui_label.text = display_text
	ui_label.position = Vector2(10, 10)
	ui_label.size = Vector2(ui_size.x - 20, ui_size.y - 20)
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Enable text wrapping and clipping
	ui_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_label.clip_contents = true
	
	# Style the text
	ui_label.add_theme_color_override("font_color", Color.WHITE)
	ui_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui_label.add_theme_constant_override("shadow_offset_x", 2)
	ui_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Apply custom font if provided
	if ui_font:
		ui_label.add_theme_font_override("font", ui_font)
	if ui_font_size > 0:
		ui_label.add_theme_font_size_override("font_size", ui_font_size)
	
	ui_panel.add_child(ui_label)

func create_panel_style():
	var style = StyleBoxFlat.new()
	
	# Create purple gradient background - matching your ghost style
	style.bg_color = Color(0.6, 0.2, 0.8, 0.9)  # Base purple color
	
	# Set up gradient styling
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	
	ui_panel.add_theme_stylebox_override("panel", style)

func get_adaptive_ui_position(base_position: Vector2) -> Vector2:
	if not adaptive_positioning or not current_player:
		return base_position
	
	# Calculate distance from base position to player
	var distance_to_player = base_position.distance_to(current_player.global_position)
	
	# If we're too close to the player, push the UI away
	if distance_to_player < min_distance_from_player:
		var direction_from_player = (base_position - current_player.global_position).normalized()
		
		# If the direction is zero (exactly on player), default to upward
		if direction_from_player.length() < 0.1:
			direction_from_player = Vector2.UP
		
		# Push UI to minimum distance
		return current_player.global_position + (direction_from_player * min_distance_from_player)
	
	return base_position

func update_ui_position_with_arc_and_bob(delta):
	if not ui_control or not current_player:
		return
	
	# Update bobbing animation
	bobbing_time += delta * bobbing_speed
	var bobbing_offset = sin(bobbing_time) * bobbing_intensity
	
	# Get player's velocity for arc calculation
	var player_velocity = current_player.velocity
	var speed_factor = player_velocity.length() / 200.0
	speed_factor = clamp(speed_factor, 0.0, 2.0)
	
	# Calculate arc offset based on player movement
	var arc_offset = Vector2.ZERO
	if player_velocity.length() > 10:
		var velocity_direction = player_velocity.normalized()
		var perpendicular = Vector2(-velocity_direction.y, velocity_direction.x)
		arc_offset = perpendicular * arc_intensity * speed_factor * 0.5
		
		# Reduce bobbing when moving fast (for smoother arc effect)
		bobbing_offset *= (1.0 - (speed_factor * 0.5))
	
	# Calculate base target position using the new ui_offset
	var base_target_pos = current_player.global_position + ui_offset + Vector2(0, bobbing_offset) + arc_offset
	
	# Apply adaptive positioning if enabled
	var target_world_pos = get_adaptive_ui_position(base_target_pos)
	
	# Convert to screen position
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	
	var target_screen_pos: Vector2
	if camera:
		target_screen_pos = target_world_pos - camera.global_position + viewport.get_visible_rect().size / 2
	else:
		target_screen_pos = target_world_pos
	
	# Smooth follow
	ui_control.global_position = ui_control.global_position.lerp(target_screen_pos, follow_smoothness * delta)

func update_fade_effect(delta):
	if not current_player:
		return
	
	# Calculate distance from player to this trigger area
	var distance_to_player = global_position.distance_to(current_player.global_position)
	
	# Calculate target alpha based on distance
	if player_in_range:
		# If in range, full opacity
		target_alpha = 1.0
	else:
		# If out of range, fade based on distance
		if distance_to_player >= max_fade_distance:
			target_alpha = 0.0
		elif distance_to_player >= fade_distance:
			# Linear fade between fade_distance and max_fade_distance
			var fade_ratio = (distance_to_player - fade_distance) / (max_fade_distance - fade_distance)
			target_alpha = 1.0 - fade_ratio
		else:
			target_alpha = 1.0
	
	# Apply fade smoothly
	var current_alpha = ui_control.modulate.a
	var new_alpha = lerp(current_alpha, target_alpha, fade_smoothness * delta)
	ui_control.modulate.a = new_alpha
	
	# Hide UI completely if fully faded
	if new_alpha <= 0.01:
		ui_canvas.visible = false
		current_player = null  # Clear reference when fully faded
	elif not ui_canvas.visible:
		ui_canvas.visible = true
