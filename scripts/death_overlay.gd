extends Control

@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var stats_label: Label = $CenterContainer/VBoxContainer/Stats

func _ready() -> void:
	# pause_mode already set on the node in the scene file (value 2 = PROCESS during pause)
	# Switch to process while paused using Godot 4 process_mode API.
	if has_method("set_process_mode"):
		set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	visible = false

func show_overlay(kills: int, wave: int, time_survived: float) -> void:
	if title_label:
		title_label.text = "You Died"
	if stats_label:
		stats_label.text = "Kills: %d\nWave Reached: %d\nTime: %.1fs" % [kills, wave, time_survived]
	visible = true

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
