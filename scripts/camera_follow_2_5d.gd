extends Node3D

@export var target_path: NodePath
@export var offset := Vector3(0.0, 13.5, 10.5)
@export var follow_speed := 5.5
@export var orthographic_size := 15.0
@export var fixed_camera_rotation := Vector3(-55.0, 0.0, 0.0)

@onready var camera: Camera3D = $Camera3D

var target: Node3D
# ─── Kamera shake ───
@export var shake_decay := 7.0  # Sallantı ne kadar hızlı sönsün
var shake_strength := 0.0
var shake_max_offset := 0.35    # Maksimum sallantı mesafesi


func _ready() -> void:
	add_to_group("camera_rig_2_5d")
	_resolve_target()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_size
	camera.position = Vector3.ZERO
	camera.rotation_degrees = fixed_camera_rotation
	rotation = Vector3.ZERO

	if target:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_resolve_target()
		if target == null:
			return

	var desired := _desired_position()
	global_position = global_position.lerp(desired, minf(delta * follow_speed, 1.0))
	global_position.y = offset.y
	rotation = Vector3.ZERO
	# Shake offset uygula
	if shake_strength > 0.0:
		shake_strength = maxf(shake_strength - shake_decay * delta, 0.0)
		var shake_offset := Vector3(
			randf_range(-1.0, 1.0) * shake_strength * shake_max_offset,
			randf_range(-1.0, 1.0) * shake_strength * shake_max_offset * 0.5,
			randf_range(-1.0, 1.0) * shake_strength * shake_max_offset
		)
		camera.position = shake_offset
	else:
		camera.position = Vector3.ZERO
	camera.rotation_degrees = fixed_camera_rotation


func _resolve_target() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target == null:
		target = get_tree().get_first_node_in_group("player_2_5d") as Node3D


func _desired_position() -> Vector3:
	return Vector3(
		target.global_position.x + offset.x,
		offset.y,
		target.global_position.z + offset.z
	)

func shake(intensity: float = 1.0) -> void:
	shake_strength = clampf(shake_strength + intensity, 0.0, 1.5)
