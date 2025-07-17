extends Control

@onready var main = get_tree().current_scene


func _on_back_button_pressed():
	# Music continues playing when returning to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_resume_pressed() -> void:
	hide()
	Engine.time_scale = 1
	


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Title_screen.tscn")
