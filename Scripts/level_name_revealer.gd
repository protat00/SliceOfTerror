# LevelNameRevealer.gd
# A standalone system for dramatic level name reveals with background fade
extends Node

@export_group("Level Settings")
@export var level_name: String = "The Attic"
@export var auto_detect_from_scene: bool = true

@export_group("Animation Settings") 
@export var fade_in_duration: float = 1.0
@export var hold_duration: float = 2.5
@export var fade_out_duration: float = 1.0
@export var background_fade_alpha: float = 0.3  # How dark the background gets (0.0 = black, 1.0 = no fade)

@export_group("Text Style")
@export var text_font: FontFile
@export var text_size: int = 48
@export var text_color: Color = Color.WHITE
@export var text_outline_size: int = 4
@export var text_outline_color: Color = Color.BLACK

@export_group("Effects")
@export var use_typewriter_effect: bool = false
@export var typewriter_speed: float = 0.05  # Time between each character
@export var use_glow_effect: bool = true
@export var play_reveal_sound: bool = true
@export var reveal_sound: AudioStream

var is_playing: bool = false
var audio_player: AudioStreamPlayer

func _ready():
	# Create audio player for sound effects
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

# Main function to trigger the level name reveal
func reveal_level_name(custom_level_name: String = ""):
	if is_playing:
		return  # Prevent overlapping reveals
	
	is_playing = true
	
	var display_name = custom_level_name
	if display_name.is_empty():
		display_name = get_level_name()
	
	await create_level_reveal_overlay(display_name)
	is_playing = false

func get_level_name() -> String:
	if not level_name.is_empty():
		return level_name
	
	if auto_detect_from_scene:
		var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
		return scene_name.replace("_", " ").capitalize()
	
	return "Unknown Level"

func create_level_reveal_overlay(display_name: String):
	# Create full-screen overlay
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.name = "LevelRevealOverlay"
	overlay.z_index = 1000
	
	# Create background fade (semi-transparent black)
	var background_fade = ColorRect.new()
	background_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_fade.color = Color(0, 0, 0, 0)  # Start transparent
	background_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create the level name label
	var level_label = Label.new()
	level_label.text = display_name
	level_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Apply text styling
	if text_font:
		level_label.add_theme_font_override("font", text_font)
	level_label.add_theme_font_size_override("font_size", text_size)
	level_label.add_theme_color_override("font_color", text_color)
	
	# Add outline for better readability
	if text_outline_size > 0:
		level_label.add_theme_constant_override("outline_size", text_outline_size)
		level_label.add_theme_color_override("font_outline_color", text_outline_color)
	
	# Add glow effect if enabled
	if use_glow_effect:
		level_label.add_theme_color_override("font_shadow_color", Color(text_color.r, text_color.g, text_color.b, 0.5))
		level_label.add_theme_constant_override("shadow_offset_x", 0)
		level_label.add_theme_constant_override("shadow_offset_y", 0)
		level_label.add_theme_constant_override("shadow_outline_size", 8)
	
	# Start with text invisible
	level_label.modulate.a = 0.0
	
	# Assemble the overlay
	overlay.add_child(background_fade)
	overlay.add_child(level_label)
	
	# Add to scene (find the best parent)
	var target_parent = find_best_parent()
	target_parent.add_child(overlay)
	
	# Play reveal sound
	if play_reveal_sound and reveal_sound:
		audio_player.stream = reveal_sound
		audio_player.play()
	
	# Start the animation sequence
	await animate_level_reveal(overlay, background_fade, level_label, display_name)

func find_best_parent() -> Node:
	# Try to find a UI layer, otherwise use current scene
	var canvas_layer = get_tree().get_first_node_in_group("ui_layer")
	if canvas_layer:
		return canvas_layer
	
	# Look for existing CanvasLayer
	var existing_canvas = get_tree().current_scene.get_children().filter(func(child): return child is CanvasLayer)
	if existing_canvas.size() > 0:
		return existing_canvas[0]
	
	# Create our own CanvasLayer for proper layering
	var new_canvas = CanvasLayer.new()
	new_canvas.layer = 100
	get_tree().current_scene.add_child(new_canvas)
	return new_canvas

func animate_level_reveal(overlay: Control, background_fade: ColorRect, level_label: Label, display_name: String):
	# Phase 1: Fade in background and text
	var fade_in_tween = create_tween()
	fade_in_tween.set_parallel(true)
	
	# Fade background to semi-transparent
	fade_in_tween.tween_property(background_fade, "color:a", 1.0 - background_fade_alpha, fade_in_duration)
	
	# Handle typewriter effect or simple fade for text
	if use_typewriter_effect:
		await animate_typewriter_text(level_label, display_name)
	else:
		fade_in_tween.tween_property(level_label, "modulate:a", 1.0, fade_in_duration)
	
	await fade_in_tween.finished
	
	# Phase 2: Hold the reveal
	await get_tree().create_timer(hold_duration).timeout
	
	# Phase 3: Fade out everything
	var fade_out_tween = create_tween()
	fade_out_tween.set_parallel(true)
	
	fade_out_tween.tween_property(background_fade, "color:a", 0.0, fade_out_duration)
	fade_out_tween.tween_property(level_label, "modulate:a", 0.0, fade_out_duration)
	
	await fade_out_tween.finished
	
	# Clean up
	overlay.queue_free()

func animate_typewriter_text(label: Label, full_text: String):
	label.text = ""
	label.modulate.a = 1.0  # Make label visible but with no text
	
	for i in range(full_text.length()):
		label.text = full_text.substr(0, i + 1)
		await get_tree().create_timer(typewriter_speed).timeout

# Convenience functions to trigger reveals
func reveal_on_checkpoint_reached():
	reveal_level_name()

func reveal_custom_level(custom_name: String):
	reveal_level_name(custom_name)

# Call this from anywhere in your game
static func show_level_reveal(level_name: String = ""):
	var revealer = Engine.get_singleton("LevelNameRevealer")
	if not revealer:
		# Find it in the scene tree
		revealer = Engine.get_main_loop().current_scene.get_node_or_null("LevelNameRevealer")
	
	if revealer:
		revealer.reveal_level_name(level_name)
