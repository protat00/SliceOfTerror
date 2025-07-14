extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D

# Soul delivery system
@export var souls_required: int = 1  # How many souls needed to make this ghost disappear
@export var delivery_text: String = "Press Q to deliver soul"
@export var ui_background_texture: Texture2D
@export var ui_size: Vector2 = Vector2(200, 50)
@export var ui_offset_distance: float = 80.0
@export var ui_height_offset: float = -60.0
@export var smooth_follow_speed: float = 8.0

var sprite_offset: Vector2
var player_in_range = false
var last_player_reference = null
var can_deliver = false
var is_satisfied = false  # Ghost has received enough souls

# UI nodes for delivery prompt
var ui_canvas: CanvasLayer
var ui_control: Control
var ui_panel: Panel
var ui_label: Label

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
	
	# Create delivery UI
	create_delivery_ui()
	
	print("Ghost ready with soul delivery system")

func _process(delta):
	# Make collision follow the animated sprite's position
	collision_shape.position = animated_sprite.position + sprite_offset
	
	# Update delivery UI position if visible
	if can_deliver and ui_canvas and ui_canvas.visible:
		update_ui_position(delta)
	
	# DEBUG: Show current state
	if player_in_range:
		print("DEBUG: Player in range, can_deliver: ", can_deliver, ", is_satisfied: ", is_satisfied)
		if last_player_reference and last_player_reference.has_method("get_soul_count"):
			print("DEBUG: Player souls: ", last_player_reference.get_soul_count())
	
	# Only kill player if ghost hasn't been satisfied with souls
	if not is_satisfied and player_in_range and last_player_reference != null:
		if is_instance_valid(last_player_reference) and last_player_reference.has_method("die"):
			# Check if player can deliver souls first
			if can_player_deliver_soul(last_player_reference):
				# Don't kill if player can deliver
				return
			
			# Double-check they're still overlapping
			var overlapping_bodies = area_2d.get_overlapping_bodies()
			if last_player_reference in overlapping_bodies:
				if not last_player_reference.is_dead:  # Only kill if not already dead
					print("💀 Continuous detection - KILLING PLAYER! 💀")
					last_player_reference.die()

func create_delivery_ui():
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
	
	# Apply custom texture or fallback style
	if ui_background_texture:
		var style = StyleBoxTexture.new()
		style.texture = ui_background_texture
		ui_panel.add_theme_stylebox_override("panel", style)
	else:
		create_fallback_style()
	
	ui_control.add_child(ui_panel)
	
	# Create label
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
	ui_panel.add_child(ui_label)
	
	# Hide UI initially
	ui_canvas.visible = false
	
	print("DEBUG: UI created successfully")

func create_fallback_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.8, 0.9)  # Purple ghost theme
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

func update_ui_position(delta):
	if not ui_control or not last_player_reference:
		return
	
	# Position UI above the ghost
	var ui_world_pos = global_position + Vector2(0, ui_height_offset)
	
	# Simple world-to-screen conversion
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	
	var screen_pos: Vector2
	if camera:
		screen_pos = ui_world_pos - camera.global_position + viewport.get_visible_rect().size / 2
	else:
		screen_pos = ui_world_pos
	
	# Smooth follow movement
	ui_control.global_position = ui_control.global_position.lerp(screen_pos, smooth_follow_speed * delta)

func _input(event):
	# DEBUG: Check if input is being received
	if event.is_action_pressed("deliver_soul"):
		print("DEBUG: deliver_soul input detected, can_deliver: ", can_deliver)
	
	if can_deliver and event.is_action_pressed("deliver_soul"):
		deliver_soul()

func _on_area_2d_body_entered(body):
	print("👻 Ghost detected body entering: ", body.name)
	
	if body.is_in_group("Player") or body.has_method("die"):
		player_in_range = true
		last_player_reference = body
		
		print("DEBUG: Player entered ghost area")
		
		# Check if player can deliver souls
		if can_player_deliver_soul(body):
			can_deliver = true
			if ui_canvas:
				ui_canvas.visible = true
				print("DEBUG: UI should now be visible")
			print("👻 Player can deliver soul! UI shown.")
		else:
			print("DEBUG: Player cannot deliver soul")
			if not is_satisfied:
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
		can_deliver = false
		if ui_canvas:
			ui_canvas.visible = false
		print("Player left ghost area")

func can_player_deliver_soul(player) -> bool:
	print("DEBUG: Checking if player can deliver soul...")
	
	# Check if player has a soul inventory and has souls to deliver
	if player.has_method("get_soul_count"):
		var soul_count = player.get_soul_count()
		print("DEBUG: Player has ", soul_count, " souls, needs ", souls_required)
		return soul_count >= souls_required
	elif player.has_method("has_souls"):
		var has_souls = player.has_souls()
		print("DEBUG: Player has_souls() returned: ", has_souls)
		return has_souls
	elif player.has_signal("souls_changed"):
		# Try to access a souls variable
		if "souls" in player:
			print("DEBUG: Player souls property: ", player.souls)
			return player.souls >= souls_required
	
	# Fallback: assume player can deliver if they have any method related to souls
	var can_deliver_fallback = player.has_method("remove_souls") or player.has_method("deliver_soul")
	print("DEBUG: Fallback check: ", can_deliver_fallback)
	return can_deliver_fallback

func deliver_soul():
	print("DEBUG: Attempting to deliver soul...")
	
	if not can_deliver or not last_player_reference:
		print("DEBUG: Cannot deliver - can_deliver: ", can_deliver, ", player_ref: ", last_player_reference != null)
		return
	
	# Try different methods to remove souls from player
	var soul_removed = false
	
	if last_player_reference.has_method("remove_souls"):
		print("DEBUG: Trying remove_souls method...")
		soul_removed = last_player_reference.remove_souls(souls_required)
		print("DEBUG: remove_souls returned: ", soul_removed)
	elif last_player_reference.has_method("deliver_soul"):
		print("DEBUG: Trying deliver_soul method...")
		soul_removed = last_player_reference.deliver_soul(souls_required)
	elif last_player_reference.has_method("use_soul"):
		print("DEBUG: Trying use_soul method...")
		soul_removed = last_player_reference.use_soul()
	elif "souls" in last_player_reference:
		print("DEBUG: Trying direct souls property...")
		if last_player_reference.souls >= souls_required:
			last_player_reference.souls -= souls_required
			soul_removed = true
	
	if soul_removed:
		print("👻 Soul delivered to ghost! Ghost is satisfied.")
		is_satisfied = true
		can_deliver = false
		
		# Hide UI
		if ui_canvas:
			ui_canvas.visible = false
		
		# Make ghost disappear with a nice effect
		disappear()
	else:
		print("❌ Could not remove soul from player!")

func disappear():
	print("👻 Ghost disappearing...")
	
	# Create a simple fade-out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	
	# Optional: Add particle effect or sound here
	# particle_system.emitting = true
	# audio_player.play()

func _exit_tree():
	# UI will be automatically freed when this node is freed
	pass
