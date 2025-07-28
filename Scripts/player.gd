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

# Respawn image settings
@export var respawn_image: Texture2D  # Drag your image here in the inspector
@export var respawn_image_duration: float = 0.5
@export var respawn_image_size: Vector2 = Vector2(200, 200)  # Width and Height of the image

# Walking sound settings
@export_group("Walking Sound")
@export var walking_sound: AudioStream  # Drag your walking sound file here
@export var walking_volume: float = 0.0  # Volume in dB (-80 to 24)
@export var walking_pitch_min: float = 0.9  # Minimum pitch variation
@export var walking_pitch_max: float = 1.1  # Maximum pitch variation

# Coyote jump settings
@export_group("Coyote Jump")
@export var coyote_time: float = 0.15  # Time in seconds after leaving ground where jump is still allowed

# Soul management
var souls: int = 0
signal souls_changed(new_count)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_tween: Tween  # Keep reference to the death tween
var current_state: State = State.IDLE
var previous_state: State = State.IDLE  # Track previous state for sound management
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var slide_timer: float = 0.0

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

# Try to get HitBox - this might fail if the node doesn't exist
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

	# Setup walking audio
	setup_walking_audio()
	
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

	# Setup respawn image overlay
	setup_respawn_overlay()

func setup_walking_audio():
	# Create AudioStreamPlayer2D if it doesn't exist
	if not has_node("WalkingAudio"):
		walking_audio = AudioStreamPlayer2D.new()
		walking_audio.name = "WalkingAudio"
		add_child(walking_audio)
	
	# Configure the audio player
	if walking_audio:
		walking_audio.stream = walking_sound
		walking_audio.volume_db = walking_volume
		walking_audio.autoplay = false
		walking_audio.bus = "SFX"  # Optional: use SFX bus if you have one

func setup_respawn_overlay():
	# Create the overlay control node
	respawn_overlay = Control.new()
	respawn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	respawn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	respawn_overlay.visible = false
	
	# Create the image display
	respawn_image_rect = TextureRect.new()
	respawn_image_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	respawn_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set initial size (adjustable via exported variable)
	respawn_image_rect.custom_minimum_size = respawn_image_size
	
	# Add to the overlay
	respawn_overlay.add_child(respawn_image_rect)
	
	# Add overlay to the camera's CanvasLayer for screen-space display
	if has_node("Camera2D/CanvasLayer"):
		$Camera2D/CanvasLayer.add_child(respawn_overlay)
	else:
		# Fallback: add to the player node
		add_child(respawn_overlay)

func _physics_process(delta):
	if is_dead and current_state != State.DYING:
		return  # Don't process movement when dead (unless playing death animation)
	
	# Handle coyote time
	handle_coyote_time(delta)
	
	if not is_on_floor() and current_state != State.DYING:
		velocity.y += gravity * delta
	
	# Store previous state before updating
	previous_state = current_state
	
	handle_input()
	update_movement(delta)
	handle_walking_sound()  # Handle walking sound based on state changes
	play_animation()
	move_and_slide()

func handle_walking_sound():
	# Only play walking sound when running on the ground
	if current_state == State.RUNNING and is_on_floor():
		# Start playing if not already playing
		if not walking_audio.playing:
			play_walking_sound()
	else:
		# Stop playing if currently playing
		if walking_audio.playing:
			walking_audio.stop()

func play_walking_sound():
	if walking_sound and walking_audio:
		# Add slight pitch variation for more natural sound
		walking_audio.pitch_scale = randf_range(walking_pitch_min, walking_pitch_max)
		walking_audio.play()

func handle_coyote_time(delta):
	# Track if player was on floor last frame
	var on_floor_now = is_on_floor()
	
	if on_floor_now:
		# Reset coyote timer when on ground
		coyote_timer = coyote_time
		was_on_floor = true
	elif was_on_floor and not on_floor_now:
		# Just left the ground, keep the coyote timer active
		was_on_floor = false
		# Don't reset timer here - let it count down from the current value
	else:
		# In air, count down coyote timer
		if coyote_timer > 0.0:
			coyote_timer -= delta

func can_coyote_jump() -> bool:
	# Can coyote jump if timer is still active, not on floor, and haven't jumped yet
	return coyote_timer > 0.0 and not is_on_floor() and current_state == State.FALLING
	
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
			if Input.is_action_just_pressed(input_jump):
				if is_on_floor():
					# If somehow back on floor, do regular jump
					jump()
				elif can_double_jump and has_double_jumped == false:
					double_jump()
				elif can_coyote_jump():
					coyote_jump()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
				# Reset jump abilities when landing
				can_double_jump = false
				has_double_jumped = false
				
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
	coyote_timer = 0.0  # Use up coyote time when jumping

func coyote_jump():
	# Same as regular jump but doesn't grant double jump ability
	velocity.y = jump_velocity
	current_state = State.JUMPING
	coyote_timer = 0.0  # Use up coyote time
	# Don't set can_double_jump = true for coyote jump
	print("Coyote jump activated! Timer was: ", coyote_timer)

func double_jump():
	velocity.y = jump_velocity * 0.8
	has_double_jumped = true
	can_double_jump = false
	coyote_timer = 0.0  # Use up coyote time if any remains

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
	
	# Stop walking sound when dying
	if walking_audio.playing:
		walking_audio.stop()
	
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
	
	# Reset jump and coyote states
	can_double_jump = false
	has_double_jumped = false
	coyote_timer = 0.0
	was_on_floor = false
	
	# Reset collision states
	normal_collision.disabled = false
	crouch_collision.disabled = true
	
	# Show respawn image
	show_respawn_image()

# Optional: Function to set new respawn points (call this at checkpoints)
func set_respawn_point(new_position: Vector2):
	respawn_position = new_position

# Soul management methods
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

# Optional: Method to get a soul display string for UI
func get_soul_display() -> String:
	return "Souls: " + str(souls)


# Example of how to connect soul pickup to your existing InteractableItem
# In your InteractableItem.gd interact() function, you can add:
func interact():
	print("Picked up: ", souls)
	
	# Add soul to player instead of just score
	
	queue_free()  # Remove the item

# Show respawn image overlay
func show_respawn_image():
	if respawn_image and respawn_overlay and respawn_image_rect:
		# Set the image texture
		respawn_image_rect.texture = respawn_image
		
		# Show the overlay
		respawn_overlay.visible = true
		
		# Create tween for fade in/out effect
		var image_tween = create_tween()
		
		# Start fully visible
		respawn_overlay.modulate.a = 1.0
		
		# Wait for most of the duration, then fade out
		image_tween.tween_interval(respawn_image_duration * 0.8)
		image_tween.tween_property(respawn_overlay, "modulate:a", 0.0, respawn_image_duration * 0.2)
		
		# Hide the overlay when done
		await image_tween.finished
		respawn_overlay.visible = false
		respawn_overlay.modulate.a = 1.0  # Reset alpha for next time
