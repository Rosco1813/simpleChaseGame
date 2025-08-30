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
var _aim_mode: String = "mouse" # "mouse" or "pad"
var _virtual_cursor: Node2D
const AIM_DEADZONE := 0.25
var _last_stick_dir := Vector2.RIGHT
@export var virtual_cursor_speed: float = 520.0
@export var virtual_cursor_accel_scale: float = 0.6 # extra speed factor at full tilt
var _mouse_last_pos: Vector2
var _mouse_move_timer: float = 0.0
const MOUSE_IDLE_SWITCH := 0.35
@export var assist_enabled: bool = true
@export var assist_radius: float = 300.0
@export var assist_cone_angle_deg: float = 65.0
@export var assist_base_strength: float = 0.6
@export var assist_hysteresis: float = 0.15
var _assist_locked_target: Node = null
var _assist_indicator: Node2D

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
	_mouse_last_pos = get_viewport().get_mouse_position()
	_create_virtual_cursor()
	_update_mouse_mode()
	_create_assist_indicator()
	# Listen for world rect changes from game manager
	var gm = get_tree().get_first_node_in_group("game")
	if gm and gm.has_signal("world_rect_changed"):
		if not gm.is_connected("world_rect_changed", Callable(self, "_on_world_rect_changed")):
			gm.world_rect_changed.connect(_on_world_rect_changed)
	# Initialize current rect if GameConfig updated earlier
	if Engine.has_singleton("GameConfig"):
		_world_rect = GameConfig.world_rect


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Refresh world rect if it expanded (multi-room)
	if Engine.has_singleton("GameConfig"):
		var wr = GameConfig.world_rect
		if wr.position != _world_rect.position or wr.size != _world_rect.size:
			_world_rect = wr
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
	_update_aim(delta)
	# Timers
	_damage_cd_left = max(_damage_cd_left - delta, 0.0)
	_mouse_move_timer += delta

func _handle_shooting(delta: float) -> void:
	_cooldown_left = max(_cooldown_left - delta, 0.0)
	if Input.is_action_pressed("shoot") and _cooldown_left <= 0.0 and bullet_scene and not _dead:
		var dir: Vector2
		if _aim_mode == "pad" and _virtual_cursor:
			var world_cursor = _virtual_cursor.global_position
			dir = (world_cursor - global_position)
		else:
			var world_mouse = get_global_mouse_position()
			dir = (world_mouse - global_position)
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

func _create_virtual_cursor():
	if _virtual_cursor:
		return
	_virtual_cursor = Node2D.new()
	_virtual_cursor.name = "VirtualCursor"
	_virtual_cursor.position = Vector2(100,0)
	add_child(_virtual_cursor)
	# Simple visual indicator
	var dot = ColorRect.new()
	dot.color = Color(0.95,0.95,0.3,0.9)
	dot.size = Vector2(6,6)
	dot.position = Vector2(-3,-3)
	_virtual_cursor.add_child(dot)

func _update_aim(delta: float):
	# Detect mouse movement (keep indentation strictly tabs to avoid mixed indentation parse errors)
	var mp = get_viewport().get_mouse_position()
	if mp.distance_to(_mouse_last_pos) > 2.0:
		_mouse_last_pos = mp
		_mouse_move_timer = 0.0
		if _aim_mode != "mouse":
			_aim_mode = "mouse"
			_update_mouse_mode()
	# Read right-stick (or equivalent) input
	var stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > AIM_DEADZONE and not _dead:
		_last_stick_dir = stick.normalized()
		if _aim_mode != "pad":
			_aim_mode = "pad"
			_update_mouse_mode()
	if _aim_mode == "pad" and _virtual_cursor:
		var mag = stick.length()
		if mag > AIM_DEADZONE:
			# Normalize tilt to 0..1 after deadzone so small deflections move slowly
			var norm_tilt = (mag - AIM_DEADZONE) / (1.0 - AIM_DEADZONE)
			norm_tilt = clamp(norm_tilt, 0.0, 1.0)
			var dir = stick.normalized()
			_last_stick_dir = dir
			var speed = virtual_cursor_speed * (0.15 + 0.85 * norm_tilt) * (1.0 + virtual_cursor_accel_scale * norm_tilt)
			# Raw move (store pre-assist position)
			var raw_pos = _virtual_cursor.global_position + dir * speed * get_physics_process_delta_time()
			_virtual_cursor.global_position = raw_pos
		# Clamp to visible camera view so it never leaves screen
		var cam = get_viewport().get_camera_2d()
		if cam:
			var vp_size = get_viewport_rect().size * cam.zoom
			var half = vp_size * 0.5
			var vis_left = cam.global_position.x - half.x
			var vis_top = cam.global_position.y - half.y
			var vis_right = cam.global_position.x + half.x
			var vis_bottom = cam.global_position.y + half.y
			_virtual_cursor.global_position.x = clamp(_virtual_cursor.global_position.x, vis_left, vis_right)
			_virtual_cursor.global_position.y = clamp(_virtual_cursor.global_position.y, vis_top, vis_bottom)
		# Apply aim assist after raw movement & clamps
		if assist_enabled:
			_apply_aim_assist()
	elif _aim_mode == "mouse" and _virtual_cursor:
		# Mirror hardware mouse so we have a consistent cursor object for effects / future UI
		_virtual_cursor.global_position = get_global_mouse_position()
	# If pad idle for a while and mouse moves, mode already switched above
	if _aim_mode == "pad" and stick.length() <= AIM_DEADZONE and _mouse_move_timer < MOUSE_IDLE_SWITCH:
		pass # remain in pad mode until mouse actively moves

func _update_mouse_mode():
	if _aim_mode == "pad":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_world_rect_changed(new_rect: Rect2):
	_world_rect = new_rect

func _create_assist_indicator():
	if _assist_indicator:
		return
	_assist_indicator = Node2D.new()
	_assist_indicator.name = "AssistIndicator"
	add_child(_assist_indicator)
	var ring = ColorRect.new()
	ring.name = "Ring"
	ring.color = Color(1,0.9,0.3,0.0)
	ring.size = Vector2(18,18)
	ring.position = Vector2(-9,-9)
	_assist_indicator.add_child(ring)
	_assist_indicator.visible = false

func _apply_aim_assist():
	# Soft magnetic assist: pull virtual cursor toward best target
	var stick = Input.get_vector("aim_left","aim_right","aim_up","aim_down")
	if stick.length() <= AIM_DEADZONE:
		_clear_assist_target()
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		_clear_assist_target()
		return
	var player_pos = global_position
	var aim_dir = (_virtual_cursor.global_position - player_pos).normalized()
	var cone_rad = deg_to_rad(assist_cone_angle_deg)
	var best: Node = null
	var best_score = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var ep = e.global_position
		var v = ep - player_pos
		var dist = v.length()
		if dist > assist_radius:
			continue
		var score = dist
		if aim_dir.length() > 0.1:
			var ang = abs(aim_dir.angle_to(v.normalized()))
			if ang > cone_rad:
				# Deprioritize outside cone
				score += assist_radius * 5.0
		if e == _assist_locked_target:
			score *= 0.85
		if score < best_score:
			best_score = score
			best = e
	# Hysteresis decision
	if best and _assist_locked_target and best != _assist_locked_target:
		var prev_dist = (_assist_locked_target.global_position - player_pos).length()
		if best_score > prev_dist * (1.0 - assist_hysteresis):
			best = _assist_locked_target
	_assist_locked_target = best
	if not _assist_locked_target:
		_clear_assist_target()
		return
	var target_pos = _assist_locked_target.global_position
	var td = (target_pos - player_pos).length()
	var falloff = clamp(1.0 - td / assist_radius, 0.0, 1.0)
	var strength = falloff * assist_base_strength
	_virtual_cursor.global_position = _virtual_cursor.global_position.lerp(target_pos, strength)
	_update_assist_indicator(target_pos, strength)

func _clear_assist_target():
	_assist_locked_target = null
	if _assist_indicator:
		_assist_indicator.visible = false

func _update_assist_indicator(target_pos: Vector2, strength: float):
	if not _assist_indicator:
		return
	_assist_indicator.global_position = target_pos
	_assist_indicator.visible = strength > 0.15
	var ring = _assist_indicator.get_node_or_null("Ring")
	if ring and ring is ColorRect:
		ring.color = Color(1,0.9,0.3, clamp(strength, 0.2, 0.9))

func _update_health_bar() -> void:
	if not has_node("HealthBar/Fill"):
		return
	var fill = get_node("HealthBar/Fill")
	if fill is ColorRect:
		var ratio = 1.0 if max_health <= 0 else float(health)/float(max_health)
		fill.size.x = 30 * ratio
