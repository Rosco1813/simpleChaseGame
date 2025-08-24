extends Node

# Rect2(position, size). Here position is top-left corner.
# Default world bounds: from -400,-300 to 400,300 (width 800, height 600)
@export var world_rect: Rect2 = Rect2(Vector2(-400,-300), Vector2(800,600))

# Helper to clamp a point inside the world.
func clamp_point(p: Vector2) -> Vector2:
    return Vector2(
        clamp(p.x, world_rect.position.x, world_rect.position.x + world_rect.size.x),
        clamp(p.y, world_rect.position.y, world_rect.position.y + world_rect.size.y)
    )