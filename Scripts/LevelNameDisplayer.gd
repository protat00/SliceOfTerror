# LevelNameDisplay.gd
# Attach this to a CanvasLayer node in your scene
extends CanvasLayer

@onready var background = $Background
@onready var level_label = $LevelLabel
@onready var typewriter_timer = $TypewriterTimer
@onready var audio_player = $AudioStreamPlayer

var current_text = ""
var display_index = 0
var typing_speed = 0.05  # Seconds between each character
var is_displaying = false

func _ready():
	print("LevelNameDisplay script is running!")
	print("Node path: ", get_path())
	
	# Initially hide everything
	background.modulate.a = 0
	level_label.text = ""
	level_label.modulate.a = 0
	
	# Connect the timer
	typewriter_timer.connect("timeout", _on_typewriter_timer_timeout)
	
	# Test the display after 2 seconds
	await get_tree().create_timer(2.0).timeout
	print("Testing display...")
	show_level_name("TEST LEVEL")

func show_level_name(level_name: String):
	print("show_level_name called with: ", level_name)
	
	if is_displaying:
		print("Already displaying, returning")
		return
	
	print("Starting display sequence...")
	is_displaying = true
	current_text = level_name
	display_index = 0
	level_label.text = ""
	
	# Make sure nodes exist
	if not background:
		print("ERROR: Background node not found!")
		return
	if not level_label:
		print("ERROR: LevelLabel node not found!")
		return
	
	print("Fading in background and label...")
	# Fade in background
	var tween = create_tween()
	tween.parallel().tween_property(background, "modulate:a", 0.8, 0.5)
	tween.parallel().tween_property(level_label, "modulate:a", 1.0, 0.5)
	
	# Wait a bit then start typewriter effect
	await tween.finished
	print("Starting typewriter effect...")
	typewriter_timer.start(typing_speed)

func _on_typewriter_timer_timeout():
	if display_index < current_text.length():
		# Add next character
		level_label.text += current_text[display_index]
		display_index += 1
		
		# Play typing sound
		if audio_player.stream:
			audio_player.play()
		
		# Continue timer
		typewriter_timer.start(typing_speed)
	else:
		# Finished typing, wait then fade out
		typewriter_timer.stop()
		await get_tree().create_timer(2.0).timeout  # Display for 2 seconds
		hide_display()

func hide_display():
	var tween = create_tween()
	tween.parallel().tween_property(background, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(level_label, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	level_label.text = ""
	is_displaying = false

# Optional: Skip typewriter effect if player presses a key
func _input(event):
	if is_displaying and event.is_pressed():
		if display_index < current_text.length():
			# Skip to end of typing
			level_label.text = current_text
			display_index = current_text.length()
			typewriter_timer.stop()
			await get_tree().create_timer(1.0).timeout
			hide_display()
