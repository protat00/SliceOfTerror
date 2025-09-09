extends Area2D

@export var level_name: String = "The Attic"
var has_been_triggered: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

# In your Area2D script
func _on_body_entered(body):
	print("Something entered: ", body.name)
	print("Is in Player group: ", body.is_in_group("Player"))
	print("Has been triggered: ", has_triggered)
	
	if body.is_in_group("Player") and not has_triggered:
		print("Triggering level reveal!")
		has_triggered = true
		var revealer = get_node("../LevelNameRevealer")  # Adjust path
		if revealer:
			print("Found revealer, calling reveal")
			revealer.reveal_level_name(level_name)
		else:
			print("Could not find revealer!")
