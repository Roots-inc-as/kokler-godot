class_name Layer1CaveVisuals
extends RefCounted

const MODEL_PATHS: Dictionary = {
	"wall": "res://assets/third_party/mines_and_caves/layer1/models/wall_caves_a.tscn",
	"corner": "res://assets/third_party/mines_and_caves/layer1/models/wall_caves_corner.tscn",
	"entrance": "res://assets/third_party/mines_and_caves/layer1/models/wall_caves_entrance_a.tscn",
	"ground": "res://assets/third_party/mines_and_caves/layer1/models/ground_cave_a.tscn",
	"rock_a": "res://assets/third_party/mines_and_caves/layer1/models/cave_rocks_a.tscn",
	"rock_b": "res://assets/third_party/mines_and_caves/layer1/models/cave_rocks_b.tscn",
}

const WALL_VISUAL_HEIGHT := 1.28
const WALL_MODULE_LENGTH := 2.6
const FLOOR_MODULE_SIZE := 4.5
const FLOOR_VISUAL_THICKNESS := 0.12

var enabled := true
var _scene_cache: Dictionary = {}


func decorate_wall_body(wall_body: Node3D, target_size: Vector3, axis: String) -> bool:
	if not enabled or wall_body == null:
		return false
	var packed := _load_model("wall")
	if packed == null:
		return false

	var wrapper := Node3D.new()
	wrapper.name = "Layer1CaveWallVisuals"
	wall_body.add_child(wrapper)
	wrapper.rotation.y = 0.0 if axis == "x" else PI * 0.5

	var first_instance := _instantiate_visual(packed)
	if first_instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(first_instance)

	var bounds := _combined_bounds(first_instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return false

	var target_length := target_size.x if axis == "x" else target_size.z
	var module_count := maxi(ceili(target_length / WALL_MODULE_LENGTH), 1)
	var module_length := target_length / float(module_count)
	var visual_height := minf(target_size.y, WALL_VISUAL_HEIGHT)
	var visual_thickness := maxf(target_size.z if axis == "x" else target_size.x, 0.42)
	var model_scale := Vector3(
		module_length / bounds.size.x,
		visual_height / bounds.size.y,
		visual_thickness / bounds.size.z
	)

	for index in range(module_count):
		var instance := first_instance
		if index > 0:
			instance = _instantiate_visual(packed)
			if instance == null:
				continue
			wrapper.add_child(instance)
		var module_center := -target_length * 0.5 + module_length * (float(index) + 0.5)
		_fit_instance(instance, bounds, model_scale, Vector3(module_center, -0.04, 0.0))

	_tag_visual(wrapper, "layer1_cave_wall_visual")
	_set_primitive_wall_visible(wall_body, false)
	return true


func decorate_floor(floor_visual: Node3D, target_size: Vector3) -> bool:
	if not enabled or floor_visual == null or floor_visual.get_parent() == null:
		return false
	var packed := _load_model("ground")
	if packed == null:
		return false

	var wrapper := Node3D.new()
	wrapper.name = "Layer1CaveFloorVisuals"
	floor_visual.get_parent().add_child(wrapper)
	wrapper.global_transform = floor_visual.global_transform

	var first_instance := _instantiate_visual(packed)
	if first_instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(first_instance)

	var bounds := _combined_bounds(first_instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return false

	var x_count := maxi(ceili(target_size.x / FLOOR_MODULE_SIZE), 1)
	var z_count := maxi(ceili(target_size.z / FLOOR_MODULE_SIZE), 1)
	var tile_width := target_size.x / float(x_count)
	var tile_depth := target_size.z / float(z_count)
	var model_scale := Vector3(
		tile_width / bounds.size.x,
		FLOOR_VISUAL_THICKNESS / bounds.size.y,
		tile_depth / bounds.size.z
	)

	var tile_index := 0
	for x_index in range(x_count):
		for z_index in range(z_count):
			var instance := first_instance
			if tile_index > 0:
				instance = _instantiate_visual(packed)
				if instance == null:
					tile_index += 1
					continue
				wrapper.add_child(instance)
			var tile_center := Vector3(
				-target_size.x * 0.5 + tile_width * (float(x_index) + 0.5),
				0.08,
				-target_size.z * 0.5 + tile_depth * (float(z_index) + 0.5)
			)
			_fit_instance(instance, bounds, model_scale, tile_center)
			tile_index += 1

	_tag_visual(wrapper, "layer1_cave_floor_visual")
	if floor_visual is GeometryInstance3D:
		(floor_visual as GeometryInstance3D).visible = false
	return true


func add_entrance(
	parent: Node,
	world_center: Vector3,
	axis: String,
	opening_width: float,
	height: float,
	thickness: float
) -> bool:
	var target_size := Vector3(
		opening_width,
		minf(height, WALL_VISUAL_HEIGHT),
		maxf(thickness, 0.52)
	)
	return _add_fitted_visual(
		parent,
		"entrance",
		"Layer1CaveEntrance",
		world_center,
		0.0 if axis == "x" else PI * 0.5,
		target_size,
		"layer1_cave_entrance_visual"
	)


func add_corner(parent: Node, world_center: Vector3, yaw: float, height: float, inner := false) -> bool:
	var visual_height := minf(height, WALL_VISUAL_HEIGHT)
	var target_size := Vector3(0.68, visual_height, 0.68)
	return _add_fitted_visual(
		parent,
		"corner",
		"Layer1CaveInnerCorner" if inner else "Layer1CaveOuterCorner",
		world_center,
		yaw,
		target_size,
		"layer1_cave_corner_visual"
	)


func add_rock(parent: Node, world_position: Vector3, yaw: float, height: float, use_variant_b: bool) -> bool:
	var model_id := "rock_b" if use_variant_b else "rock_a"
	var packed := _load_model(model_id)
	if not enabled or packed == null:
		return false
	var wrapper := Node3D.new()
	wrapper.name = "Layer1CaveRockB" if use_variant_b else "Layer1CaveRockA"
	parent.add_child(wrapper)
	wrapper.global_position = world_position
	wrapper.rotation.y = yaw

	var instance := _instantiate_visual(packed)
	if instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(instance)
	var bounds := _combined_bounds(instance)
	if not _bounds_are_valid(bounds):
		wrapper.queue_free()
		return false
	var uniform_scale := height / bounds.size.y
	_fit_instance(instance, bounds, Vector3.ONE * uniform_scale, Vector3(0.0, height * 0.5, 0.0))
	_tag_visual(wrapper, "layer1_cave_decor_visual")
	return true


func _add_fitted_visual(
	parent: Node,
	model_id: String,
	node_name: String,
	world_center: Vector3,
	yaw: float,
	target_size: Vector3,
	specific_group: String
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
	wrapper.rotation.y = yaw

	var instance := _instantiate_visual(packed)
	if instance == null:
		wrapper.queue_free()
		return false
	wrapper.add_child(instance)
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
	_tag_visual(wrapper, specific_group)
	return true


func _instantiate_visual(packed: PackedScene) -> Node3D:
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	if instance is CollisionObject3D:
		instance.free()
		return null
	if not instance.find_children("*", "CollisionObject3D", true, false).is_empty():
		instance.free()
		return null
	if not instance.find_children("*", "CollisionShape3D", true, false).is_empty():
		instance.free()
		return null
	if not _has_textured_mesh(instance):
		instance.free()
		return null
	return instance


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
	for mesh_instance in _mesh_nodes(root_node):
		var local_transform := root_inverse * mesh_instance.global_transform
		var mesh_bounds := _transformed_aabb(mesh_instance.get_aabb(), local_transform)
		result = result.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	return result


func _mesh_nodes(root_node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		result.append(root_node as MeshInstance3D)
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			result.append(mesh_instance)
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
	for mesh_instance in _mesh_nodes(root_node):
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				return true
	return false


func _set_primitive_wall_visible(wall_body: Node3D, visible: bool) -> void:
	for child in wall_body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = visible


func _tag_visual(wrapper: Node3D, specific_group: String) -> void:
	wrapper.add_to_group("layer1_cave_visual")
	wrapper.add_to_group(specific_group)
