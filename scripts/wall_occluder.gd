extends Node2D

@export_enum("TOP","BOTTOM","LEFT","RIGHT") var orientation: String = "TOP"
@export var base_line: float = 0.0 # World-space reference line (bottom edge for TOP wall, top edge for BOTTOM wall, left edge for LEFT, right edge for RIGHT)
@export var min_alpha: float = 0.35
@export var fade_enabled: bool = true

var _player: Node2D

func _ready():
    _player = get_tree().get_first_node_in_group("player")
    set_process(fade_enabled)

func _process(_delta: float) -> void:
    if not fade_enabled:
        return
    if not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
        if not _player:
            return
    var a := 1.0
    match orientation:
        "TOP":
            # Player above (smaller y) is behind the wall top section
            if _player.global_position.y < base_line:
                a = min_alpha
        "BOTTOM":
            if _player.global_position.y > base_line:
                a = min_alpha
        "LEFT":
            if _player.global_position.x < base_line:
                a = min_alpha
        "RIGHT":
            if _player.global_position.x > base_line:
                a = min_alpha
    modulate.a = a
