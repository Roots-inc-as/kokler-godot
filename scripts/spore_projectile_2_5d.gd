extends Area3D

@export var speed := 8.0
@export var lifetime := 1.1

var direction := Vector3.FORWARD
var damage := 1
var source: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(start_position: Vector3, travel_direction: Vector3, projectile_damage: int, projectile_source: Node = null) -> void:
	global_position = start_position
	direction = travel_direction
	direction.y = 0.0
	direction = direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	damage = projectile_damage
	source = projectile_source


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	global_position.y = 0.35
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == source:
		return
	if source and source.is_in_group("player_2_5d"):
		if body.is_in_group("enemy_2_5d") and body.has_method("take_damage"):
			body.call("take_damage", damage)
		queue_free()
		return
	elif body.is_in_group("player_2_5d") and body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
