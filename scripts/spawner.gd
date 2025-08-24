extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
@export var spawn_radius: float = 300.0
@export var player_path: NodePath
@export var spawn_margin: float = 24.0 # keep spawned enemies inside walls by this padding
@export var difficulty_ramp_interval: float = 10.0 # seconds between difficulty bumps
@export var spawn_interval_min: float = 0.4
@export var spawn_interval_decrease: float = 0.1 # amount to reduce each ramp
@export var enemy_speed_increase: float = 15.0
@export var max_enemies_increase: int = 2
@export var wave_mode: bool = true # when true, spawning is controlled externally per wave

var _time_accum := 0.0
var _player: Node2D
var _world_rect: Rect2
var _time_since_ramp := 0.0
var _wave_number := 0
var _wave_spawned := 0

const MAX_SPAWN_ATTEMPTS := 8

func _ready():
	if player_path != NodePath():
		_player = get_node(player_path)
	randomize()
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect

func _process(delta: float) -> void:
	if wave_mode:
		return # wave-controlled; no continuous spawning
	_time_accum += delta
	_time_since_ramp += delta
	if difficulty_ramp_interval > 0 and _time_since_ramp >= difficulty_ramp_interval:
		_time_since_ramp = 0.0
		spawn_interval = max(spawn_interval_min, spawn_interval - spawn_interval_decrease)
		max_enemies += max_enemies_increase
		# Increase speed on existing enemies
		for e in get_tree().get_nodes_in_group("enemy"):
			var has_speed := false
			for prop in e.get_property_list():
				if prop.name == "speed":
					has_speed = true
					break
			if has_speed:
				e.speed += enemy_speed_increase
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

func start_wave(wave_number: int, enemy_count: int, color: Color) -> int:
	if enemy_scene == null:
		return 0
	_wave_number = wave_number
	_wave_spawned = 0
	var existing = get_tree().get_nodes_in_group("enemy").size()
	var space = max_enemies - existing
	if space <= 0:
		return 0
	var to_spawn = min(enemy_count, space)
	for i in range(to_spawn):
		var enemy = enemy_scene.instantiate()
		var center = _player.global_position if is_instance_valid(_player) else Vector2.ZERO
		enemy.position = _pick_spawn_position(center)
		# Assign target
		if is_instance_valid(_player):
			var has_target_path := false
			for prop in enemy.get_property_list():
				if prop.name == "target_path":
					has_target_path = true
					break
			if has_target_path:
				enemy.set("target_path", _player.get_path())
		# Color application
		_apply_wave_color(enemy, color)
		add_child(enemy)
		_wave_spawned += 1
	return _wave_spawned

func _apply_wave_color(enemy: Node, color: Color) -> void:
	if enemy.has_node("Body"):
		var body = enemy.get_node("Body")
		if body is Polygon2D:
			body.color = color

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
