extends TileMap

@export var room_origin: Vector2 = Vector2(-400, -300)
@export var room_size: Vector2 = Vector2(800, 600)
@export var tile_size_px: int = 32
@export var doorway_center: Vector2 = Vector2(400, 0) # world position of doorway center relative to main scene
@export var doorway_half_height: int = 110
@export var draw_interior_edge: bool = true
@export var variation_seed: int = 1
@export var doorway_open: bool = false
@export var doorway_width_tiles: int = 2 # vertical half-height expressed in tile count (gap height = doorway_width_tiles * 2 tiles)
@export var open_full_side: bool = false # when true and doorway opens, remove entire owning side wall, not just gap

var _doorway_is_left: bool = false
var _doorway_is_right: bool = false

var _tiles_ready := false

func _ready():
	_ensure_tiles()
	# Defer painting so physics bodies are created after current collision flush (avoids flushing queries error)
	call_deferred("_deferred_paint")

func _deferred_paint():
	_paint_border()

func _ensure_tiles():
	if tile_set == null:
		tile_set = TileSet.new()
		# Ensure tile size matches our intended pixel size so placement aligns.
		tile_set.tile_size = Vector2i(tile_size_px, tile_size_px)
	if _tiles_ready:
		return
	# Create three atlas sources: 0 base, 1 alt, 2 lip
	var base_img = Image.create(tile_size_px, tile_size_px, false, Image.FORMAT_RGBA8)
	base_img.fill(Color(0.16,0.19,0.23,1))
	# Subtle 2px lighter edge for top highlight
	for x in range(tile_size_px):
		for y in range(2):
			var c = base_img.get_pixel(x,y)
			base_img.set_pixel(x,y, c.lightened(0.08))
	var base_src = TileSetAtlasSource.new()
	base_src.texture = ImageTexture.create_from_image(base_img)
	# In Godot 4, use create_tile with atlas coordinates instead of setting a region property.
	base_src.create_tile(Vector2i(0,0))
	tile_set.add_source(base_src, 0)

	var alt_img = base_img.duplicate()
	for i in range(12):
		var rx = randi() % tile_size_px
		var ry = randi() % tile_size_px
		var p = alt_img.get_pixel(rx, ry)
		alt_img.set_pixel(rx, ry, p.lightened(0.05))
	var alt_src = TileSetAtlasSource.new()
	alt_src.texture = ImageTexture.create_from_image(alt_img)
	alt_src.create_tile(Vector2i(0,0))
	tile_set.add_source(alt_src, 1)
	_tiles_ready = true

func _paint_border():
	clear()
	var base_offset = global_position
	var left = base_offset.x + room_origin.x
	var top = base_offset.y + room_origin.y
	var right = left + room_size.x
	var bottom = top + room_size.y
	var tile_w = tile_size_px
	var cols = int(room_size.x / tile_w)
	var rows = int(room_size.y / tile_w)
	var wall_tile_id = 0
	var alt_id = 1
	# Compute vertical gap from either explicit pixel half-height or doorway_width_tiles
	var gap_half_height_px = max(doorway_half_height, doorway_width_tiles * tile_size_px * 0.5)
	var doorway_center_global = base_offset + doorway_center
	var doorway_y_min = doorway_center_global.y - gap_half_height_px
	var doorway_y_max = doorway_center_global.y + gap_half_height_px
	# Determine which side the doorway belongs to (closest horizontal edge)
	var dist_left = abs(doorway_center_global.x - left)
	var dist_right = abs(right - doorway_center_global.x)
	_doorway_is_left = dist_left <= dist_right
	_doorway_is_right = dist_right < dist_left
	for cx in range(cols):
		var world_x = left + cx * tile_w + tile_w/2
		# top row
		_set_cell(world_x, top + tile_w/2, wall_tile_id if cx % 2 == 0 else alt_id)
		# bottom row
		_set_cell(world_x, bottom - tile_w/2, wall_tile_id if cx % 2 == 0 else alt_id)
	# left and right columns (skip corners to avoid double placement overlap)
	for cy in range(1, rows-1):
		var world_y = top + cy * tile_w + tile_w/2
		var in_gap = world_y > doorway_y_min and world_y < doorway_y_max
		# Left column
		if not (doorway_open and _doorway_is_left and (in_gap or open_full_side)):
			_set_cell(left + tile_w/2, world_y, alt_id if cy % 2 == 0 else wall_tile_id)
		# Right column
		if not (doorway_open and _doorway_is_right and (in_gap or open_full_side)):
			_set_cell(right - tile_w/2, world_y, alt_id if cy % 2 == 0 else wall_tile_id)

	_build_collision_segments(cols, rows, left, top, right, bottom, doorway_y_min, doorway_y_max, tile_w)
	_debug_dump_segments()

func _build_collision_segments(cols:int, rows:int, left:float, top:float, right:float, bottom:float, doorway_y_min:float, doorway_y_max:float, tile_w:int):
	# Remove previous segment bodies
	if has_node("WallSegments"):
		get_node("WallSegments").queue_free()
	var container = Node2D.new()
	container.name = "WallSegments"
	add_child(container)
	# Top & Bottom rows
	for cx in range(cols):
		var world_x = left + cx * tile_w + tile_w/2
		_make_rect(container, Vector2(world_x, top + tile_w/2), Vector2(tile_w, tile_w))
		_make_rect(container, Vector2(world_x, bottom - tile_w/2), Vector2(tile_w, tile_w))
	# Left / Right columns, optionally skipping doorway gap on the owning side only when open
	for cy in range(1, rows-1):
		var world_y = top + cy * tile_w + tile_w/2
		var in_gap = world_y > doorway_y_min and world_y < doorway_y_max
		if not (doorway_open and _doorway_is_left and (in_gap or open_full_side)):
			_make_rect(container, Vector2(left + tile_w/2, world_y), Vector2(tile_w, tile_w))
		if not (doorway_open and _doorway_is_right and (in_gap or open_full_side)):
			_make_rect(container, Vector2(right - tile_w/2, world_y), Vector2(tile_w, tile_w))

func open_doorway(force_rebuild: bool=false):
	# When force_rebuild is true we repaint even if already open (needed when upgrading to full-side removal)
	if doorway_open and not force_rebuild:
		return
	doorway_open = true
	_paint_border()
	if not open_full_side:
		_draw_threshold_tiles()
	_purge_gap_collisions()

func _draw_threshold_tiles():
	# Place a single interior column of base tiles just inside each opened side for visual floor bridge
	if not doorway_open:
		return
	if open_full_side:
		return # no threshold accent when entire side removed
	var base_offset = global_position
	var left = base_offset.x + room_origin.x
	var right = left + room_size.x
	var top = base_offset.y + room_origin.y
	var bottom = top + room_size.y
	var gap_half_height_px = max(doorway_half_height, doorway_width_tiles * tile_size_px * 0.5)
	var doorway_center_global = base_offset + doorway_center
	var doorway_y_min = doorway_center_global.y - gap_half_height_px
	var doorway_y_max = doorway_center_global.y + gap_half_height_px
	var tile_w = tile_size_px
	# y iteration over tiles in gap
	var y_start = int(floor((doorway_y_min - top) / tile_w))
	var y_end = int(ceil((doorway_y_max - top) / tile_w))
	for ty in range(y_start, y_end):
		var world_y = top + ty * tile_w + tile_w/2
		if world_y <= doorway_y_min or world_y >= doorway_y_max:
			continue
		# Left interior bridge (one tile inside room) if doorway on left side
		if _doorway_is_left:
			_set_cell(left + tile_w/2 + tile_w, world_y, 0)
		# Right interior bridge (one tile inside room) if doorway on right side
		if _doorway_is_right:
			_set_cell(right - tile_w/2 - tile_w, world_y, 0)

func _purge_gap_collisions():
	if not doorway_open:
		return
	if not has_node("WallSegments"):
		return
	var base_offset = global_position
	var left = base_offset.x + room_origin.x
	var right = left + room_size.x
	var top = base_offset.y + room_origin.y
	var gap_half_height_px = max(doorway_half_height, doorway_width_tiles * tile_size_px * 0.5)
	var doorway_center_global = base_offset + doorway_center
	var doorway_y_min = doorway_center_global.y - gap_half_height_px
	var doorway_y_max = doorway_center_global.y + gap_half_height_px
	var tile_w = tile_size_px
	var target_x = 0.0
	if _doorway_is_left:
		target_x = left + tile_w/2
	elif _doorway_is_right:
		target_x = right - tile_w/2
	var container = get_node("WallSegments")
	for body in container.get_children():
		if not (body is StaticBody2D):
			continue
		var gp = body.global_position
		if gp.y > doorway_y_min and gp.y < doorway_y_max and abs(gp.x - target_x) < tile_w * 0.75:
			body.queue_free()
	_debug_dump_segments()

func _debug_dump_segments():
	if not has_node("WallSegments"):
		return
	var arr: Array[String] = []
	for b in get_node("WallSegments").get_children():
		if b is StaticBody2D:
			arr.append("%.1f,%.1f" % [b.global_position.x, b.global_position.y])
	print_debug("[WallTileMap] segments count=", arr.size(), " first few=", arr.slice(0, min(5, arr.size())))

func _make_rect(container: Node2D, center: Vector2, size: Vector2):
	if size.x <= 0 or size.y <= 0:
		return
	var body = StaticBody2D.new()
	# 'center' provided in world coordinates; convert to local so collisions align with tiles for all room offsets
	body.position = to_local(center)
	body.add_to_group("wall")
	var shape = RectangleShape2D.new()
	shape.size = size
	var cs = CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	container.add_child(body)

func _set_cell(world_x: float, world_y: float, tile_id: int):
	var local = to_local(Vector2(world_x, world_y))
	var co = local / tile_size_px
	var x = int(floor(co.x))
	var y = int(floor(co.y))
	set_cell(0, Vector2i(x,y), tile_id, Vector2i.ZERO)
