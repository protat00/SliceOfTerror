extends Button





func _on_pressed() -> void:
	print(get_tree())
	get_tree().change_scene_to_file("res://Scenes/Title_screen.tscn")
