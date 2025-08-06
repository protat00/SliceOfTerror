# Attach this script to an HSlider node
extends HSlider

func _ready():
	# Set slider properties
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	
	# Load saved volume or default to 50%
	load_volume_setting()
	
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
	
	# Save the volume setting
	save_volume_setting(new_value)
	
	print("Slider value: ", new_value, " Volume dB: ", volume_db)

func save_volume_setting(volume_value: float):
	var config = ConfigFile.new()
	config.set_value("audio", "volume", volume_value)
	config.save("user://settings.cfg")

func load_volume_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		value = config.get_value("audio", "volume", 0.5)  # Default to 50% if not found
	else:
		value = 0.5  # Default volume
