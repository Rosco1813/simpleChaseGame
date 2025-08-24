extends CharacterBody2D

@export var speed: float = 120.0
@export var target_path: NodePath
@export var stop_distance: float = 32.0 # minimum distance to keep from target
var target: Node2D
var _world_rect: Rect2

func _ready() -> void:
	if target_path != NodePath():
		target = get_node(target_path)
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir = (target.global_position - global_position)
	var dist = dir.length()
	if dist > stop_distance:
		dir = dir.normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# Clamp inside world
	if _world_rect.size != Vector2.ZERO:
		global_position.x = clamp(global_position.x, _world_rect.position.x, _world_rect.position.x + _world_rect.size.x)
		global_position.y = clamp(global_position.y, _world_rect.position.y, _world_rect.position.y + _world_rect.size.y)
