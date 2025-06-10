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

func _ready():
	crouch_collision.disabled = true
	$Camera2D/CanvasLayer.visible = true

func _physics_process(delta):
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
	print(current_state)
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
