extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING, SLIDING, CROUCHING, DYING }

@export var input_left: String = "backward"
@export var input_right: String = "forward"
@export var input_jump: String = "jump"
@export var input_crouch: String = "slide"

#controller variables
@export var speed: float = 200.0
@export var jump_velocity: float = -340.0
@export var dash_speed: float = 400.0
@export var slide_time: float = 0.5

# Death animation settings
@export var death_animation_duration: float = 1.0
@export var death_bounce_height: float = -200.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_tween: Tween  # Keep reference to the death tween
var current_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var slide_timer: float = 0.0

@onready var normal_collision = $NormalCollision
@onready var crouch_collision = $CrouchCollision
@onready var animated_sprite = $AnimatedSprite2D
@onready var game_manager : Node2D

# Store original sprite properties
var original_sprite_scale: Vector2
var original_sprite_modulate: Color
var original_sprite_rotation: float

# Try to get HitBox - this might fail if the node doesn't exist
@onready var hit_box = get_node_or_null("HitBox")

@export var respawn_position: Vector2 = Vector2.ZERO
var is_dead = false

func _ready():
	crouch_collision.disabled = true
	$Camera2D/CanvasLayer.visible = true
	respawn_position = global_position
	add_to_group("Player")
	
	# Store original sprite properties
	if animated_sprite:
		original_sprite_scale = animated_sprite.scale
		original_sprite_modulate = animated_sprite.modulate
		original_sprite_rotation = animated_sprite.rotation
	
	# Check if HitBox exists
	if hit_box == null:
		var area_nodes = find_children("*", "Area2D", true, false)
		if area_nodes.size() > 0:
			for area in area_nodes:
				hit_box = area
				break
	
	if hit_box:
		# Connect signals
		if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
			hit_box.area_entered.connect(_on_hit_box_area_entered)
			
		if not hit_box.body_entered.is_connected(_on_hit_box_body_entered):
			hit_box.body_entered.connect(_on_hit_box_body_entered)

func _physics_process(delta):
	if is_dead and current_state != State.DYING:
		return  # Don't process movement when dead (unless playing death animation)
	
	if not is_on_floor() and current_state != State.DYING:
		velocity.y += gravity * delta
	
	handle_input()
	update_movement(delta)
	play_animation()
	move_and_slide()
	
func handle_input():
	# Don't handle input during death animation
	if current_state == State.DYING:
		return
		
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
	# Don't update movement during death animation (let the death animation handle movement)
	if current_state == State.DYING:
		return
		
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
		State.DYING: 
			# Check if you have a specific death animation, otherwise use a fallback
			if animated_sprite.sprite_frames.has_animation("death"):
				animated_sprite.play("death")
			else:
				# If no death animation exists, just stop the current animation
				animated_sprite.stop()

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
	if area.is_in_group("Enemy"):
		die()

# This should be called when a CharacterBody2D enters the HitBox  
func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		die()

func die():
	if is_dead:
		return  # Prevent multiple deaths
		
	is_dead = true
	current_state = State.DYING
	
	# Stop any existing death tween
	if death_tween:
		death_tween.kill()
	
	# Stop horizontal movement but allow death animation physics
	velocity.x = 0
	
	# Start death animation with optional bounce effect
	if death_bounce_height != 0:
		velocity.y = death_bounce_height
	
	# Create death animation tween for visual effects
	death_tween = create_tween()
	death_tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
	
	# Fade out effect
	death_tween.tween_property(animated_sprite, "modulate:a", 0.0, death_animation_duration)
	
	# Optional: Scale effect (make player shrink)
	death_tween.tween_property(animated_sprite, "scale", Vector2(0.5, 0.5), death_animation_duration)
	
	# Optional: Rotation effect
	death_tween.tween_property(animated_sprite, "rotation", deg_to_rad(360), death_animation_duration)
	
	# Wait for animation to complete, then respawn
	await death_tween.finished
	respawn()
		
func respawn():
	# Kill the death tween completely before resetting
	if death_tween:
		death_tween.kill()
		death_tween = null
	
	# Force immediate reset using original stored values
	if animated_sprite:
		animated_sprite.scale = original_sprite_scale
		animated_sprite.modulate = original_sprite_modulate
		animated_sprite.rotation = original_sprite_rotation
		
		# Force a visual update
		animated_sprite.queue_redraw()
	
	is_dead = false
	global_position = respawn_position
	velocity = Vector2.ZERO
	current_state = State.IDLE
	
	# Reset collision states
	normal_collision.disabled = false
	crouch_collision.disabled = true

# Optional: Function to set new respawn points (call this at checkpoints)
func set_respawn_point(new_position: Vector2):
	respawn_position = new_position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if Input.is_action_pressed("pick_up"):
		print('hehehe')


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
