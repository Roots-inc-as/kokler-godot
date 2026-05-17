extends Node3D
class_name HealthBar3D

@export var width := 0.9
@export var height := 0.08
@export var depth := 0.04
@export var y_offset := 1.15
@export var fill_color := Color(0.65, 0.08, 0.06)
@export var back_color := Color(0.08, 0.05, 0.04)

var _back: MeshInstance3D
var _fill: MeshInstance3D
var _pending_current_hp := -1
var _pending_max_hp := 0


func _ready() -> void:
	position = Vector3(0.0, y_offset, 0.0)
	_back = _make_box("Back", Vector3(width, height, depth), back_color)
	_fill = _make_box("Fill", Vector3(width, height, depth * 1.1), fill_color)
	_fill.position = Vector3(0.0, 0.0, -0.01)
	add_child(_back)
	add_child(_fill)
	if _pending_current_hp >= 0:
		set_health(_pending_current_hp, _pending_max_hp)


func set_health(current_hp: int, max_hp: int) -> void:
	if not _fill:
		_pending_current_hp = current_hp
		_pending_max_hp = max_hp
		return
	var ratio := 0.0
	if max_hp > 0:
		ratio = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	visible = ratio > 0.0
	_fill.scale.x = ratio
	_fill.position.x = -width * (1.0 - ratio) * 0.5


func _make_box(node_name: String, size: Vector3, material_color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	return instance
