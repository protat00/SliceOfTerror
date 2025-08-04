# Attach this script to an HSlider node
extends HSlider

func _ready():
	# Set slider properties
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value = 0.5  # Start at 50% volume
	
	# Connect the slider to the function
	value_changed.connect(_on_volume_changed)
	
	# Set initial volume
	_on_volume_changed(value)

func _on_volume_changed(new_value: float):
	# Convert 0-1 range to decibels (-80 to 0)
	var volume_db: float
	if new_value <= 0.0:
		volume_db = -80.0  # Effectively mute
	else:
		# Convert linear to logarithmic (decibels)
		volume_db = 20.0 * log(new_value) / log(10.0)
	
	# Set the Master bus volume
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, volume_db)
	
	print("Slider value: ", new_value, " Volume dB: ", volume_db)
