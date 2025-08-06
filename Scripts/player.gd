extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING, SLIDING, CROUCHING, DYING }

@export var input_left: String = "backward"
@export var input_right: String = "forward"
@export var input_jump: String = "jump"
@export var input_crouch: String = "slide"

# Enhanced movement variables
@export_group("Movement")
@export var max_speed: float = 200.0
@export var acceleration: float = 1200.0  # How quickly we reach max speed
@export var momentum_friction: float = 800.0  # How quickly we slow down when changing direction

@export_group("Jumping")
@export var jump_velocity: float = -340.0

@export_group("Advanced Movement")
@export var dash_speed: float = 400.0
@export var slide_time: float = 0.5

# Death animation settings
@export var death_animation_duration: float = 1.0
@export var death_bounce_height: float = -200.0

# Respawn image settings
@export var respawn_image: Texture2D
@export var respawn_image_duration: float = 0.5
@export var respawn_image_size: Vector2 = Vector2(200, 200)

# Walking sound settings
@export_group("Walking Sound")
@export var walking_sound: AudioStream
@export var walking_volume: float = 0.0
@export var walking_pitch_min: float = 0.9
@export var walking_pitch_max: float = 1.1

# Coyote jump settings
@export_group("Coyote Jump")
@export var coyote_time: float = 0.15

# Jump buffering - allows player to press jump slightly before landing
@export_group("Jump Buffer")
@export var jump_buffer_time: float = 0.1

# Soul management
var souls: int = 0
signal souls_changed(new_count)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_tween: Tween
var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var slide_timer: float = 0.0

# Enhanced movement variables
var last_facing_direction: int = 1  # 1 for right, -1 for left
var is_jumping: bool = false
var jump_buffer_timer: float = 0.0

# Coyote jump variables
var coyote_timer: float = 0.0
var was_on_floor: bool = false

@onready var normal_collision = $NormalCollision
@onready var crouch_collision = $CrouchCollision
@onready var animated_sprite = $AnimatedSprite2D
@onready var walking_audio: AudioStreamPlayer2D = $WalkingAudio
@onready var game_manager : Node2D

# Store original sprite properties
var original_sprite_scale: Vector2
var original_sprite_modulate: Color
var original_sprite_rotation: float

@onready var hit_box = get_node_or_null("HitBox")

@export var respawn_position: Vector2 = Vector2.ZERO
var is_dead = false

# Respawn image overlay components
var respawn_overlay: Control
var respawn_image_rect: TextureRect

func _ready():
	crouch_collision.disabled = true
	$Camera2D/CanvasLayer.visible = true
	respawn_position = global_position
	add_to_group("Player")
	print("DEBUG: Player ready with ", souls, " souls")

	setup_walking_audio()
	
	if animated_sprite:
		original_sprite_scale = animated_sprite.scale
		original_sprite_modulate = animated_sprite.modulate
		original_sprite_rotation = animated_sprite.rotation
	
	if hit_box == null:
		var area_nodes = find_children("*", "Area2D", true, false)
		if area_nodes.size() > 0:
			for area in area_nodes:
				hit_box = area
				break
	
	if hit_box:
		if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
			hit_box.area_entered.connect(_on_hit_box_area_entered)
			
		if not hit_box.body_entered.is_connected(_on_hit_box_body_entered):
			hit_box.body_entered.connect(_on_hit_box_body_entered)

	setup_respawn_overlay()

func setup_walking_audio():
	if not has_node("WalkingAudio"):
		walking_audio = AudioStreamPlayer2D.new()
		walking_audio.name = "WalkingAudio"
		add_child(walking_audio)
	
	if walking_audio:
		walking_audio.stream = walking_sound
		walking_audio.volume_db = walking_volume
		walking_audio.autoplay = false
		walking_audio.bus = "SFX"

func setup_respawn_overlay():
	respawn_overlay = Control.new()
	respawn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	respawn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	respawn_overlay.visible = false
	
	respawn_image_rect = TextureRect.new()
	respawn_image_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	respawn_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	respawn_image_rect.custom_minimum_size = respawn_image_size
	
	respawn_overlay.add_child(respawn_image_rect)
	
	if has_node("Camera2D/CanvasLayer"):
		$Camera2D/CanvasLayer.add_child(respawn_overlay)
	else:
		add_child(respawn_overlay)

func _physics_process(delta):
	if is_dead and current_state != State.DYING:
		return
	
	handle_timers(delta)
	apply_gravity(delta)
	
	previous_state = current_state
	
	handle_input()
	update_movement(delta)
	handle_walking_sound()
	play_animation()
	move_and_slide()

func handle_timers(delta):
	# Handle coyote time
	var on_floor_now = is_on_floor()
	
	if on_floor_now:
		coyote_timer = coyote_time
		was_on_floor = true
		# Reset double jump when landing
		if current_state == State.FALLING or current_state == State.JUMPING:
			can_double_jump = false
			has_double_jumped = false
			is_jumping = false
	elif was_on_floor and not on_floor_now:
		was_on_floor = false
	else:
		if coyote_timer > 0.0:
			coyote_timer -= delta
	
	# Handle jump buffer
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

func apply_gravity(delta):
	if not is_on_floor() and current_state != State.DYING:
		velocity.y += gravity * delta

func handle_walking_sound():
	if current_state == State.RUNNING and is_on_floor():
		if not walking_audio.playing:
			play_walking_sound()
	else:
		if walking_audio.playing:
			walking_audio.stop()

func play_walking_sound():
	if walking_sound and walking_audio:
		walking_audio.pitch_scale = randf_range(walking_pitch_min, walking_pitch_max)
		walking_audio.play()

func can_coyote_jump() -> bool:
	return coyote_timer > 0.0 and not is_on_floor() and current_state == State.FALLING
	
func handle_input():
	if current_state == State.DYING:
		return
		
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	var crouching = Input.is_action_pressed(input_crouch)
	
	# Handle jump buffer
	if Input.is_action_just_pressed(input_jump):
		jump_buffer_timer = jump_buffer_time
		
	# Try to use buffered jump or immediate jump
	var should_jump = jump_buffer_timer > 0.0
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif should_jump:
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
			if should_jump:
				if is_on_floor():
					jump()
				elif can_double_jump and has_double_jumped == false:
					double_jump()
				elif can_coyote_jump():
					coyote_jump()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
				can_double_jump = false
				has_double_jumped = false
				
		State.SLIDING:
			slide_timer -= get_physics_process_delta_time()
			if slide_timer <= 0 or not crouching or not is_on_floor():
				end_crouch()
				current_state = State.FALLING if not is_on_floor() else State.IDLE
				
		State.CROUCHING:
			if should_jump:
				end_crouch()
				jump()
			elif not crouching or not is_on_floor():
				end_crouch()
				current_state = State.FALLING if not is_on_floor() else State.IDLE

func update_movement(delta):
	if current_state == State.DYING:
		return
		
	var direction = Input.get_axis(input_left, input_right)
	
	# Update facing direction only when actually giving input
	if direction != 0:
		if direction > 0:
			last_facing_direction = 1  # facing right
		else:
			last_facing_direction = -1  # facing left

	match current_state:
		State.IDLE:
			apply_momentum_movement(0, delta)
			# Always use the last facing direction
			animated_sprite.flip_h = last_facing_direction > 0
			
		State.RUNNING:
			apply_momentum_movement(direction, delta)
			# Always use the last facing direction  
			animated_sprite.flip_h = last_facing_direction < 0
		
		State.JUMPING, State.FALLING:
			apply_momentum_movement(direction, delta)
			# Always use the last facing direction
			animated_sprite.flip_h = last_facing_direction < 0
				
		State.SLIDING:
			velocity.x = move_toward(velocity.x, 0, max_speed * delta)
			
		State.CROUCHING:
			apply_momentum_movement(0, delta, momentum_friction * 2)  # Stop faster when crouching

func apply_momentum_movement(direction: float, delta: float, custom_friction: float = momentum_friction):
	if direction != 0:
		# Moving in a direction
		var target_velocity = direction * max_speed
		
		# If we're moving in opposite direction to current velocity, apply friction first (momentum)
		if sign(velocity.x) != sign(direction) and abs(velocity.x) > 10:
			velocity.x = move_toward(velocity.x, 0, custom_friction * delta)
		else:
			# Normal acceleration towards target
			velocity.x = move_toward(velocity.x, target_velocity, acceleration * delta)
	else:
		# No input - apply friction
		velocity.x = move_toward(velocity.x, 0, custom_friction * delta)





func play_animation():
	match current_state:
		State.IDLE: animated_sprite.play("idle")
		State.RUNNING: animated_sprite.play("run")
		State.JUMPING: animated_sprite.play("jump")
		State.FALLING: animated_sprite.play("fall")
		State.SLIDING: animated_sprite.play("slide")
		State.CROUCHING: animated_sprite.play("crouch")
		State.DYING: 
			if animated_sprite.sprite_frames.has_animation("death"):
				animated_sprite.play("death")
			else:
				animated_sprite.stop()

func jump():
	velocity.y = jump_velocity
	can_double_jump = true
	has_double_jumped = false
	is_jumping = true
	current_state = State.JUMPING
	coyote_timer = 0.0
	jump_buffer_timer = 0.0  # Consume the jump buffer

func coyote_jump():
	velocity.y = jump_velocity
	current_state = State.JUMPING
	is_jumping = true
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	print("Coyote jump activated!")

func double_jump():
	velocity.y = jump_velocity * 0.8
	has_double_jumped = true
	can_double_jump = false
	is_jumping = true
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

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

func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy"):
		die()

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		die()

func die():
	if is_dead:
		return
		
	is_dead = true
	current_state = State.DYING
	
	if walking_audio.playing:
		walking_audio.stop()
	
	if death_tween:
		death_tween.kill()
	
	velocity.x = 0
	
	if death_bounce_height != 0:
		velocity.y = death_bounce_height
	
	death_tween = create_tween()
	death_tween.set_parallel(true)
	
	death_tween.tween_property(animated_sprite, "modulate:a", 0.0, death_animation_duration)
	death_tween.tween_property(animated_sprite, "scale", Vector2(0.5, 0.5), death_animation_duration)
	death_tween.tween_property(animated_sprite, "rotation", deg_to_rad(360), death_animation_duration)
	
	await death_tween.finished
	respawn()
		
func respawn():
	if death_tween:
		death_tween.kill()
		death_tween = null
	
	if animated_sprite:
		animated_sprite.scale = original_sprite_scale
		animated_sprite.modulate = original_sprite_modulate
		animated_sprite.rotation = original_sprite_rotation
		animated_sprite.queue_redraw()
	
	is_dead = false
	global_position = respawn_position
	velocity = Vector2.ZERO
	current_state = State.IDLE
	
	can_double_jump = false
	has_double_jumped = false
	is_jumping = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	was_on_floor = false
	
	normal_collision.disabled = false
	crouch_collision.disabled = true
	
	show_respawn_image()

func set_respawn_point(new_position: Vector2):
	respawn_position = new_position

func add_soul(amount: int = 1):
	souls += amount
	souls_changed.emit(souls)
	print("Souls collected: ", souls)

func remove_souls(amount: int = 1) -> bool:
	if souls >= amount:
		souls -= amount
		souls_changed.emit(souls)
		print("Souls used: ", amount, " | Remaining: ", souls)
		return true
	else:
		print("Not enough souls! Have: ", souls, " | Need: ", amount)
		return false

func get_soul_count() -> int:
	return souls

func has_souls() -> bool:
	return souls > 0

func get_soul_display() -> String:
	return "Souls: " + str(souls)

func interact():
	print("Picked up: ", souls)
	queue_free()

func show_respawn_image():
	if respawn_image and respawn_overlay and respawn_image_rect:
		respawn_image_rect.texture = respawn_image
		respawn_overlay.visible = true
		
		var image_tween = create_tween()
		respawn_overlay.modulate.a = 1.0
		
		image_tween.tween_interval(respawn_image_duration * 0.8)
		image_tween.tween_property(respawn_overlay, "modulate:a", 0.0, respawn_image_duration * 0.2)
		
		await image_tween.finished
		respawn_overlay.visible = false
		respawn_overlay.modulate.a = 1.0
