extends CharacterBody2D

@export var speed: float = 200.0
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.15
@export var bullet_spawn_radius: float = 16.0
@export var player_color: Color = Color(0.4, 0.8, 1, 1)
@export var head_color: Color = Color(1.0, 0.62, 0.55, 1.0) # salmon
@export var head_radius: int = 8
@export var head_outline: bool = true
@export var head_outline_color: Color = Color(0,0,0,0.85)
@export var head_offset: Vector2 = Vector2(0, -14) # position relative to body center

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
	_ensure_head_sprite()
	_apply_colors()
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
	var spd_mult := 1.0
	if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled:
		spd_mult = DebugSettings.player_speed_mult
	velocity = input_vector * speed * spd_mult
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
		# Notify game manager(s)
		if get_tree().has_group("game"):
			for n in get_tree().get_nodes_in_group("game"):
				if n.has_method("on_bullet_fired"):
					n.on_bullet_fired()
		_cooldown_left = fire_cooldown

func _on_hitbox_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("enemy"):
		_apply_contact_damage(1)

func _apply_contact_damage(amount: int) -> void:
	if _damage_cd_left > 0.0:
		return
	if typeof(DebugSettings) != TYPE_NIL and DebugSettings.enabled and DebugSettings.invincible:
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
	# Recolor stick figure lines
	for c in get_children():
		if c is Line2D:
			c.default_color = Color(0.6,0.6,0.6,1)
	var head = get_node_or_null("Head")
	if head and head is Sprite2D:
		head.texture = _generate_head_texture(Color(0.6,0.6,0.6,1))

func _apply_colors() -> void:
	# Regenerate head texture
	var head = get_node_or_null("Head")
	if head and head is Sprite2D:
		head.texture = _generate_head_texture(head_color)
	for c in get_children():
		if c is Line2D:
			c.default_color = player_color

func set_player_color(new_color: Color) -> void:
	player_color = new_color
	if not _dead:
		_apply_colors()

func set_head_color(new_color: Color) -> void:
	head_color = new_color
	if not _dead:
		_apply_colors()

func _ensure_head_sprite() -> void:
	if get_node_or_null("Head"):
		return
	var head = Sprite2D.new()
	head.name = "Head"
	head.position = head_offset
	add_child(head)

func _generate_head_texture(color: Color) -> Texture2D:
	var r = max(2, head_radius)
	var size = r * 2 + 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(r+1, r+1)
	var rr = float(r)
	var outline_width = 1.0 if head_outline else 0.0
	for y in size:
		for x in size:
			var p = Vector2(x, y)
			var d = p.distance_to(center)
			if d <= rr:
				var px_color = color
				if head_outline and d >= rr - outline_width:
					px_color = head_outline_color
				img.set_pixel(x, y, px_color)
			else:
				img.set_pixel(x, y, Color(0,0,0,0))
	var tex = ImageTexture.create_from_image(img)
	return tex

func _update_health_bar() -> void:
	if not has_node("HealthBar/Fill"):
		return
	var fill = get_node("HealthBar/Fill")
	if fill is ColorRect:
		var ratio = 1.0 if max_health <= 0 else float(health)/float(max_health)
		fill.size.x = 30 * ratio
