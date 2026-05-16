extends Camera2D

@export var target_path: NodePath
@export var follow_speed := 8.0

var target: Node2D


func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node2D
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
		return

	global_position = global_position.lerp(target.global_position, minf(delta * follow_speed, 1.0))
