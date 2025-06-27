extends Control

func _on_back_button_pressed():
	# Go back to main menu - the music will resume automatically
	get_tree().change_scene_to_file("res://path/to/your/main_menu.tscn")
