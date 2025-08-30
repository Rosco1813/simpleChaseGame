extends Camera2D

@export var target_path: NodePath
@export var use_player_group: bool = true
@export var enable_smoothing: bool = true
@export var smooth_speed: float = 8.0
@export var clamp_to_world: bool = true
@export var extra_margin: Vector2 = Vector2(0, 0)
@export var debug: bool = false

var _target: Node2D
var _world_rect: Rect2
var _initialized: bool = false

func _ready():
	make_current()
	_resolve_target()
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect
	var gm = get_tree().get_first_node_in_group("game")
	if gm and gm.has_signal("world_rect_changed"):
		if not gm.is_connected("world_rect_changed", Callable(self, "_on_world_rect_changed")):
			gm.world_rect_changed.connect(_on_world_rect_changed)
	if is_instance_valid(_target):
		position = _clamped_target_position(_target.global_position)
	_initialized = true
	if debug:
		print_debug("[CameraFollow] ready; target=", _target)

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
		if debug and is_instance_valid(_target):
			print_debug("[CameraFollow] acquired target late: ", _target)
	if not is_instance_valid(_target):
		return
	var desired = _clamped_target_position(_target.global_position)
	if enable_smoothing:
		var t = 1.0 - pow(0.001, delta * smooth_speed)
		position = position.lerp(desired, clamp(t, 0.0, 1.0))
	else:
		position = desired

func _resolve_target():
	if target_path != NodePath():
		_target = get_node_or_null(target_path)
	elif use_player_group:
		_target = get_tree().get_first_node_in_group("player")

func _clamped_target_position(pos: Vector2) -> Vector2:
	if not clamp_to_world or _world_rect.size == Vector2.ZERO:
		return pos
	var vp = get_viewport_rect().size
	var z = zoom
	var half = (vp * z) * 0.5
	var min_x = _world_rect.position.x + half.x + extra_margin.x
	var max_x = _world_rect.position.x + _world_rect.size.x - half.x - extra_margin.x
	var min_y = _world_rect.position.y + half.y + extra_margin.y
	var max_y = _world_rect.position.y + _world_rect.size.y - half.y - extra_margin.y
	return Vector2(
		clamp(pos.x, min_x, max_x),
		clamp(pos.y, min_y, max_y)
	)

func _on_world_rect_changed(new_rect: Rect2):
	_world_rect = new_rect
	if debug:
		print_debug("[CameraFollow] world rect updated: ", new_rect)
