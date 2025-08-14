# DeathScreen.gd
# Attach this to your DeathScreen scene root node
extends Control

@export var main_menu_scene_path: String = "res://Scenes/Title_screen.tscn"  # Based on your file structure
@export var gameplay_scene_path: String = "res://Scenes/game.tscn"  # Based on your file structure
@export var show_stats: bool = true

# Get references to your existing UI elements
@onready var main_menu_button = get_node_or_null("VBoxContainer/MainMenu")
@onready var restart_button = get_node_or_null("VBoxContainer/RestartButton") 
@onready var quit_button = get_node_or_null("VBoxContainer/QuitButton")

# Optional stat display elements (create these if you want stats)
@onready var deaths_label = get_node_or_null("StatsContainer/DeathsLabel")
@onready var time_label = get_node_or_null("StatsContainer/TimeLabel")
@onready var souls_label = get_node_or_null("StatsContainer/SoulsLabel")

func _ready():
	# Connect existing buttons
	connect_buttons()
	
	# Display stats
	if show_stats:
		display_death_stats()
	
	# Fade in from the black screen (LifeManager handles the fade)
	LifeManager.fade_in_new_scene()
	
	# Optional: Play death screen music/sound
	# play_death_screen_audio()

func connect_buttons():
	# Connect to your existing button scripts or replace their functionality
	if restart_button and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func display_death_stats():
	var stats = LifeManager.get_death_stats()
	
	if deaths_label:
		deaths_label.text = "Deaths: " + str(stats.total_deaths)
	
	if time_label:
		var minutes = int(stats.session_time) / 60
		var seconds = int(stats.session_time) % 60
		time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	if souls_label:
		souls_label.text = "Souls: " + str(stats.souls_collected)
	
	# Print stats to console for debugging
	print("=== DEATH STATS ===")
	print("Total Deaths: ", stats.total_deaths)
	print("Deaths This Level: ", stats.deaths_this_level)
	print("Session Time: ", "%.1f" % stats.session_time, " seconds")
	print("Souls Collected: ", stats.souls_collected)
	print("Levels Completed: ", stats.levels_completed)
	print("==================")

func _on_restart_pressed():
	print("Restarting game...")
	# Use LifeManager's fade transition
	LifeManager.start_new_game(gameplay_scene_path)

func _on_main_menu_pressed():
	print("Going to main menu...")
	go_to_main_menu()

func _on_quit_pressed():
	print("Quitting game...")
	get_tree().quit()

func go_to_main_menu():
	if ResourceLoader.exists(main_menu_scene_path):
		# Fade out and go to menu
		await LifeManager.fade_to_black()
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		print("ERROR: Main menu scene not found at: ", main_menu_scene_path)

# Handle keyboard shortcuts
func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_on_restart_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()

# Optional: Add screen shake effect
func add_screen_shake():
	var tween = create_tween()
	var original_position = position
	
	for i in range(10):
		var shake_offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(self, "position", original_position + shake_offset, 0.05)
	
	tween.tween_property(self, "position", original_position, 0.1)

# Optional: Play death screen audio
func play_death_screen_audio():
	# Add your death screen music/sound here
	pass
