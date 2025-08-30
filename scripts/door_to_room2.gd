extends Node2D

signal player_entered_room2

@onready var blocker: StaticBody2D = $Blocker
@onready var trigger: Area2D = $Trigger

var is_open := false

func _ready():
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)
	_close_initial()

func _close_initial():
	is_open = false
	if blocker:
		blocker.visible = true
		for c in blocker.get_children():
			if c is CollisionShape2D:
				c.disabled = false
	# (No visual sprite now.)
	if trigger:
		trigger.monitoring = true
		trigger.set_deferred("monitorable", true)

func open_door():
	if is_open:
		return
	is_open = true
	print_debug("[DoorToRoom2] Opening door and removing blocker")
	# Remove blocker collision
	if blocker:
		for c in blocker.get_children():
			if c is CollisionShape2D:
				c.disabled = true
		blocker.visible = false
		# Fully remove blocker to guarantee no lingering collision
		blocker.queue_free()
	# Ensure trigger no longer obstructs (disable its shapes & stop monitoring)
	if trigger:
		for c in trigger.get_children():
			if c is CollisionShape2D:
				c.disabled = true
		trigger.monitoring = true # still needs to fire once when player enters
		trigger.monitorable = false # prevent physics bodies from treating it as obstacle
	# Disable door fill segments if present (split wall pattern)
	# (Legacy door fill segments removed; collision gap handled by TileMap script now.)
	# (No door visual to fade in.)

func _on_trigger_body_entered(body: Node) -> void:
	if not is_open:
		return
	if body.is_in_group("player"):
		emit_signal("player_entered_room2")
		# Only need to fire once
		if trigger:
			trigger.monitoring = false
			for c in trigger.get_children():
				if c is CollisionShape2D:
					c.disabled = true
