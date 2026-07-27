class_name KayKitLayerWallVisuals
extends RefCounted

const MODEL_PATHS: Dictionary = {
	"wall": "res://assets/kaykit/Katman2_TasZindan/wall.fbx",
	"corner": "res://assets/kaykit/Katman2_TasZindan/wall_corner.fbx",
	"corner_small": "res://assets/kaykit/Katman2_TasZindan/wall_corner_small.fbx",
	"doorway": "res://assets/kaykit/Katman2_TasZindan/wall_doorway.fbx",
}

var enabled := true
var active_layer := 0
var _scene_cache: Dictionary = {}


func set_active_layer(layer_index: int) -> void:
	active_layer = layer_index


func decorate_wall_body(wall_body: Node3D, target_size: Vector3, axis: String, flip := false) -> bool:
	if not enabled or wall_body == null:
		return false
	var packed := _load_model("wall")
	if packed == null:
		return false

	var wrapper := Node3D.new()
	wrapper.name = "KayKitWallVisuals"
	wall_body.add_child(wrapper)
	wrapper.rotation.y = (0.0 if axis == "x" else PI * 0.5) + (PI if flip else 0.0)

	var first_instance := packed.instantiate() as Node3D
	if first_instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(first_instance)
	if not _has_textured_mesh(first_instance):
		wrapper.queue_free()
		return false

	var bounds := _combined_bounds(first_instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return false

	var target_length := target_size.x if axis == "x" else target_size.z
	var height_scale := target_size.y / bounds.size.y
	var natural_length := maxf(bounds.size.x * height_scale, 0.01)
	var module_count := maxi(ceili(target_length / natural_length), 1)
	var module_length := target_length / float(module_count)
	var model_scale := Vector3(
		module_length / bounds.size.x,
		height_scale,
		target_size.z / bounds.size.z if axis == "x" else target_size.x / bounds.size.z
	)

	for index in range(module_count):
		var instance := first_instance
		if index > 0:
			instance = packed.instantiate() as Node3D
			if instance == null:
				continue
			wrapper.add_child(instance)
		var module_center := -target_length * 0.5 + module_length * (float(index) + 0.5)
		_fit_instance(instance, bounds, model_scale, Vector3(module_center, 0.0, 0.0))

	_tag_visual(wrapper)
	return true


func add_doorway(
	parent: Node,
	world_center: Vector3,
	axis: String,
	opening_width: float,
	height: float,
	thickness: float
) -> bool:
	var target_size := Vector3(opening_width, height, thickness)
	return _add_fitted_visual(parent, "doorway", "KayKitDoorway", world_center, axis, target_size, true)


func add_corner(
	parent: Node,
	world_center: Vector3,
	yaw: float,
	height: float,
	use_small_corner: bool
) -> Node3D:
	if not enabled:
		return null
	var model_id := "corner_small" if use_small_corner else "corner"
	var packed := _load_model(model_id)
	if packed == null:
		return null

	var wrapper := Node3D.new()
	wrapper.name = "KayKitCorner"
	parent.add_child(wrapper)
	wrapper.global_position = world_center
	wrapper.rotation.y = yaw

	var instance := packed.instantiate() as Node3D
	if instance == null:
		wrapper.queue_free()
		return null
	wrapper.add_child(instance)
	if not _has_textured_mesh(instance):
		wrapper.queue_free()
		return null

	var bounds := _combined_bounds(instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return null
	var uniform_scale := height / bounds.size.y
	_fit_instance(instance, bounds, Vector3.ONE * uniform_scale, Vector3.ZERO)
	_tag_visual(wrapper)
	return wrapper


func _add_fitted_visual(
	parent: Node,
	model_id: String,
	node_name: String,
	world_center: Vector3,
	axis: String,
	target_size: Vector3,
	hide_door_leaf: bool
) -> bool:
	if not enabled:
		return false
	var packed := _load_model(model_id)
	if packed == null:
		return false

	var wrapper := Node3D.new()
	wrapper.name = node_name
	parent.add_child(wrapper)
	wrapper.global_position = world_center
	wrapper.rotation.y = 0.0 if axis == "x" else PI * 0.5

	var instance := packed.instantiate() as Node3D
	if instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(instance)
	if hide_door_leaf:
		_hide_door_leaf(instance)
	if not _has_textured_mesh(instance):
		wrapper.queue_free()
		return false

	var bounds := _combined_bounds(instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return false
	var model_scale := Vector3(
		target_size.x / bounds.size.x,
		target_size.y / bounds.size.y,
		target_size.z / bounds.size.z
	)
	_fit_instance(instance, bounds, model_scale, Vector3.ZERO)
	_tag_visual(wrapper)
	return true


func _load_model(model_id: String) -> PackedScene:
	var cached := _scene_cache.get(model_id) as PackedScene
	if cached != null:
		return cached
	var path := String(MODEL_PATHS.get(model_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := ResourceLoader.load(path) as PackedScene
	if packed != null:
		_scene_cache[model_id] = packed
	return packed


func _fit_instance(instance: Node3D, bounds: AABB, model_scale: Vector3, target_center: Vector3) -> void:
	var source_center := bounds.position + bounds.size * 0.5
	instance.scale = model_scale
	instance.position = target_center - Vector3(
		source_center.x * model_scale.x,
		source_center.y * model_scale.y,
		source_center.z * model_scale.z
	)


func _combined_bounds(root_node: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var root_inverse := root_node.global_transform.affine_inverse()
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or not mesh_instance.visible:
			continue
		var local_transform := root_inverse * mesh_instance.global_transform
		var mesh_bounds := _transformed_aabb(mesh_instance.get_aabb(), local_transform)
		result = result.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	return result


func _transformed_aabb(bounds: AABB, xform: Transform3D) -> AABB:
	var first := xform * bounds.get_endpoint(0)
	var result := AABB(first, Vector3.ZERO)
	for index in range(1, 8):
		result = result.expand(xform * bounds.get_endpoint(index))
	return result


func _bounds_are_valid(bounds: AABB) -> bool:
	return bounds.size.x > 0.001 and bounds.size.y > 0.001 and bounds.size.z > 0.001


func _has_textured_mesh(root_node: Node3D) -> bool:
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or not mesh_instance.visible:
			continue
		for surface_index in range(mesh_instance.get_surface_override_material_count()):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				return true
	return false


func _hide_door_leaf(root_node: Node3D) -> void:
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and String(mesh_instance.name).ends_with("_door"):
			mesh_instance.visible = false


func _set_primitive_visual_visible(wall_body: Node3D, visible: bool) -> void:
	for child in wall_body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = visible


func _tag_visual(wrapper: Node3D) -> void:
	wrapper.add_to_group("kaykit_layer_wall_visual")
	if active_layer == 1 or active_layer == 2:
		wrapper.add_to_group("kaykit_layer%d_visual" % active_layer)
