extends Node3D

const RAT_SCENE := preload("res://scenes/blind_rat_2_5d.tscn")
const KEY_SCRIPT := preload("res://scripts/key_pickup_2_5d.gd")
const EXIT_SCRIPT := preload("res://scripts/exit_gate_2_5d.gd")
const LORE_SCRIPT := preload("res://scripts/lore_trigger_3d.gd")

const WAKE_MESSAGE := "Toprak nefes almıyor. Dinliyor."
const MAP_MESSAGE := "Kökaltı gerçek. İnme. Geri dön."
const SHRINE_MESSAGE := "Haritalar yukarıdakiler içindir. Aşağıda yollar canlıdır."
const KEY_MESSAGE := "Bir kapı açıldı. Bir şey seni içeri saydı."
const LOCKED_EXIT_MESSAGE := "Anahtar olmadan Kökaltı seni bırakmaz."
const SEALED_DOOR_MESSAGE := "Bazı kapılar açılmaz. Seni bekler."
const VICTORY_MESSAGE := "Şimdilik kaçtın. Ama Kökler seni hatırlıyor."
const DEATH_MESSAGE := "Asha yeniden hatırlıyor..."

const WALL_THICKNESS := 0.34
const WALL_HEIGHT := 1.35
const DOOR_GAP := 2.0
const FLOOR_THICKNESS := 0.08
# ─── RASTGELE LAYOUT SABİTLERİ ───
const ROOM_SPACING_X := 7.5      # Odalar arası yatay mesafe
const BRANCH_SPACING_Z := 6.5    # Dal odanın derinliği
const MIN_ROOM_SIZE := Vector2(4.0, 4.0)
const MAX_ROOM_SIZE := Vector2(5.5, 5.0)

# Oda tipi havuzu — her run'da bunlardan seçilecek
const ROOM_TYPE_WAKE := "wake"
const ROOM_TYPE_MAP := "map"
const ROOM_TYPE_STORAGE := "storage"
const ROOM_TYPE_SHRINE := "shrine"
const ROOM_TYPE_KEY := "key"
const ROOM_TYPE_EXIT := "exit"
const ROOM_TYPE_LORE := "lore"
const ROOM_TYPE_EMPTY := "empty"

@export var player_path: NodePath

@onready var hp_label: Label = $UI/HPLabel
@onready var key_label: Label = $UI/KeyLabel
@onready var dash_label: Label = $UI/DashLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var victory_panel: ColorRect = $UI/VictoryPanel
@onready var victory_label: Label = $UI/VictoryPanel/VictoryLabel

var generated_root: Node3D
var player: Node3D
var has_key := false
var victory := false
var restarting := false
var message_token := 0
# ─── Rastgele layout için yeni değişkenler ───
var generated_rooms: Array[Dictionary] = []  # her oda: {id, type, center, size}

var floor_material: StandardMaterial3D
var corridor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var root_material: StandardMaterial3D
var parchment_material: StandardMaterial3D
var ink_material: StandardMaterial3D
var crate_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var exit_material: StandardMaterial3D
var pale_stone_material: StandardMaterial3D
var grey_hint_material: StandardMaterial3D
var lumen_material: StandardMaterial3D
var sealed_material: StandardMaterial3D


func _ready() -> void:
	print(">>>>>> 2.5D SCRIPT CALISTI <<<<<<")
	add_to_group("mini_story_manager_2_5d")
	_resolve_player()
	_setup_ui()
	_create_materials()
	_build_story_map()
	_wire_player()
	call_deferred("show_message", WAKE_MESSAGE, 4.0)


func collect_key() -> void:
	if has_key or victory or restarting:
		return
	has_key = true
	key_label.text = "Anahtar: Alındı"
	show_message(KEY_MESSAGE, 3.5)


func has_player_key() -> bool:
	return has_key


func try_exit() -> void:
	if victory or restarting:
		return
	if not has_key:
		show_message(LOCKED_EXIT_MESSAGE, 2.8)
		return

	victory = true
	message_token += 1
	message_label.visible = false
	victory_label.text = VICTORY_MESSAGE
	victory_panel.visible = true


func player_died() -> void:
	if victory or restarting:
		return

	restarting = true
	show_message(DEATH_MESSAGE, 1.0)
	await get_tree().create_timer(1.15).timeout
	get_tree().reload_current_scene()


func is_run_locked() -> bool:
	return victory or restarting


func show_message(text: String, duration := 3.0) -> void:
	message_token += 1
	var token := message_token
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if token == message_token and not victory_panel.visible:
		message_label.visible = false


func _setup_ui() -> void:
	key_label.text = "Anahtar: Yok"
	dash_label.text = "Dash: Hazır"
	message_label.visible = false
	victory_panel.visible = false


func _resolve_player() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player_2_5d") as Node3D


func _wire_player() -> void:
	if player == null:
		return

	if player.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_player_health_changed")
		if not player.is_connected("health_changed", health_callable):
			player.connect("health_changed", health_callable)

	if player.has_signal("dash_cooldown_changed"):
		var dash_callable := Callable(self, "_on_player_dash_cooldown_changed")
		if not player.is_connected("dash_cooldown_changed", dash_callable):
			player.connect("dash_cooldown_changed", dash_callable)

	if player.has_signal("died"):
		var died_callable := Callable(self, "player_died")
		if not player.is_connected("died", died_callable):
			player.connect("died", died_callable)

	if player.has_method("get_health_state"):
		var health_state: Dictionary = player.get_health_state()
		_on_player_health_changed(int(health_state.get("current", 0)), int(health_state.get("max", 0)))


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]


func _on_player_dash_cooldown_changed(is_ready: bool, remaining: float) -> void:
	dash_label.text = "Dash: Hazır" if is_ready else "Dash: %.1f" % remaining


func _build_story_map() -> void:
	randomize()
	
	var previous := get_node_or_null("GeneratedStoryMap")
	if previous:
		previous.queue_free()

	generated_root = Node3D.new()
	generated_root.name = "GeneratedStoryMap"
	add_child(generated_root)

	_add_rooms_and_corridors()
	
	# Oyuncuyu ilk odaya (start) ışınla
	if player and generated_rooms.size() > 0:
		var start_center: Vector3 = generated_rooms[0]["center"]
		player.global_position = Vector3(start_center.x, 0.0, start_center.z)
	
	_add_props_per_room()
	_spawn_random_rats()
	_spawn_key_in_random_room()
	_spawn_exit_in_last_room()
	_add_room_lights_random()


func _add_rooms_and_corridors() -> void:
	generated_rooms.clear()
	
	# Kaç oda? 4-6 arası rastgele
	var room_count := randi_range(4, 6)
	print(">>> RASTGELE 2.5D LAYOUT: ", room_count, " oda")
	
	# Ana koridorda odalar — soldan sağa
	for i in range(room_count):
		var room_size := Vector2(
			randf_range(MIN_ROOM_SIZE.x, MAX_ROOM_SIZE.x),
			randf_range(MIN_ROOM_SIZE.y, MAX_ROOM_SIZE.y)
		)
		var center := Vector3(i * ROOM_SPACING_X, 0.0, 0.0)
		var room_type := ROOM_TYPE_EMPTY
		
		if i == 0:
			room_type = ROOM_TYPE_WAKE
		elif i == room_count - 1:
			room_type = ROOM_TYPE_EXIT
		else:
			# Orta odalardan birine rastgele tip ata
			var middle_types := [ROOM_TYPE_MAP, ROOM_TYPE_STORAGE, ROOM_TYPE_SHRINE, ROOM_TYPE_LORE]
			room_type = middle_types[randi() % middle_types.size()]
		
		generated_rooms.append({
			"id": "room_%d" % i,
			"type": room_type,
			"center": center,
			"size": room_size,
			"in_main_chain": true,
		})
	
	# Dal oda — anahtar burada olacak
	# Ana koridordaki rastgele bir odanın altına (z yönünde)
	var branch_parent_index := randi_range(1, room_count - 2)
	var parent_room: Dictionary = generated_rooms[branch_parent_index]
	var parent_center: Vector3 = parent_room["center"]
	var branch_center := Vector3(parent_center.x, 0.0, BRANCH_SPACING_Z)
	var branch_size := Vector2(
		randf_range(MIN_ROOM_SIZE.x, MAX_ROOM_SIZE.x),
		randf_range(MIN_ROOM_SIZE.y, MAX_ROOM_SIZE.y)
	)
	generated_rooms.append({
		"id": "branch",
		"type": ROOM_TYPE_KEY,
		"center": branch_center,
		"size": branch_size,
		"in_main_chain": false,
		"branch_parent_index": branch_parent_index,
	})
	
	# Şimdi odaları ve koridorları çiz
	for i in range(generated_rooms.size()):
		var room: Dictionary = generated_rooms[i]
		var center: Vector3 = room["center"]
		var size: Vector2 = room["size"]
		var openings := _calc_openings_for_room(i)
		_add_room(
			room["id"],
			Vector2(center.x, center.z),
			size,
			openings
		)
	
	# Ana koridor bağlantıları
	for i in range(room_count - 1):
		var a: Dictionary = generated_rooms[i]
		var b: Dictionary = generated_rooms[i + 1]
		var a_center: Vector3 = a["center"]
		var b_center: Vector3 = b["center"]
		var a_size: Vector2 = a["size"]
		var b_size: Vector2 = b["size"]
		var x_start := a_center.x + a_size.x * 0.5
		var x_end := b_center.x - b_size.x * 0.5
		_add_corridor_x("corridor_%d" % i, x_start, x_end, 0.0, 1.7)
	
	# Dal koridor bağlantısı
	var branch: Dictionary = generated_rooms[generated_rooms.size() - 1]
	var branch_parent: Dictionary = generated_rooms[branch["branch_parent_index"]]
	var branch_parent_center: Vector3 = branch_parent["center"]
	var branch_parent_size: Vector2 = branch_parent["size"]
	var branch_center_vec: Vector3 = branch["center"]
	var branch_size_vec: Vector2 = branch["size"]
	var z_start := branch_parent_center.z + branch_parent_size.y * 0.5
	var z_end := branch_center_vec.z - branch_size_vec.y * 0.5
	_add_corridor_z("branch_corridor", branch_parent_center.x, z_start, z_end, 1.7)


# Bir odanın hangi yönlerinin açık olması gerektiğini hesaplar
func _calc_openings_for_room(index: int) -> Dictionary:
	var openings := {}
	var room: Dictionary = generated_rooms[index]
	var is_branch: bool = not bool(room.get("in_main_chain", true))
	
	if is_branch:
		# Dal oda — sadece yukarı açık (ana koridora doğru)
		openings["up"] = true
		return openings
	
	var main_chain_count := generated_rooms.size() - 1  # son eleman dal
	
	# Ana koridordaki odalar
	if index > 0:
		openings["left"] = true
	if index < main_chain_count - 1:
		openings["right"] = true
	
	# Bu oda dal'ın parent'ı mı?
	var branch: Dictionary = generated_rooms[generated_rooms.size() - 1]
	if branch.get("branch_parent_index", -1) == index:
		openings["down"] = true
	
	return openings















func _spawn_rat(position: Vector3) -> void:
	var rat := RAT_SCENE.instantiate() as Node3D
	rat.global_position = position
	generated_root.add_child(rat)


func _add_lumen_hint(position: Vector3) -> void:
	_add_cylinder("LumenStem", position + Vector3(0.0, 0.24, 0.0), 0.035, 0.46, lumen_material, Vector3(1.0, 1.0, 1.0))
	_add_sphere("LumenGlow", position + Vector3(0.0, 0.52, 0.0), 0.18, lumen_material, Vector3(1.0, 0.75, 1.0))
	_add_omni_light("FaintLumenLight", position + Vector3(0.0, 0.9, 0.0), Color(0.42, 0.78, 0.68, 1.0), 0.72, 3.2)


func _add_key_pickup(position: Vector3) -> void:
	var area := Area3D.new()
	area.name = "MutedGoldKeyPickup"
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.2, 1.1, 1.2)
	shape.shape = box_shape
	area.add_child(shape)

	var key_visual := Node3D.new()
	key_visual.name = "KeyVisual"
	area.add_child(key_visual)
	_add_cylinder_to(key_visual, "KeyBow", Vector3(-0.18, 0.02, 0.0), 0.16, 0.08, gold_material, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0.0, 0.0))
	_add_visual_box_to(key_visual, "KeyShaft", Vector3(0.18, 0.0, 0.0), Vector3(0.48, 0.08, 0.08), gold_material)
	_add_visual_box_to(key_visual, "KeyTooth", Vector3(0.43, -0.02, 0.13), Vector3(0.14, 0.08, 0.24), gold_material)

	area.set_script(KEY_SCRIPT)
	generated_root.add_child(area)


func _add_exit_trigger(position: Vector3) -> void:
	var area := Area3D.new()
	area.name = "ForgottenExitTrigger"
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.8, 1.1)
	shape.shape = box_shape
	area.add_child(shape)

	area.set_script(EXIT_SCRIPT)
	generated_root.add_child(area)


func _add_lore_trigger(trigger_name: String, position: Vector3, size: Vector3, text: String) -> void:
	var area := Area3D.new()
	area.name = trigger_name
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	area.add_child(shape)

	area.set_script(LORE_SCRIPT)
	area.set("message", text)
	area.set("duration", 4.0)
	generated_root.add_child(area)


func _add_room(room_name: String, center: Vector2, size: Vector2, openings: Dictionary) -> void:
	_add_visual_box(room_name + "Floor", Vector3(center.x, -FLOOR_THICKNESS * 0.5, center.y), Vector3(size.x, FLOOR_THICKNESS, size.y), floor_material)

	var left_x := center.x - size.x * 0.5 - WALL_THICKNESS * 0.5
	var right_x := center.x + size.x * 0.5 + WALL_THICKNESS * 0.5
	var top_z := center.y - size.y * 0.5 - WALL_THICKNESS * 0.5
	var bottom_z := center.y + size.y * 0.5 + WALL_THICKNESS * 0.5
	var x_start := center.x - size.x * 0.5
	var x_end := center.x + size.x * 0.5
	var z_start := center.y - size.y * 0.5
	var z_end := center.y + size.y * 0.5

	_add_horizontal_wall(room_name + "NorthWall", top_z, x_start, x_end, center.x, openings.has("up"))
	_add_horizontal_wall(room_name + "SouthWall", bottom_z, x_start, x_end, center.x, openings.has("down"))
	_add_vertical_wall(room_name + "WestWall", left_x, z_start, z_end, center.y, openings.has("left"))
	_add_vertical_wall(room_name + "EastWall", right_x, z_start, z_end, center.y, openings.has("right"))


func _add_corridor_x(corridor_name: String, x_start: float, x_end: float, z: float, width: float) -> void:
	var length := x_end - x_start
	var center_x := (x_start + x_end) * 0.5
	_add_visual_box(corridor_name + "Floor", Vector3(center_x, -FLOOR_THICKNESS * 0.5, z), Vector3(length, FLOOR_THICKNESS, width), corridor_material)
	_add_static_box(corridor_name + "NorthWall", Vector3(center_x, WALL_HEIGHT * 0.5, z - width * 0.5 - WALL_THICKNESS * 0.5), Vector3(length, WALL_HEIGHT, WALL_THICKNESS), wall_material)
	_add_static_box(corridor_name + "SouthWall", Vector3(center_x, WALL_HEIGHT * 0.5, z + width * 0.5 + WALL_THICKNESS * 0.5), Vector3(length, WALL_HEIGHT, WALL_THICKNESS), wall_material)


func _add_corridor_z(corridor_name: String, x: float, z_start: float, z_end: float, width: float) -> void:
	var length := z_end - z_start
	var center_z := (z_start + z_end) * 0.5
	_add_visual_box(corridor_name + "Floor", Vector3(x, -FLOOR_THICKNESS * 0.5, center_z), Vector3(width, FLOOR_THICKNESS, length), corridor_material)
	_add_static_box(corridor_name + "WestWall", Vector3(x - width * 0.5 - WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, WALL_HEIGHT, length), wall_material)
	_add_static_box(corridor_name + "EastWall", Vector3(x + width * 0.5 + WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, WALL_HEIGHT, length), wall_material)


func _add_horizontal_wall(wall_name: String, z: float, x_start: float, x_end: float, opening_center: float, has_opening: bool) -> void:
	if not has_opening:
		_add_static_box(wall_name, Vector3((x_start + x_end) * 0.5, WALL_HEIGHT * 0.5, z), Vector3(x_end - x_start, WALL_HEIGHT, WALL_THICKNESS), wall_material)
		return
	var left_end := opening_center - DOOR_GAP * 0.5
	var right_start := opening_center + DOOR_GAP * 0.5
	_add_wall_segment(wall_name + "A", Vector3((x_start + left_end) * 0.5, WALL_HEIGHT * 0.5, z), Vector3(left_end - x_start, WALL_HEIGHT, WALL_THICKNESS))
	_add_wall_segment(wall_name + "B", Vector3((right_start + x_end) * 0.5, WALL_HEIGHT * 0.5, z), Vector3(x_end - right_start, WALL_HEIGHT, WALL_THICKNESS))


func _add_vertical_wall(wall_name: String, x: float, z_start: float, z_end: float, opening_center: float, has_opening: bool) -> void:
	if not has_opening:
		_add_static_box(wall_name, Vector3(x, WALL_HEIGHT * 0.5, (z_start + z_end) * 0.5), Vector3(WALL_THICKNESS, WALL_HEIGHT, z_end - z_start), wall_material)
		return
	var top_end := opening_center - DOOR_GAP * 0.5
	var bottom_start := opening_center + DOOR_GAP * 0.5
	_add_wall_segment(wall_name + "A", Vector3(x, WALL_HEIGHT * 0.5, (z_start + top_end) * 0.5), Vector3(WALL_THICKNESS, WALL_HEIGHT, top_end - z_start))
	_add_wall_segment(wall_name + "B", Vector3(x, WALL_HEIGHT * 0.5, (bottom_start + z_end) * 0.5), Vector3(WALL_THICKNESS, WALL_HEIGHT, z_end - bottom_start))


func _add_wall_segment(wall_name: String, position: Vector3, size: Vector3) -> void:
	if size.x <= 0.08 or size.z <= 0.08:
		return
	_add_static_box(wall_name, position, size, wall_material)


func _add_room_lights() -> void:
	_add_omni_light("WakeWarmth", Vector3(0.0, 3.1, 0.0), Color(0.74, 0.48, 0.28, 1.0), 0.65, 7.0)
	_add_omni_light("MapDustLight", Vector3(6.6, 3.0, 0.0), Color(0.82, 0.64, 0.42, 1.0), 0.55, 6.0)
	_add_omni_light("ShrineLowLight", Vector3(18.6, 3.1, 0.0), Color(0.72, 0.52, 0.34, 1.0), 0.45, 6.0)
	_add_omni_light("ExitColdLight", Vector3(37.3, 3.2, -1.0), Color(0.55, 0.82, 0.74, 1.0), 0.85, 6.5)


func _add_omni_light(light_name: String, position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	generated_root.add_child(light)


func _add_static_box(box_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position

	var mesh_instance := _make_box_mesh("Visual", size, material)
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	generated_root.add_child(body)
	return body


func _add_visual_box(box_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := _make_box_mesh(box_name, size, material)
	mesh_instance.position = position
	generated_root.add_child(mesh_instance)
	return mesh_instance


func _add_visual_box_to(parent: Node3D, box_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := _make_box_mesh(box_name, size, material)
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance


func _make_box_mesh(mesh_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance


func _add_cylinder(cylinder_name: String, position: Vector3, radius: float, height: float, material: Material, mesh_scale: Vector3, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := _make_cylinder_mesh(cylinder_name, radius, height, material)
	mesh_instance.position = position
	mesh_instance.scale = mesh_scale
	mesh_instance.rotation = rotation
	generated_root.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder_to(parent: Node3D, cylinder_name: String, position: Vector3, radius: float, height: float, material: Material, mesh_scale: Vector3, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := _make_cylinder_mesh(cylinder_name, radius, height, material)
	mesh_instance.position = position
	mesh_instance.scale = mesh_scale
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	return mesh_instance


func _make_cylinder_mesh(mesh_name: String, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance


func _add_sphere(sphere_name: String, position: Vector3, radius: float, material: Material, mesh_scale: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = sphere_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = mesh_scale
	mesh_instance.material_override = material
	generated_root.add_child(mesh_instance)
	return mesh_instance


func _create_materials() -> void:
	floor_material = _material(Color(0.18, 0.12, 0.075, 1.0))
	corridor_material = _material(Color(0.13, 0.09, 0.06, 1.0))
	wall_material = _material(Color(0.065, 0.052, 0.044, 1.0))
	dark_stone_material = _material(Color(0.105, 0.09, 0.075, 1.0))
	root_material = _material(Color(0.16, 0.09, 0.045, 1.0))
	parchment_material = _material(Color(0.68, 0.58, 0.38, 1.0))
	ink_material = _material(Color(0.12, 0.08, 0.045, 1.0))
	crate_material = _material(Color(0.22, 0.14, 0.08, 1.0))
	gold_material = _material(Color(0.72, 0.56, 0.18, 1.0))
	exit_material = _material(Color(0.55, 0.78, 0.68, 0.78), true)
	pale_stone_material = _material(Color(0.48, 0.52, 0.48, 1.0))
	grey_hint_material = _material(Color(0.30, 0.31, 0.30, 1.0))
	lumen_material = _material(Color(0.28, 0.66, 0.58, 1.0))
	sealed_material = _material(Color(0.72, 0.73, 0.69, 1.0))


func _material(color: Color, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
	
	# ─── RASTGELE SPAWN FONKSIYONLARI ───

func _spawn_random_rats() -> void:
	for room in generated_rooms:
		if room["type"] in [ROOM_TYPE_WAKE, ROOM_TYPE_EXIT]:
			continue  # başlangıç ve çıkışta düşman yok
		
		var rat_count := randi_range(1, 2)
		if room["type"] == ROOM_TYPE_KEY:
			rat_count = randi_range(2, 3)  # anahtar odasında daha zor
		
		var center: Vector3 = room["center"]
		var size: Vector2 = room["size"]
		
		for i in range(rat_count):
			var offset := Vector3(
				randf_range(-size.x * 0.3, size.x * 0.3),
				0.0,
				randf_range(-size.y * 0.3, size.y * 0.3)
			)
			_spawn_rat(center + offset)


func _spawn_key_in_random_room() -> void:
	# Anahtar dal odadadır (zaten type = KEY olarak ayarlandı)
	for room in generated_rooms:
		if room["type"] == ROOM_TYPE_KEY:
			var center: Vector3 = room["center"]
			_add_key_pickup(Vector3(center.x, 0.75, center.z))
			break


func _spawn_exit_in_last_room() -> void:
	for room in generated_rooms:
		if room["type"] == ROOM_TYPE_EXIT:
			var center: Vector3 = room["center"]
			var size: Vector2 = room["size"]
			# Trigger'ı kapının önüne (arka duvardan biraz öne) koy
			var back_z := -size.y * 0.5 + 0.6
			_add_exit_trigger(Vector3(center.x, 0.8, center.z + back_z))
			break


func _add_room_lights_random() -> void:
	for room in generated_rooms:
		var center: Vector3 = room["center"]
		var light_color := Color(0.74, 0.48, 0.28, 1.0)  # varsayılan sıcak
		
		match room["type"]:
			ROOM_TYPE_EXIT:
				light_color = Color(0.55, 0.82, 0.74, 1.0)  # soğuk yeşil
			ROOM_TYPE_KEY:
				light_color = Color(0.82, 0.64, 0.42, 1.0)  # altın
			ROOM_TYPE_LORE:
				light_color = Color(0.72, 0.52, 0.34, 1.0)  # solgun
		
		_add_omni_light(
			"%sLight" % room["id"],
			Vector3(center.x, 3.0, center.z),
			light_color,
			0.55,
			6.5)
			
func _add_props_per_room() -> void:
	for room in generated_rooms:
		var center: Vector3 = room["center"]
		var size: Vector2 = room["size"]
		var type: String = room["type"]
		match type:
			ROOM_TYPE_WAKE:
				_props_wake_chamber(center, size)
			ROOM_TYPE_MAP:
				_props_map_room(center, size)
			ROOM_TYPE_STORAGE:
				_props_storage(center, size)
			ROOM_TYPE_SHRINE:
				_props_shrine(center, size)
			ROOM_TYPE_KEY:
				_props_key_alcove(center, size)
			ROOM_TYPE_EXIT:
				_props_forgotten_exit(center, size)
			ROOM_TYPE_LORE:
				_props_lore_room(center, size)
			_:
				pass


func _props_wake_chamber(center: Vector3, size: Vector2) -> void:
	_add_visual_box("WakeSlabA", center + Vector3(-1.35, 0.035, -1.15), Vector3(1.45, 0.07, 0.7), dark_stone_material)
	_add_visual_box("WakeSlabB", center + Vector3(1.15, 0.04, 1.2), Vector3(1.2, 0.08, 0.9), dark_stone_material)
	_add_visual_box("WakeStone", center + Vector3(-2.0, 0.18, 1.55), Vector3(0.55, 0.36, 0.42), dark_stone_material)
	_add_cylinder("WakePillar", center + Vector3(2.0, 0.62, -1.45), 0.18, 1.25, root_material, Vector3(0.9, 1.0, 0.9))
	_add_lore_trigger("WakeLoreTrigger", center + Vector3(0.0, 0.7, 0.0), Vector3(size.x * 0.8, 1.4, size.y * 0.8), "Toprak nefes almıyor. Dinliyor.")


func _props_map_room(center: Vector3, size: Vector2) -> void:
	_add_static_box("MapTable", center + Vector3(0.0, 0.28, 0.15), Vector3(2.1, 0.55, 1.05), dark_stone_material)
	_add_visual_box("ParchmentMap", center + Vector3(0.0, 0.59, 0.15), Vector3(1.55, 0.035, 0.72), parchment_material)
	_add_visual_box("MapLineA", center + Vector3(-0.25, 0.625, 0.0), Vector3(0.8, 0.025, 0.04), ink_material)
	_add_visual_box("MapLineB", center + Vector3(0.25, 0.626, 0.32), Vector3(0.55, 0.025, 0.04), ink_material)
	_add_visual_box("MapLineC", center + Vector3(0.18, 0.627, -0.08), Vector3(0.04, 0.025, 0.5), ink_material)
	_add_lore_trigger("MapLoreTrigger", center + Vector3(0.0, 0.7, 0.0), Vector3(size.x * 0.8, 1.4, size.y * 0.8), "Kökaltı gerçek. İnme. Geri dön.")


func _props_storage(center: Vector3, size: Vector2) -> void:
	_add_static_box("CrateA", center + Vector3(-1.0, 0.28, 0.6), Vector3(0.75, 0.55, 0.75), crate_material)
	_add_static_box("CrateB", center + Vector3(1.0, 0.22, -0.6), Vector3(0.7, 0.44, 0.65), crate_material)
	_add_visual_box("StorageStone", center + Vector3(0.0, 0.12, 1.0), Vector3(0.9, 0.24, 0.38), dark_stone_material)
	
func _props_shrine(center: Vector3, size: Vector2) -> void:
	_add_static_box("ShrineMarker", center + Vector3(0.0, 0.65, -1.1), Vector3(0.62, 1.3, 0.32), pale_stone_material)
	_add_visual_box("ShrineBase", center + Vector3(0.0, 0.12, -1.1), Vector3(1.25, 0.24, 0.75), dark_stone_material)
	_add_visual_box("ShrineRubble", center + Vector3(-1.35, 0.12, 1.25), Vector3(0.82, 0.24, 0.38), dark_stone_material)
	_add_lore_trigger("ShrineLoreTrigger", center + Vector3(0.0, 0.7, 0.0), Vector3(size.x * 0.8, 1.4, size.y * 0.8), "Haritalar yukaridakiler icindir. Asagida yollar canlidir.")


func _props_key_alcove(center: Vector3, size: Vector2) -> void:
	_add_cylinder("AlcoveRootLeft", center + Vector3(-0.85, 0.72, -0.5), 0.18, 1.45, root_material, Vector3(0.75, 1.0, 0.75))
	_add_cylinder("AlcoveRootRight", center + Vector3(0.85, 0.72, -0.5), 0.18, 1.45, root_material, Vector3(0.75, 1.0, 0.75))
	_add_static_box("KeyPlinth", center + Vector3(0.0, 0.18, 0.5), Vector3(1.2, 0.36, 0.9), dark_stone_material)


func _props_forgotten_exit(center: Vector3, size: Vector2) -> void:
	var back_z := -size.y * 0.5 + 0.3
	_add_static_box("ExitLeftPillar", center + Vector3(-0.85, 0.85, back_z), Vector3(0.42, 1.7, 0.42), pale_stone_material)
	_add_static_box("ExitRightPillar", center + Vector3(0.85, 0.85, back_z), Vector3(0.42, 1.7, 0.42), pale_stone_material)
	_add_static_box("ExitLintel", center + Vector3(0.0, 1.72, back_z), Vector3(2.15, 0.32, 0.42), pale_stone_material)
	_add_visual_box("ExitGlow", center + Vector3(0.0, 0.82, back_z - 0.09), Vector3(1.18, 1.45, 0.08), exit_material)


func _props_lore_room(center: Vector3, size: Vector2) -> void:
	_add_lumen_hint(center + Vector3(-0.5, 0.05, 0.35))
	_add_visual_box("LoreDampStone", center + Vector3(0.5, 0.08, -0.35), Vector3(1.0, 0.16, 0.42), dark_stone_material)
	_add_lore_trigger("LoreTrigger", center + Vector3(0.0, 0.7, 0.0), Vector3(size.x * 0.8, 1.4, size.y * 0.8), "Bazi kapilar acilmaz. Seni bekler.")
