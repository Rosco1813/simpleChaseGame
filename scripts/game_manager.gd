extends Node

signal world_rect_changed(new_rect: Rect2)

@export var hud_path: NodePath
var hud: Node
var elapsed: float = 0.0
var kills: int = 0
var wave: int = 0
var enemies_remaining_in_wave: int = 0
var bullets_fired: int = 0
var score: int = 0
@export var wave_break_time: float = 3.0
@export var base_wave_enemy_count: int = 5
@export var wave_enemy_growth: int = 3
@export var wave_speed_growth: float = 10.0
@export var score_scale: float = 100.0 # multiplier to inflate score numbers
var _between_waves_timer: float = 0.0
var _in_break := true
var _game_over := false
var _last_time_scale: float = 1.0
var waiting_for_room2: bool = false
var room2_instanced: bool = false
var room2_packed: PackedScene
var current_room: int = 1
var waiting_for_room2_center: bool = false
@export var room2_center_trigger_radius: float = 160.0
const ROOM1_RECT := Rect2(Vector2(-400,-300), Vector2(800,600))
const ROOM2_RECT := Rect2(Vector2(420,-300), Vector2(800,600)) # 820 center - 400 origin

func _ready():
	add_to_group("game")
	if hud_path != NodePath():
		hud = get_node(hud_path)
	# Preload reference to room2 scene for lazy instance
	if ResourceLoader.exists("res://scenes/Room2.tscn"):
		room2_packed = load("res://scenes/Room2.tscn")
	_start_next_wave()

func on_enemy_killed(_enemy: Node) -> void:
	kills += 1
	enemies_remaining_in_wave = max(enemies_remaining_in_wave - 1, 0)
	if enemies_remaining_in_wave == 0:
		if wave == 1 and not room2_instanced:
			_prepare_room2_transition()
		else:
			_in_break = true
			_between_waves_timer = 0.0
	_update_hud()

func _update_hud():
	if hud and hud.is_inside_tree():
		if hud.has_node("KillLabel"):
			hud.get_node("KillLabel").text = "Kills: %d" % kills
		if hud.has_node("TimeLabel"):
			hud.get_node("TimeLabel").text = "Time: %.1f" % elapsed
		if hud.has_node("WaveLabel"):
			hud.get_node("WaveLabel").text = "Wave: %d" % wave
		if hud.has_node("WaveStatus"):
			var status = "Fighting" if not _in_break else "Break"
			hud.get_node("WaveStatus").text = status
		if hud.has_node("BulletLabel"):
			hud.get_node("BulletLabel").text = "Bullets: %d" % bullets_fired
		if hud.has_node("ScoreLabel"):
			hud.get_node("ScoreLabel").text = "Score: %d" % score

func _process(delta: float) -> void:
	if _game_over:
		return
	# Apply debug time scale
	if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled:
		if DebugSettings.time_scale != _last_time_scale:
			Engine.time_scale = DebugSettings.time_scale
			_last_time_scale = DebugSettings.time_scale
	elapsed += delta
	score = _compute_score()
	if _in_break and not waiting_for_room2:
		_between_waves_timer += delta
		if _between_waves_timer >= wave_break_time:
			_start_next_wave()
	if waiting_for_room2_center:
		_check_room2_center_progress()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	if _game_over:
		return
	get_tree().paused = true
	if hud and hud.has_node("PauseOverlay"):
		var p = hud.get_node("PauseOverlay")
		if p and p.has_method("show_menu"):
			p.show_menu()

func resume_game() -> void:
	get_tree().paused = false
	if hud and hud.has_node("PauseOverlay"):
		var p = hud.get_node("PauseOverlay")
		if p and p.has_method("hide_menu"):
			p.hide_menu()

func _start_next_wave():
	wave += 1
	_in_break = false
	var enemy_count = base_wave_enemy_count + (wave - 1) * wave_enemy_growth
	enemies_remaining_in_wave = enemy_count
	# Choose color based on wave (cycle hues)
	var hue = fmod((wave * 0.13), 1.0)
	var wave_color = Color.from_hsv(hue, 0.75, 0.95)
	# Increase base enemy speed each wave by directly touching existing enemies
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("speed"):
			e.speed += wave_speed_growth
	# Spawn wave via spawner
	var spawner = get_node_or_null("WorldYSort/EnemySpawner")
	if spawner == null:
		spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.has_method("start_wave"):
		# Ensure max_enemies can accommodate wave (optional mild growth)
		# Safely detect max_enemies property without using unavailable has_variable
		var has_max := false
		for prop in spawner.get_property_list():
			if prop.name == "max_enemies":
				has_max = true
				break
		if has_max and enemy_count > spawner.max_enemies:
			spawner.max_enemies = enemy_count
		var spawned = spawner.start_wave(wave, enemy_count, wave_color)
		enemies_remaining_in_wave = spawned
		if spawned == 0:
			# If nothing spawned, immediately schedule another attempt after short break
			_in_break = true
			_between_waves_timer = wave_break_time * 0.5

func on_player_died() -> void:
	_game_over = true
	if hud and hud.has_node("WaveStatus"):
		hud.get_node("WaveStatus").text = "Game Over"
	if hud and hud.has_node("DeathOverlay"):
		var overlay = hud.get_node("DeathOverlay")
		if overlay and overlay.has_method("show_overlay"):
			overlay.show_overlay(kills, wave, elapsed, bullets_fired, score)
	get_tree().paused = true

# Debug helpers
func debug_skip_wave() -> void:
	if _game_over:
		return
	_start_next_wave()

func debug_kill_all_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	enemies_remaining_in_wave = 0
	_in_break = true
	_between_waves_timer = 0.0
	_update_hud()

func _prepare_room2_transition():
	# Stop automatic break-based next wave until player enters room2
	waiting_for_room2 = true
	_in_break = false
	_between_waves_timer = 0.0
	# Open door
	var door = get_node_or_null("DoorToRoom2")
	if door and door.has_method("open_door"):
		door.open_door()
	if door and door.has_signal("player_entered_room2"):
		if not door.is_connected("player_entered_room2", Callable(self, "_on_player_entered_room2")):
			door.player_entered_room2.connect(_on_player_entered_room2)
	# Instance room2 now (hidden initially optional)
	if room2_packed and not room2_instanced:
		var r2 = room2_packed.instantiate()
		get_tree().current_scene.add_child(r2)
		room2_instanced = true
		# Open matching doorway on Room2 side now as well (bidirectional)
		# Defer opening doorways on both walls until both maps exist; call after a small defer
		call_deferred("_open_both_doorways")
		# Expand world rect to include both rooms precisely
		if Engine.has_singleton("GameConfig"):
			var r1 = ROOM1_RECT
			var r2_rect = ROOM2_RECT
			var left = min(r1.position.x, r2_rect.position.x)
			var top = min(r1.position.y, r2_rect.position.y)
			var right = max(r1.position.x + r1.size.x, r2_rect.position.x + r2_rect.size.x)
			var bottom = max(r1.position.y + r1.size.y, r2_rect.position.y + r2_rect.size.y)
			var combined = Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
			GameConfig.world_rect = combined
			world_rect_changed.emit(combined)
		# Optionally keep camera limits already large

func _on_player_entered_room2():
	if waiting_for_room2:
		waiting_for_room2 = false
		current_room = 2
		# Defer wave start until player reaches center area
		waiting_for_room2_center = true
		_in_break = true # treat as break until ready

func get_active_room_rect() -> Rect2:
	return ROOM2_RECT if current_room == 2 else ROOM1_RECT


func _open_both_doorways():
	var wall1 = get_node_or_null("WorldYSort/WallMap")
	if wall1 and wall1.has_method("open_doorway"):
		if "open_full_side" in wall1:
			wall1.open_full_side = true
		# Force rebuild in case doorway was already opened earlier without full-side
		wall1.open_doorway(true)
	var room2 = get_tree().current_scene.get_node_or_null("Room2")
	if room2:
		var wall2 = room2.get_node_or_null("WallMap")
		if wall2 and wall2.has_method("open_doorway"):
			if "open_full_side" in wall2:
				wall2.open_full_side = true
			wall2.open_doorway(true)

func _check_room2_center_progress():
	# Ensure room2 center goal only for wave 2 gating
	if wave >= 2:
		waiting_for_room2_center = false
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var room_rect = ROOM2_RECT
	var center = room_rect.position + room_rect.size * 0.5
	var dist = player.global_position.distance_to(center)
	if dist <= room2_center_trigger_radius:
		waiting_for_room2_center = false
		_in_break = false
		_between_waves_timer = 0.0
		_start_next_wave()

func on_bullet_fired():
	bullets_fired += 1
	# update score after bullet use
	score = _compute_score()
	_update_hud()

func _compute_score() -> int:
	# Enhanced formula: ((kills * elapsed) + wave * 10) / bullets * scale
	var denom = max(1, bullets_fired)
	var base = (kills * elapsed + wave * 10.0) / denom
	return int(base * score_scale)
