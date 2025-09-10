# LevelTrigger.gd
# Attach this to your Area2D nodes that should trigger the level name
extends Area2D

@export var level_name: String = "Level Name"
@export var trigger_once: bool = false  # Set to false for testing

var has_triggered = false

func _ready():
	connect("body_entered", _on_body_entered)
	print("LevelTrigger ready")

func _on_body_entered(body):
	print("Body entered: ", body.name)
	
	if body.is_in_group("player") or body.name == "Player" or body.name.to_lower().contains("player"):
		print("Player detected!")
		
		if trigger_once and has_triggered:
			print("Already triggered, skipping")
			return
		
		has_triggered = true
		
		# Simple approach - print the scene tree first
		print("=== SCENE TREE ===")
		print_simple_tree(get_tree().current_scene, 0)
		print("=== END TREE ===")
		
		# Try to find the display node
		var display = find_display_node(get_tree().current_scene)
		if display:
			print("Found display node at: ", display.get_path())
			display.show_level_name(level_name)
		else:
			print("No display node found!")

func find_display_node(node: Node) -> Node:
	if node.has_method("show_level_name"):
		return node
	
	for child in node.get_children():
		var result = find_display_node(child)
		if result:
			return result
	
	return null

func print_simple_tree(node: Node, depth: int):
	var spaces = ""
	for i in range(depth):
		spaces += "  "
	
	print(spaces + node.name)
	
	for child in node.get_children():
		print_simple_tree(child, depth + 1)
