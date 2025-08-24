extends Node

@export var hud_path: NodePath
var hud: Node
var elapsed: float = 0.0
var kills: int = 0
var wave: int = 0
var enemies_remaining_in_wave: int = 0
@export var wave_break_time: float = 3.0
@export var base_wave_enemy_count: int = 5
@export var wave_enemy_growth: int = 3
@export var wave_speed_growth: float = 10.0
var _between_waves_timer: float = 0.0
var _in_break := true
var _game_over := false

func _ready():
	add_to_group("game")
	if hud_path != NodePath():
		hud = get_node(hud_path)
	_start_next_wave()

func on_enemy_killed(enemy: Node) -> void:
	kills += 1
	enemies_remaining_in_wave = max(enemies_remaining_in_wave - 1, 0)
	if enemies_remaining_in_wave == 0:
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

func _process(delta: float) -> void:
	if _game_over:
		return
	elapsed += delta
	if _in_break:
		_between_waves_timer += delta
		if _between_waves_timer >= wave_break_time:
			_start_next_wave()
	_update_hud()

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
	var spawner = get_node_or_null("EnemySpawner")
	if spawner == null:
		spawner = get_tree().get_first_node_in_group("EnemySpawner")
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
			overlay.show_overlay(kills, wave, elapsed)
	get_tree().paused = true
