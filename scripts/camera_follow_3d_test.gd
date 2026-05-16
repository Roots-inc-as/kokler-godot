extends Camera3D

@export var target_path: NodePath
@export var offset := Vector3(0.0, 7.0, 7.0)
@export var follow_speed := 8.0
@export var look_height := 0.65

var target: Node3D


func _ready() -> void:
	current = true
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target:
		global_position = target.global_position + offset
		_look_at_target()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player_2_5d_test") as Node3D
		return

	var desired_position := target.global_position + offset
	global_position = global_position.lerp(desired_position, minf(delta * follow_speed, 1.0))
	_look_at_target()


func _look_at_target() -> void:
	look_at(target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
