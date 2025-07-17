extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animated_sprite = $AnimatedSprite2D

# Separate collision areas for different purposes
@onready var death_area = $DeathArea
@onready var delivery_area = $DeliveryArea
@onready var death_collision = $DeathArea/CollisionShape2D
@onready var delivery_collision = $DeliveryArea/CollisionShape2D

# Soul delivery system
@export var souls_required: int = 1
@export var delivery_text: String = "Press Q to deliver item"
@export var ui_background_texture: Texture2D
@export var ui_size: Vector2 = Vector2(200, 50)
@export var ui_offset_distance: float = 80.0
@export var ui_height_offset: float = -60.0
@export var smooth_follow_speed: float = 8.0

# Bobbing animation variables
@export var bobbing_intensity: float = 10.0  # How far up/down the UI moves
@export var bobbing_speed: float = 3.0       # How fast the bobbing animation is

# Font customization
@export var ui_font: Font                    # Custom font for the UI text
@export var ui_font_size: int = 16           # Font size for the UI text

# Gradient animation variables
@export var gradient_colors: Array[Color] = [Color.WHITE, Color.CYAN, Color.MAGENTA, Color.YELLOW]  # Colors for gradient
@export var gradient_speed: float = 2.0      # Speed of gradient animation
@export var use_gradient_animation: bool = true  # Toggle gradient animation on/off

var sprite_offset_death: Vector2
var sprite_offset_delivery: Vector2
var player_in_delivery_range = false
var player_in_death_range = false
var last_player_reference = null
var can_deliver = false
var is_satisfied = false

# UI nodes for delivery prompt
var ui_canvas: CanvasLayer
var ui_control: Control
var ui_panel: Panel
var ui_label: Label

# Bobbing animation variables
var bobbing_time: float = 0.0
var base_ui_position: Vector2

# Gradient animation variables
var gradient_time: float = 0.0
var current_gradient_index: int = 0

# Reference to the soul count UI
var soul_count_ui = null

func _ready():
	# Store the initial offsets between sprite and collision shapes
	sprite_offset_death = death_collision.position - animated_sprite.position
	sprite_offset_delivery = delivery_collision.position - animated_sprite.position
	
	# Add ghost to Enemy group
	add_to_group("Enemy")
	
	# Get reference to soul count UI (adjust path as needed)
	# Try different common paths where the UI might be
	soul_count_ui = get_node_or_null("/root/Main/SoulCountUI")
	if not soul_count_ui:
		soul_count_ui = get_node_or_null("/root/SoulCountUI")
	if not soul_count_ui:
		soul_count_ui = get_tree().get_first_node_in_group("SoulCountUI")
	if not soul_count_ui:
		# Search for any CanvasLayer with soul count methods
		var canvas_layers = get_tree().get_nodes_in_group("CanvasLayer")
		for layer in canvas_layers:
			if layer.has_method("remove_souls"):
				soul_count_ui = layer
				break
	
	if not soul_count_ui:
		print("WARNING: Could not find soul count UI!")
	
	# Connect death area signals
	if not death_area.body_entered.is_connected(_on_death_area_body_entered):
		death_area.body_entered.connect(_on_death_area_body_entered)
	
	if not death_area.body_exited.is_connected(_on_death_area_body_exited):
		death_area.body_exited.connect(_on_death_area_body_exited)
	
	# Connect delivery area signals
	if not delivery_area.body_entered.is_connected(_on_delivery_area_body_entered):
		delivery_area.body_entered.connect(_on_delivery_area_body_entered)
	
	if not delivery_area.body_exited.is_connected(_on_delivery_area_body_exited):
		delivery_area.body_exited.connect(_on_delivery_area_body_exited)
	
	# Create delivery UI
	create_delivery_ui()
	
	print("Ghost ready with separate collision areas")

func _process(delta):
	# Make collision shapes follow the animated sprite's position
	death_collision.position = animated_sprite.position + sprite_offset_death
	delivery_collision.position = animated_sprite.position + sprite_offset_delivery
	
	# Update delivery UI position if visible
	if can_deliver and ui_canvas and ui_canvas.visible:
		update_ui_position(delta)
		
		# Update gradient animation
		if use_gradient_animation:
			update_gradient_animation(delta)
	
	# Handle death logic - only kill if ghost hasn't been satisfied
	if not is_satisfied and player_in_death_range and last_player_reference != null:
		if is_instance_valid(last_player_reference) and last_player_reference.has_method("die"):
			# Double-check they're still overlapping with death area
			var overlapping_bodies = death_area.get_overlapping_bodies()
			if last_player_reference in overlapping_bodies:
				if not last_player_reference.is_dead:
					print("💀 Death area collision - KILLING PLAYER! 💀")
					last_player_reference.die()

# DEATH AREA SIGNALS
func _on_death_area_body_entered(body):
	print("💀 Death area - body entered: ", body.name)
	
	if body.is_in_group("Player") or body.has_method("die"):
		player_in_death_range = true
		last_player_reference = body
		
		# Only kill immediately if ghost is not satisfied
		if not is_satisfied:
			print("💀 DEATH AREA - KILLING IMMEDIATELY! 💀")
			if body.has_method("die") and not body.is_dead:
				body.die()
			else:
				print("ERROR: Player doesn't have die() method or is already dead!")

func _on_death_area_body_exited(body):
	print("💀 Death area - body exited: ", body.name)
	
	if body == last_player_reference:
		player_in_death_range = false
		# Don't reset last_player_reference here in case they're still in delivery range

# DELIVERY AREA SIGNALS
func _on_delivery_area_body_entered(body):
	print("📦 Delivery area - body entered: ", body.name)
	
	if body.is_in_group("Player") or body.has_method("die"):
		player_in_delivery_range = true
		last_player_reference = body
		
		# Check if player can deliver souls
		if can_player_deliver_soul():
			can_deliver = true
			if ui_canvas:
				ui_canvas.visible = true
				# Reset bobbing animation when UI becomes visible
				bobbing_time = 0.0
				gradient_time = 0.0
				print("📦 Player can deliver soul! UI shown.")
		else:
			print("📦 Player cannot deliver soul")

func _on_delivery_area_body_exited(body):
	print("📦 Delivery area - body exited: ", body.name)
	
	if body == last_player_reference:
		player_in_delivery_range = false
		can_deliver = false
		if ui_canvas:
			ui_canvas.visible = false
		
		# Only reset player reference if they're not in death range either
		if not player_in_death_range:
			last_player_reference = null

func create_delivery_ui():
	# Create CanvasLayer as child of this node
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100
	add_child(ui_canvas)
	
	# Create Control node
	ui_control = Control.new()
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_canvas.add_child(ui_control)
	
	# Create panel
	ui_panel = Panel.new()
	ui_panel.size = ui_size
	ui_panel.position = -ui_size / 2
	
	# Apply custom texture or fallback style
	if ui_background_texture:
		var style = StyleBoxTexture.new()
		style.texture = ui_background_texture
		ui_panel.add_theme_stylebox_override("panel", style)
	else:
		create_fallback_style()
	
	ui_control.add_child(ui_panel)
	
	# Create label with white text
	ui_label = Label.new()
	ui_label.text = delivery_text
	ui_label.position = Vector2(10, 10)
	ui_label.size = Vector2(ui_size.x - 20, ui_size.y - 20)
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_label.add_theme_color_override("font_color", Color.WHITE)
	ui_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui_label.add_theme_constant_override("shadow_offset_x", 2)
	ui_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Apply custom font and font size if provided
	if ui_font:
		ui_label.add_theme_font_override("font", ui_font)
	if ui_font_size > 0:
		ui_label.add_theme_font_size_override("font_size", ui_font_size)
	
	ui_panel.add_child(ui_label)
	
	# Hide UI initially
	ui_canvas.visible = false

func create_fallback_style():
	var style = StyleBoxFlat.new()
	
	# Create purple gradient background
	style.bg_color = Color(0.6, 0.2, 0.8, 0.9)  # Base purple color
	
	# Set up gradient
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	
	# Create gradient effect with different purple shades
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.4, 1.0, 0.9))    # Light purple at top
	gradient.add_point(1.0, Color(0.4, 0.1, 0.6, 0.9))    # Dark purple at bottom
	
	# Apply gradient to the style
	style.set_bg_color(Color(0.6, 0.2, 0.8, 0.9))
	
	ui_panel.add_theme_stylebox_override("panel", style)

func update_ui_position(delta):
	if not ui_control or not last_player_reference:
		return
	
	# Update bobbing animation
	bobbing_time += delta * bobbing_speed
	var bobbing_offset = sin(bobbing_time) * bobbing_intensity
	
	# Calculate the target position with bobbing
	var ui_world_pos = global_position + Vector2(0, ui_height_offset + bobbing_offset)
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	
	var screen_pos: Vector2
	if camera:
		screen_pos = ui_world_pos - camera.global_position + viewport.get_visible_rect().size / 2
	else:
		screen_pos = ui_world_pos
	
	# Store the base position for smooth following
	base_ui_position = screen_pos
	
	# Apply smooth following to the bobbing position
	ui_control.global_position = ui_control.global_position.lerp(base_ui_position, smooth_follow_speed * delta)

func update_gradient_animation(delta):
	# Animation removed - using static purple gradient box instead
	pass

func _input(event):
	if can_deliver and event.is_action_pressed("deliver_soul"):
		deliver_soul()

func can_player_deliver_soul() -> bool:
	if not soul_count_ui:
		print("ERROR: No soul count UI found!")
		return false
	
	if soul_count_ui.has_method("has_souls"):
		return soul_count_ui.has_souls()
	elif soul_count_ui.has_method("get_soul_count"):
		return soul_count_ui.get_soul_count() >= souls_required
	
	print("ERROR: Soul count UI doesn't have expected methods!")
	return false

func deliver_soul():
	if not can_deliver or not soul_count_ui:
		print("Cannot deliver: can_deliver=", can_deliver, ", soul_count_ui=", soul_count_ui)
		return
	
	# Check if we have souls to deliver
	if not soul_count_ui.has_souls():
		print("❌ No souls to deliver!")
		return
	
	# Remove souls from the UI
	if soul_count_ui.has_method("remove_souls"):
		soul_count_ui.remove_souls(souls_required)
		print("👻 Soul delivered to ghost! Ghost is satisfied.")
		is_satisfied = true
		can_deliver = false
		
		# Hide UI
		if ui_canvas:
			ui_canvas.visible = false
		
		# Make ghost disappear
		disappear()
	else:
		print("❌ Could not remove soul - UI doesn't have remove_souls method!")

func disappear():
	print("👻 Ghost disappearing...")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _exit_tree():
	pass
