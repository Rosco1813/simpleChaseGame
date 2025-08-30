extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
@export var spawn_radius: float = 300.0
@export var player_path: NodePath
@export var spawn_margin: float = 24.0 # keep spawned enemies inside walls by this padding
@export var spawn_clearance: float = 28.0 # minimum radius clear of walls/player/other enemies
@export var wall_thickness: float = 32.0 # assumed wall collision thickness (tile size)
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

# Doorway geometry (populated at runtime). Fallback constants retained.
var _door_left_x: float = 400.0
var _door_right_x: float = 420.0
var _door_center_y: float = 0.0
var _door_half_height: float = 110.0

const MAX_SPAWN_ATTEMPTS := 8
const PHYSICS_CHECK_SHRINK := 2.0 # shrink shape slightly to be conservative

func _ready():
	if player_path != NodePath():
		_player = get_node(player_path)
	randomize()
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect
	_init_doorway_params()

func _init_doorway_params():
	# Probe scene for a WallMap (TileMap) carrying doorway exports to refine vertical gap size.
	var maps = get_tree().get_nodes_in_group("wall_maps") # optional if user groups them
	if maps.is_empty():
		# Fallback: scan all TileMaps under current scene for property doorway_half_height
		maps = []
		for n in get_tree().current_scene.get_children():
			if n is TileMap and "doorway_half_height" in n:
				maps.append(n)
			# Also descend one level (common structure)
			for c in n.get_children():
				if c is TileMap and "doorway_half_height" in c:
					maps.append(c)
	if maps.size() > 0:
		var m = maps[0]
		if "doorway_half_height" in m:
			_door_half_height = m.doorway_half_height
		if "doorway_center" in m:
			_door_center_y = m.doorway_center.y
	# door_left/right remain defaults unless we can derive from room_origin/size
	if maps.size() > 0:
		var m2 = maps[0]
		if "room_origin" in m2 and "room_size" in m2:
			_door_left_x = m2.room_origin.x + m2.room_size.x
	# Attempt to locate second room to refine right edge (left edge of room2)
	for node in maps:
		if "room_origin" in node and node.room_origin.x > _door_left_x:
			_door_right_x = node.room_origin.x
			break
	# Sanity: ensure ordering
	if _door_right_x < _door_left_x:
		_door_right_x = _door_left_x + 20.0

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
	# Add enemy directly to YSort parent so y-sorting includes it
	if get_parent():
		get_parent().add_child(enemy)
	else:
		add_child(enemy) # fallback

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
		if get_parent():
			get_parent().add_child(enemy)
		else:
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
	# Room bias: ask game manager which room is active
	var gm = get_tree().get_first_node_in_group("game")
	if gm and gm.has_method("get_active_room_rect"):
		var r = gm.get_active_room_rect()
		if r is Rect2:
			rect = r
	# Derive safer interior bounds using half wall thickness plus clearance to reduce chance of spawning inside/adjacent to wall
	var min_x = rect.position.x + wall_thickness * 0.5 + spawn_clearance
	var max_x = rect.position.x + rect.size.x - (wall_thickness * 0.5 + spawn_clearance)
	var min_y = rect.position.y + wall_thickness * 0.5 + spawn_clearance
	var max_y = rect.position.y + rect.size.y - (wall_thickness * 0.5 + spawn_clearance)
	var pos := center
	for i in MAX_SPAWN_ATTEMPTS * 4:
		var angle = randf() * TAU
		var r = sqrt(randf()) * spawn_radius
		var candidate = center + Vector2(cos(angle), sin(angle)) * r
		candidate.x = clamp(candidate.x, min_x, max_x)
		candidate.y = clamp(candidate.y, min_y, max_y)
		# Accept if inside and clear of edges / other entities and passes physics overlap test
		if _candidate_valid(candidate, min_x, max_x, min_y, max_y) and _spawn_area_clear(candidate):
			return candidate
	# Fallback center (already clamped)
	pos.x = clamp(center.x, min_x, max_x)
	pos.y = clamp(center.y, min_y, max_y)
	return pos

func _candidate_valid(candidate: Vector2, min_x: float, max_x: float, min_y: float, max_y: float) -> bool:
	if not (candidate.x > min_x + spawn_clearance and candidate.x < max_x - spawn_clearance and candidate.y > min_y + spawn_clearance and candidate.y < max_y - spawn_clearance):
		return false
	# Corridor / doorway safety region: broaden exclusion horizontally and constrain vertical band.
	var extended_left = _door_left_x - wall_thickness * 1.0
	var extended_right = _door_right_x + wall_thickness * 1.0
	if candidate.x > extended_left and candidate.x < extended_right:
		# Only allow spawn if within the vertical doorway gap band.
		if abs(candidate.y - _door_center_y) > _door_half_height * 0.85:
			return false
		# Still keep a margin closer to actual wall columns.
		if candidate.x < _door_left_x + 4 or candidate.x > _door_right_x - 4:
			return false
	# Keep a little distance from player
	if is_instance_valid(_player) and candidate.distance_to(_player.global_position) < spawn_clearance * 1.6:
		return false
	# Avoid overlapping existing enemies
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if candidate.distance_to(e.global_position) < spawn_clearance * 1.4:
			return false
	return true

func _spawn_area_clear(candidate: Vector2) -> bool:
	# Physics overlap test using a small circle to ensure not inside / too close to wall static bodies
	var world2d = get_viewport().get_world_2d()
	if world2d == null:
		return true # can't test; allow
	var space = world2d.direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = max(4.0, spawn_clearance * 0.6) - PHYSICS_CHECK_SHRINK
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, candidate)
	params.collision_mask = 0xFFFFFFFF
	var res = space.intersect_shape(params, 8)
	for hit in res:
		if hit.has("collider") and hit.collider.is_in_group("wall"):
			return false
	return true
