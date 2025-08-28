extends Control

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var settings_panel: Control = $SettingsPanel
@onready var back_button: Button = $SettingsPanel/VBox/BackButton

# Debug controls (optional nodes, will be null if not present yet)
@onready var dbg_invincible: CheckButton = $SettingsPanel/VBox/Invincible if has_node("SettingsPanel/VBox/Invincible") else null
@onready var dbg_freeze: CheckButton = $SettingsPanel/VBox/FreezeEnemies if has_node("SettingsPanel/VBox/FreezeEnemies") else null
@onready var dbg_skip_wave: Button = $SettingsPanel/VBox/SkipWave if has_node("SettingsPanel/VBox/SkipWave") else null
@onready var dbg_kill_all: Button = $SettingsPanel/VBox/KillAll if has_node("SettingsPanel/VBox/KillAll") else null
@onready var dbg_player_speed: HSlider = $SettingsPanel/VBox/PlayerSpeed if has_node("SettingsPanel/VBox/PlayerSpeed") else null
@onready var dbg_player_speed_val: Label = $SettingsPanel/VBox/PlayerSpeedValue if has_node("SettingsPanel/VBox/PlayerSpeedValue") else null
@onready var dbg_enemy_speed: HSlider = $SettingsPanel/VBox/EnemySpeed if has_node("SettingsPanel/VBox/EnemySpeed") else null
@onready var dbg_enemy_speed_val: Label = $SettingsPanel/VBox/EnemySpeedValue if has_node("SettingsPanel/VBox/EnemySpeedValue") else null
@onready var dbg_time_scale: HSlider = $SettingsPanel/VBox/TimeScale if has_node("SettingsPanel/VBox/TimeScale") else null
@onready var dbg_time_scale_val: Label = $SettingsPanel/VBox/TimeScaleValue if has_node("SettingsPanel/VBox/TimeScaleValue") else null
@onready var dbg_show_collisions: CheckButton = $SettingsPanel/VBox/ShowCollisions if has_node("SettingsPanel/VBox/ShowCollisions") else null

func _ready():
    # Allow this menu to process while game is paused
    if has_method("set_process_mode"):
        set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)
    visible = false
    settings_panel.visible = false
    if resume_button:
        resume_button.pressed.connect(_on_resume)
    if settings_button:
        settings_button.pressed.connect(_on_settings)
    if quit_button:
        quit_button.pressed.connect(_on_quit)
    if back_button:
        back_button.pressed.connect(_on_back_from_settings)
    else:
        # Fallback search if structure changes
        var candidate = settings_panel.find_child("BackButton", true, false)
        if candidate and candidate is Button:
            back_button = candidate
            back_button.pressed.connect(_on_back_from_settings)
    _wire_debug_controls()

func show_menu():
    settings_panel.visible = false
    visible = true

func hide_menu():
    visible = false
    settings_panel.visible = false

func _on_resume():
    hide_menu()
    var gm = _find_game_manager()
    if gm and gm.has_method("resume_game"):
        gm.resume_game()

func _on_settings():
    settings_panel.visible = true

func _on_back_from_settings():
    settings_panel.visible = false

func _on_quit():
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func _find_game_manager():
    # GameManager is script on Main root
    return get_tree().current_scene

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("pause"):
        _on_resume()
        get_viewport().set_input_as_handled()

func _wire_debug_controls():
    if typeof(DebugSettings) == TYPE_NIL:
        return
    if dbg_invincible:
        dbg_invincible.toggled.connect(func(v): DebugSettings.invincible = v)
    if dbg_freeze:
        dbg_freeze.toggled.connect(func(v): DebugSettings.freeze_enemies = v)
    if dbg_player_speed:
        dbg_player_speed.value_changed.connect(func(v):
            DebugSettings.player_speed_mult = v
            if dbg_player_speed_val: dbg_player_speed_val.text = "Player Speed x%.2f" % v)
        if dbg_player_speed_val: dbg_player_speed_val.text = "Player Speed x%.2f" % dbg_player_speed.value
    if dbg_enemy_speed:
        dbg_enemy_speed.value_changed.connect(func(v):
            DebugSettings.enemy_speed_mult = v
            if dbg_enemy_speed_val: dbg_enemy_speed_val.text = "Enemy Speed x%.2f" % v)
        if dbg_enemy_speed_val: dbg_enemy_speed_val.text = "Enemy Speed x%.2f" % dbg_enemy_speed.value
    if dbg_time_scale:
        dbg_time_scale.value_changed.connect(func(v):
            DebugSettings.time_scale = v
            if dbg_time_scale_val: dbg_time_scale_val.text = "Time Scale x%.2f" % v)
        if dbg_time_scale_val: dbg_time_scale_val.text = "Time Scale x%.2f" % dbg_time_scale.value
    if dbg_show_collisions:
        dbg_show_collisions.toggled.connect(func(v): DebugSettings.show_collision_shapes = v)
    if dbg_skip_wave:
        dbg_skip_wave.pressed.connect(func():
            var gm = _find_game_manager()
            if gm and gm.has_method("debug_skip_wave"):
                gm.debug_skip_wave())
    if dbg_kill_all:
        dbg_kill_all.pressed.connect(func():
            var gm = _find_game_manager()
            if gm and gm.has_method("debug_kill_all_enemies"):
                gm.debug_kill_all_enemies())
