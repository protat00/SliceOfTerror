# Attach to a Label node
extends Label

func _ready():
	# Get the slider by its path - adjust this path to match your scene structure
	var volume_slider = get_node("../VolumeSlider")  # or whatever the actual path is
	
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		_on_volume_changed(volume_slider.value)
	else:
		print("Could not find volume slider!")

func _on_volume_changed(value: float):
	text = str(int(value * 100)) + "%"
