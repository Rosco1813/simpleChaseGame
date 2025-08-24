extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
    # Connect start button
    if start_button:
        start_button.pressed.connect(_on_start_pressed)

    # Hide or wire quit button depending on platform (skip in web/editor)
    if quit_button:
        if OS.has_feature("web"):
            quit_button.visible = false
        else:
            quit_button.pressed.connect(func(): get_tree().quit())

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/Main.tscn")
