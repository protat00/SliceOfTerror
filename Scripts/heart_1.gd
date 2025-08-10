# Heart.gd
# Attach this script to each individual heart AnimatedSprite2D

extends AnimatedSprite2D

var is_active: bool = true

func _ready():
	# Start with idle/full heart animation
	play("idle")
	animation_finished.connect(_on_animation_finished)

# Call this to lose this heart
func lose_heart():
	if is_active:
		is_active = false
		play("death")  # Replace with your actual death animation name

# Called when any animation finishes
func _on_animation_finished():
	if animation == "death":
		# Hide the heart or switch to empty state
		visible = false
		# Or play an empty heart animation:
		# play("empty")
		# visible = true

# Restore this heart
func restore_heart():
	if not is_active:
		is_active = true
		visible = true
		play("idle")

# Check if this heart is still active
func is_heart_active() -> bool:
	return is_active
