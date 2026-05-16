extends CharacterBody3D

@export var target_path: NodePath
@export var move_speed := 1.65
@export var chase_radius := 7.5
@export var return_speed := 0.9
@export var ground_y := 0.0

@onready var model: Node3D = $Model

var target: Node3D
var home_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("blind_rat_2_5d_test")
	home_position = global_position
	home_position.y = ground_y
	global_position.y = ground_y
	_resolve_target()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_resolve_target()

	var desired_velocity := Vector3.ZERO
	if target:
		var to_player := target.global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= chase_radius:
			desired_velocity = to_player.normalized() * move_speed

	if desired_velocity == Vector3.ZERO:
		var to_home := home_position - global_position
		to_home.y = 0.0
		if to_home.length() > 0.15:
			desired_velocity = to_home.normalized() * return_speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, 8.0 * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, 8.0 * delta)
	velocity.y = 0.0

	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		model.rotation.y = atan2(velocity.x, velocity.z)

	move_and_slide()
	global_position.y = ground_y
	velocity.y = 0.0


func _resolve_target() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target == null:
		target = get_tree().get_first_node_in_group("player_2_5d_test") as Node3D
