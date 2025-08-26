extends Node2D

func _ready():
	fade_in()

func fade_in():
	# Create fade overlay for fade-in effect
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.modulate.a = 1.0  # Start fully black
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(fade_overlay)
	
	# Fade in from black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Clean up
	canvas_layer.queue_free()
