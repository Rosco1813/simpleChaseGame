extends CharacterBody2D

@export var speed: float = 200.0
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.15
@export var bullet_spawn_radius: float = 16.0

# Health system
@export var max_health: int = 5
@export var damage_cooldown: float = 0.6 # seconds between taking contact damage
var health: int
var _damage_cd_left: float = 0.0
var _dead: bool = false

signal died

var _cooldown_left := 0.0

var _world_rect: Rect2

func _ready() -> void:
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect
	health = max_health
	# Connect hitbox for damage
	if has_node("Hitbox"):
		var hitbox = get_node("Hitbox")
		if hitbox.has_signal("body_entered"):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()

	_handle_shooting(delta)
	# Timers
	_damage_cd_left = max(_damage_cd_left - delta, 0.0)
	# Clamp inside world bounds (if configured)
	if _world_rect.size != Vector2.ZERO:
		global_position.x = clamp(global_position.x, _world_rect.position.x, _world_rect.position.x + _world_rect.size.x)
		global_position.y = clamp(global_position.y, _world_rect.position.y, _world_rect.position.y + _world_rect.size.y)

func _handle_shooting(delta: float) -> void:
	_cooldown_left = max(_cooldown_left - delta, 0.0)
	if Input.is_action_pressed("shoot") and _cooldown_left <= 0.0 and bullet_scene and not _dead:
		var world_mouse = get_global_mouse_position()
		var dir = (world_mouse - global_position)
		if dir.length() < 0.001:
			return
		var spawn_pos = global_position + dir.normalized() * bullet_spawn_radius
		var bullet = bullet_scene.instantiate()
		bullet.global_position = spawn_pos
		if bullet.has_method("setup"):
			bullet.setup(dir)
		get_tree().current_scene.add_child(bullet)
		_cooldown_left = fire_cooldown

func _on_hitbox_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("enemy"):
		_apply_contact_damage(1)

func _apply_contact_damage(amount: int) -> void:
	if _damage_cd_left > 0.0:
		return
	health = clamp(health - amount, 0, max_health)
	_damage_cd_left = damage_cooldown
	_update_health_bar()
	if health <= 0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	emit_signal("died")
	# Notify game manager(s)
	if get_tree().has_group("game"):
		for n in get_tree().get_nodes_in_group("game"):
			if n.has_method("on_player_died"):
				n.on_player_died()
	# Optional: visually indicate death
	if has_node("Body"):
		var body = get_node("Body")
		if body is Polygon2D:
			body.color = Color(0.5,0.5,0.5,1)

func _update_health_bar() -> void:
	if not has_node("HealthBar/Fill"):
		return
	var fill = get_node("HealthBar/Fill")
	if fill is ColorRect:
		var ratio = 1.0 if max_health <= 0 else float(health)/float(max_health)
		fill.size.x = 30 * ratio
