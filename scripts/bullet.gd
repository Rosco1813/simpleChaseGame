extends Area2D

@export var speed: float = 500.0
@export var lifetime: float = 2.0
var _dir: Vector2 = Vector2.ZERO
var _world_rect: Rect2

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect

func setup(direction: Vector2, speed_override: float = -1.0, lifetime_override: float = -1.0):
	_dir = direction.normalized()
	if speed_override > 0:
		speed = speed_override
	if lifetime_override > 0:
		lifetime = lifetime_override

func _physics_process(delta: float) -> void:
	position += _dir * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	# Cull if far outside world
	if _world_rect.size != Vector2.ZERO:
		var margin = 64.0
		if position.x < _world_rect.position.x - margin or position.x > _world_rect.position.x + _world_rect.size.x + margin or position.y < _world_rect.position.y - margin or position.y > _world_rect.position.y + _world_rect.size.y + margin:
			queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if get_tree().has_group("game"):
			for n in get_tree().get_nodes_in_group("game"):
				if n.has_method("on_enemy_killed"):
					n.on_enemy_killed(body)
		body.queue_free()
		queue_free()
