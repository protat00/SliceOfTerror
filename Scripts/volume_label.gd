# Attach to a Label node that's a sibling of the HSlider
extends Label

@export var volume_slider: HSlider

func _ready():
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		_on_volume_changed(volume_slider.value)

func _on_volume_changed(value: float):
	text = str(int(value * 100)) + "%"
