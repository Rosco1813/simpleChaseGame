extends CharacterBody2D

@export var speed: float = 200.0
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.15
@export var bullet_spawn_radius: float = 16.0

var _cooldown_left := 0.0

var _world_rect: Rect2

func _ready() -> void:
	if Engine.has_singleton("GameConfig"):
		# If added as autoload singleton (Node), we can just reference the script directly
		_world_rect = GameConfig.world_rect

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()

	_handle_shooting(delta)
	# Clamp inside world bounds (if configured)
	if _world_rect.size != Vector2.ZERO:
		global_position.x = clamp(global_position.x, _world_rect.position.x, _world_rect.position.x + _world_rect.size.x)
		global_position.y = clamp(global_position.y, _world_rect.position.y, _world_rect.position.y + _world_rect.size.y)

func _handle_shooting(delta: float) -> void:
	_cooldown_left = max(_cooldown_left - delta, 0.0)
	if Input.is_action_pressed("shoot") and _cooldown_left <= 0.0 and bullet_scene:
		var viewport := get_viewport()
		var mouse_pos = viewport.get_mouse_position()
		# Convert mouse from viewport to world (Camera2D) coordinates
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
