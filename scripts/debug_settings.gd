extends Node

# Central debug / testing flags & tunables
var enabled: bool = true
var invincible: bool = false
var freeze_enemies: bool = false
var player_speed_mult: float = 1.0
var enemy_speed_mult: float = 1.0
var time_scale: float = 1.0
var show_collision_shapes: bool = false

signal changed(name, value)

# Allowed flag names for validation
const _ALLOWED := {
    "invincible": true,
    "freeze_enemies": true,
    "player_speed_mult": true,
    "enemy_speed_mult": true,
    "time_scale": true,
    "show_collision_shapes": true
}

func set_flag(name: String, value) -> void:
    if not enabled:
        return
    if not _ALLOWED.has(name):
        return
    self.set(name, value)
    emit_signal("changed", name, value)

func reset() -> void:
    invincible = false
    freeze_enemies = false
    player_speed_mult = 1.0
    enemy_speed_mult = 1.0
    time_scale = 1.0
    show_collision_shapes = false
    emit_signal("changed", "reset", null)
