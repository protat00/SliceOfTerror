extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING, SLIDING, CROUCHING }

@export var input_left: String = "backward"
@export var input_right: String = "forward"
@export var input_jump: String = "jump"
@export var input_crouch: String = "slide"

#controller variables
@export var speed: float = 200.0
@export var jump_velocity: float = -340.0
@export var dash_speed: float = 400.0
@export var slide_time: float = 0.5

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var slide_timer: float = 0.0

@onready var normal_collision = $NormalCollision
@onready var crouch_collision = $CrouchCollision
@onready var animated_sprite = $AnimatedSprite2D
@onready var game_manager : Node2D

# Try to get HitBox - this might fail if the node doesn't exist
@onready var hit_box = get_node_or_null("HitBox")

@export var respawn_position: Vector2 = Vector2.ZERO
var is_dead = false

func _ready():
	crouch_collision.disabled = true
	$Camera2D/CanvasLayer.visible = true
	respawn_position = global_position
	add_to_group("Player")
	
	# Debug: Print all child nodes
	print("=== PLAYER DEBUG INFO ===")
	print("Player children:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		if child is Area2D:
			print("    Area2D found! Groups: ", child.get_groups())
			print("    Children of Area2D:")
			for grandchild in child.get_children():
				print("      - ", grandchild.name, " (", grandchild.get_class(), ")")
	
	# Check if HitBox exists
	if hit_box == null:
		print("ERROR: HitBox not found! Looking for Area2D nodes...")
		var area_nodes = find_children("*", "Area2D", true, false)
		if area_nodes.size() > 0:
			print("Found Area2D nodes:")
			for area in area_nodes:
				print("  - ", area.name)
				hit_box = area
				break
		else:
			print("No Area2D nodes found at all!")
			return
	
	if hit_box:
		print("HitBox found: ", hit_box.name)
		print("HitBox groups: ", hit_box.get_groups())
		
		# Connect signal
		if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
			hit_box.area_entered.connect(_on_hit_box_area_entered)
			print("Connected area_entered signal")
		else:
			print("area_entered signal already connected")
			
		# Also connect body_entered just in case
		if not hit_box.body_entered.is_connected(_on_hit_box_body_entered):
			hit_box.body_entered.connect(_on_hit_box_body_entered)
			print("Connected body_entered signal")
	else:
		print("ERROR: No HitBox Area2D found!")
	
	print("=== END PLAYER DEBUG ===")

func _physics_process(delta):
	# Add debug info when dead
	if is_dead:
		# Print debug info every 60 frames (about once per second at 60 FPS)
		if Engine.get_process_frames() % 60 == 0:
			print("Player is dead, skipping physics process")
		return  # Don't process movement when dead
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	handle_input()
	update_movement(delta)
	play_animation()
	move_and_slide()
	
func handle_input():
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	var crouching = Input.is_action_pressed(input_crouch)
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif Input.is_action_just_pressed(input_jump):
				jump()
			elif crouching and moving:
				start_slide()
			elif crouching:
				start_crouch()
			elif moving:
				current_state = State.RUNNING
			else:
				current_state = State.IDLE
		
		State.JUMPING, State.FALLING:
			if Input.is_action_just_pressed(input_jump) and can_double_jump:
				double_jump()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
				
		State.SLIDING:
			slide_timer -= get_physics_process_delta_time()
			if slide_timer <= 0 or not crouching or not is_on_floor():
				end_crouch()
				current_state = State.FALLING if not is_on_floor() else State.IDLE
				
		State.CROUCHING:
			if Input.is_action_just_pressed(input_jump):
				end_crouch()
				jump()
			elif not crouching or not is_on_floor():
				end_crouch()
				current_state = State.FALLING if not is_on_floor() else State.IDLE

var bruh = 0		
func update_movement(delta):
	var direction = Input.get_axis(input_left, input_right)

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * 3 * delta)
			animated_sprite.flip_h = bruh > 0
		State.RUNNING:
			velocity.x = direction * speed
			bruh = direction

			if direction != 0:
				animated_sprite.flip_h = direction < 0
		
		State.JUMPING, State.FALLING:
			if direction != 0:
				velocity.x = direction * speed
				animated_sprite.flip_h = direction < 0
		State.SLIDING:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
		State.CROUCHING:
			velocity.x = move_toward(velocity.x, 0, speed * 4 * delta)

func play_animation():
	match current_state:
		State.IDLE: animated_sprite.play("idle")
		State.RUNNING: animated_sprite.play("run")
		State.JUMPING: animated_sprite.play("jump")
		State.FALLING: animated_sprite.play("fall")
		State.SLIDING: animated_sprite.play("slide")
		State.CROUCHING: animated_sprite.play("crouch")

func jump():
	velocity.y = jump_velocity
	can_double_jump = true
	has_double_jumped = false
	current_state = State.JUMPING

func double_jump():
	velocity.y = jump_velocity * 0.8
	has_double_jumped = true
	can_double_jump = false

func start_slide():
	if is_on_floor():
		normal_collision.disabled = true
		crouch_collision.disabled = false
		slide_timer = slide_time
		current_state = State.SLIDING

func start_crouch():
	if is_on_floor():
		normal_collision.disabled = true
		crouch_collision.disabled = false
		current_state = State.CROUCHING

func end_crouch():
	normal_collision.disabled = false
	crouch_collision.disabled = true

# This should be called when an Area2D enters the HitBox
func _on_hit_box_area_entered(area: Area2D) -> void:
	print("🔥 AREA ENTERED DETECTED! 🔥")
	print("Area name: ", area.name)
	print("Area parent: ", area.get_parent().name if area.get_parent() else "No parent")
	print("Area groups: ", area.get_groups())
	
	if area.is_in_group("Enemy"):
		print("💀 ENEMY DETECTED - PLAYER SHOULD DIE! 💀")
		die()
	else:
		print("❌ Area not in Enemy group")

# This should be called when a CharacterBody2D enters the HitBox  
func _on_hit_box_body_entered(body: Node2D) -> void:
	print("🔥 BODY ENTERED DETECTED! 🔥")
	print("Body name: ", body.name)
	print("Body groups: ", body.get_groups())
	
	if body.is_in_group("Enemy"):
		print("💀 ENEMY BODY DETECTED - PLAYER SHOULD DIE! 💀")
		die()
	else:
		print("❌ Body not in Enemy group")

func die():
	print("🔥 DIE METHOD CALLED! 🔥")
	print("Current is_dead state: ", is_dead)
	
	if is_dead:
		print("❌ Already dead, returning early")
		return  # Prevent multiple deaths
		
	is_dead = true
	print("💀💀💀 PLAYER DIED! Setting is_dead to true 💀💀💀")
	print("Stopping velocity and movement")
	velocity = Vector2.ZERO  # Stop movement immediately
	current_state = State.IDLE
	
	# Make player visually disappear or change color to show death
	if animated_sprite:
		animated_sprite.modulate = Color.RED  # Turn player red when dead
		print("Player sprite turned red")
	
	print("Starting respawn timer...")
	# Respawn after a short delay
	await get_tree().create_timer(1.0).timeout
	print("Respawn timer finished, calling respawn()")
	respawn()
		
func respawn():
	print("🔄 RESPAWN METHOD CALLED! 🔄")
	is_dead = false
	global_position = respawn_position
	velocity = Vector2.ZERO
	current_state = State.IDLE
	print("🔄 Player respawned at position: ", respawn_position, " 🔄")
	
	# Reset visual appearance
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE  # Reset color
		print("Player sprite color reset")
	
	# Reset collision states
	normal_collision.disabled = false
	crouch_collision.disabled = true
	print("Collision states reset")

# Optional: Function to set new respawn points (call this at checkpoints)
func set_respawn_point(new_position: Vector2):
	respawn_position = new_position
	print("New respawn point set!")
