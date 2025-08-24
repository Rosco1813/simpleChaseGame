extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
@export var spawn_radius: float = 300.0
@export var player_path: NodePath
@export var spawn_margin: float = 24.0 # keep spawned enemies inside walls by this padding

var _time_accum := 0.0
var _player: Node2D
var _world_rect: Rect2

const MAX_SPAWN_ATTEMPTS := 8

func _ready():
	if player_path != NodePath():
		_player = get_node(player_path)
	randomize()
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect

func _process(delta: float) -> void:
	_time_accum += delta
	if _time_accum >= spawn_interval:
		_time_accum = 0.0
		_spawn_enemy_if_needed()

func _spawn_enemy_if_needed():
	if enemy_scene == null:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	var enemy = enemy_scene.instantiate()
	var center = _player.global_position if is_instance_valid(_player) else Vector2.ZERO
	enemy.position = _pick_spawn_position(center)
	if is_instance_valid(_player):
		# Check that the instantiated enemy actually has the exported property before setting
		var has_target_path := false
		for prop in enemy.get_property_list():
			if prop.name == "target_path":
				has_target_path = true
				break
		if has_target_path:
			enemy.set("target_path", _player.get_path())
	add_child(enemy)

func _pick_spawn_position(center: Vector2) -> Vector2:
	# Ensure we have a world rect; if not, fallback to default that matches walls
	var rect = _world_rect
	if rect.size == Vector2.ZERO:
		rect = Rect2(Vector2(-400,-300), Vector2(800,600))
	var min_x = rect.position.x + spawn_margin
	var max_x = rect.position.x + rect.size.x - spawn_margin
	var min_y = rect.position.y + spawn_margin
	var max_y = rect.position.y + rect.size.y - spawn_margin
	var pos := center
	for i in MAX_SPAWN_ATTEMPTS:
		var angle = randf() * TAU
		var r = sqrt(randf()) * spawn_radius
		var candidate = center + Vector2(cos(angle), sin(angle)) * r
		candidate.x = clamp(candidate.x, min_x, max_x)
		candidate.y = clamp(candidate.y, min_y, max_y)
		# Accept if strictly inside (with 0.5px slack) and not intersecting walls
		if candidate.x > min_x + 0.5 and candidate.x < max_x - 0.5 and candidate.y > min_y + 0.5 and candidate.y < max_y - 0.5:
			return candidate
	# Fallback center (already clamped)
	pos.x = clamp(center.x, min_x, max_x)
	pos.y = clamp(center.y, min_y, max_y)
	return pos
