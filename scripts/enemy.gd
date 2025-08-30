extends CharacterBody2D

@export var speed: float = 120.0
@export var target_path: NodePath
@export var stop_distance: float = 32.0 # minimum distance to keep from target
@export var separation_push: float = 160.0 # outward push speed when overlapping player
var target: Node2D
var _world_rect: Rect2
var _spawn_age: float = 0.0

# Doorway / corridor heuristics (mutable; populated from spawner when available)
var _door_left_x: float = 400.0
var _door_right_x: float = 420.0
var _door_half_height: float = 110.0
var _door_center_y: float = 0.0

var _door_inited: bool = false

func _ready() -> void:
	if target_path != NodePath():
		target = get_node(target_path)
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect
	# Listen for world rect changes from game manager
	var gm = get_tree().get_first_node_in_group("game")
	if gm and gm.has_signal("world_rect_changed"):
		if not gm.is_connected("world_rect_changed", Callable(self, "_on_world_rect_changed")):
			gm.world_rect_changed.connect(_on_world_rect_changed)

func _physics_process(delta: float) -> void:
	_spawn_age += delta
	if not _door_inited:
		_init_door_params()
	# Ensure we have a world rect (fallback each frame if missing)
	if _world_rect.size == Vector2.ZERO and Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect
	if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.freeze_enemies:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var desired = target.global_position
	# If target is across the doorway horizontally, bias movement vertically toward doorway gap first
	var crossing_rooms = (global_position.x < _door_left_x and desired.x > _door_right_x) or (global_position.x > _door_right_x and desired.x < _door_left_x)
	if crossing_rooms:
		var within_vertical_band = abs(global_position.y - _door_center_y) <= _door_half_height * 0.95
		if not within_vertical_band:
			# Vertical alignment phase. Guard against pushing off-map if at extreme edges.
			var vertical_dir = sign(_door_center_y - global_position.y)
			if _world_rect.size != Vector2.ZERO:
				var top_edge = _world_rect.position.y + 6.0
				var bottom_edge = _world_rect.position.y + _world_rect.size.y - 6.0
				if global_position.y <= top_edge and vertical_dir < 0:
					vertical_dir = 0
				if global_position.y >= bottom_edge and vertical_dir > 0:
					vertical_dir = 0
			velocity.x = lerp(velocity.x, 0.0, 0.6)
			velocity.y = vertical_dir * speed * 0.85
			if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.log_enemy_launch:
				print_debug("[EnemyAlign] id=", get_instance_id(), " alignPhase pos=", global_position, " vDir=", vertical_dir, " bandHalf=", _door_half_height)
			move_and_slide()
			# Post-move clamp & damp to kill any accidental large vertical impulse
			if _world_rect.size != Vector2.ZERO:
				var top_edge2 = _world_rect.position.y
				var bottom_edge2 = _world_rect.position.y + _world_rect.size.y
				global_position.y = clamp(global_position.y, top_edge2 + 4.0, bottom_edge2 - 4.0)
			if abs(velocity.y) > speed * 2.0:
				velocity.y = sign(velocity.y) * speed
			return
		# Inside band: gently bias desired.y toward center to stay in corridor
		if abs(desired.y - _door_center_y) > _door_half_height * 0.6:
			desired.y = _door_center_y
	var dir = (desired - global_position)
	var dist = dir.length()
	# Simplified: if within stop distance just slow down instead of strong push which could cause slide along walls
	if dist > stop_distance:
		dir = dir.normalized()
		var spd_mult := 1.0
		if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled:
			spd_mult = DebugSettings.enemy_speed_mult
		velocity = dir * speed * spd_mult
	else:
		# Within comfort radius: smoothly slow toward zero without reversing direction violently
		var slow_factor = clamp(dist / stop_distance, 0.0, 1.0)
		velocity = dir.normalized() * speed * 0.4 * slow_factor
	move_and_slide()
	# Clamp inside current world rect to avoid drifting off-map due to any rare collision impulses
	if _world_rect.size != Vector2.ZERO:
		var margin := 8.0
		global_position.x = clamp(global_position.x, _world_rect.position.x + margin, _world_rect.position.x + _world_rect.size.x - margin)
		global_position.y = clamp(global_position.y, _world_rect.position.y + margin, _world_rect.position.y + _world_rect.size.y - margin)
	# Mitigate vertical launch: damp large vertical velocity (early or anytime while crossing)
	if abs(velocity.y) > speed * 2.5:
		if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.log_enemy_launch:
			print_debug("[EnemyLaunch] id=", get_instance_id(), " pos=", global_position, " vel=", velocity, " age=", _spawn_age)
		velocity.y = sign(velocity.y) * speed * 1.2
	# Absolute position failsafe if something still escaped bounds
	if _world_rect.size != Vector2.ZERO:
		var top_bound = _world_rect.position.y - 16.0
		var bottom_bound = _world_rect.position.y + _world_rect.size.y + 16.0
		if global_position.y < top_bound or global_position.y > bottom_bound:
			if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.log_enemy_launch:
				print_debug("[EnemyOOB] id=", get_instance_id(), " pos=", global_position, " correcting")
			global_position.y = clamp(global_position.y, _world_rect.position.y + 8.0, _world_rect.position.y + _world_rect.size.y - 8.0)
			velocity.y = 0.0

func _init_door_params():
	_door_inited = true
	# Attempt to pull doorway params from any spawner (which gathered them from wall maps)
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		if "_door_left_x" in spawner:
			_door_left_x = spawner._door_left_x
		if "_door_right_x" in spawner:
			_door_right_x = spawner._door_right_x
		if "_door_center_y" in spawner:
			_door_center_y = spawner._door_center_y
		if "_door_half_height" in spawner:
			_door_half_height = spawner._door_half_height

func _on_world_rect_changed(new_rect: Rect2):
	_world_rect = new_rect

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.log_enemy_spawn:
			print_debug("[EnemySpawn] id=", get_instance_id(), " pos=", global_position)
