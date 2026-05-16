extends Node2D

const BLIND_RAT_SCENE := preload("res://scenes/blind_rat.tscn")
const KEY_SCENE := preload("res://scenes/key_pickup.tscn")
const EXIT_SCENE := preload("res://scenes/exit_gate.tscn")

const LORE_MESSAGE := "Kökaltı seni öldürmez. Seni sadeleştirir."
const ROOM_SPACING := Vector2(340.0, 260.0)
const WALL_THICKNESS := 24.0
const CORRIDOR_WIDTH := 72.0

const COLOR_BACKGROUND := Color(0.035, 0.026, 0.02, 1.0)
const COLOR_FLOOR := Color(0.19, 0.13, 0.08, 1.0)
const COLOR_CORRIDOR := Color(0.15, 0.10, 0.065, 1.0)
const COLOR_WALL := Color(0.075, 0.055, 0.043, 1.0)

@export var player_path: NodePath
@export var game_manager_path: NodePath

var rooms: Array[Dictionary] = []
var connections: Array[Array] = []
var room_by_id := {}
var room_rects := {}
var room_openings := {}

var level_root: Node2D
var floor_root: Node2D
var wall_root: Node2D
var enemy_root: Node2D
var pickup_root: Node2D
var trigger_root: Node2D
var game_manager: Node
var lore_shown := false


func _ready() -> void:
	call_deferred("generate")


func generate() -> void:
	lore_shown = false
	_clear_previous_level()	
	_define_layout()
	_create_roots()
	_create_background()
	_create_corridors()
	_create_rooms()
	_spawn_level_objects()


func _clear_previous_level() -> void:
	var previous := get_node_or_null("GeneratedLevel")
	if previous:
		previous.queue_free()


func _define_layout() -> void:
	rooms = [
		{"id": "start", "name": "Collapsed Root Chamber", "grid": Vector2i(0, 0), "size": Vector2(260, 180), "kind": "start", "rats": 0},
		{"id": "tunnel", "name": "Narrow Tunnel", "grid": Vector2i(1, 0), "size": Vector2(230, 150), "kind": "combat", "rats": 1},
		{"id": "map", "name": "Broken Map Room", "grid": Vector2i(2, 0), "size": Vector2(280, 190), "kind": "lore", "rats": 0},
		{"id": "storage", "name": "Old Storage Room", "grid": Vector2i(2, 1), "size": Vector2(250, 180), "kind": "key", "rats": 2, "has_key": true},
		{"id": "damp", "name": "Damp Stone Room", "grid": Vector2i(1, 1), "size": Vector2(260, 180), "kind": "combat", "rats": 2},
		{"id": "shrine", "name": "Abandoned Shrine Space", "grid": Vector2i(0, 1), "size": Vector2(250, 200), "kind": "exit", "rats": 0, "has_exit": true},
	]
	connections = [
		["start", "tunnel"],
		["tunnel", "map"],
		["map", "storage"],
		["storage", "damp"],
		["damp", "shrine"],
	]

	room_by_id.clear()
	room_rects.clear()
	room_openings.clear()

	for room in rooms:
		var room_id: String = room["id"]
		room_by_id[room_id] = room
		room_rects[room_id] = _room_rect(room)
		room_openings[room_id] = {}

	for connection in connections:
		var first_id: String = connection[0]
		var second_id: String = connection[1]
		_mark_openings(first_id, second_id)


func _create_roots() -> void:
	level_root = Node2D.new()
	level_root.name = "GeneratedLevel"
	add_child(level_root)

	floor_root = Node2D.new()
	floor_root.name = "Floors"
	level_root.add_child(floor_root)

	wall_root = Node2D.new()
	wall_root.name = "Walls"
	level_root.add_child(wall_root)

	enemy_root = Node2D.new()
	enemy_root.name = "Enemies"
	level_root.add_child(enemy_root)

	pickup_root = Node2D.new()
	pickup_root.name = "Pickups"
	level_root.add_child(pickup_root)

	trigger_root = Node2D.new()
	trigger_root.name = "Triggers"
	level_root.add_child(trigger_root)


func _create_background() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	var first := true
	for value in room_rects.values():
		var rect: Rect2 = value
		bounds = rect if first else bounds.merge(rect)
		first = false

	bounds = bounds.grow(220.0)
	_create_rect_visual(floor_root, bounds, COLOR_BACKGROUND, -100, "BuriedDarkness")


func _create_corridors() -> void:
	for connection in connections:
		var first_id: String = connection[0]
		var second_id: String = connection[1]
		var rect_a: Rect2 = room_rects[first_id]
		var rect_b: Rect2 = room_rects[second_id]
		var center_a := rect_a.get_center()
		var center_b := rect_b.get_center()

		if is_equal_approx(center_a.y, center_b.y):
			var left_rect := rect_a if center_a.x < center_b.x else rect_b
			var right_rect := rect_b if center_a.x < center_b.x else rect_a
			var x_start := left_rect.end.x
			var x_end := right_rect.position.x
			var length := x_end - x_start
			var y := center_a.y
			_create_rect_visual(floor_root, Rect2(Vector2(x_start, y - CORRIDOR_WIDTH * 0.5), Vector2(length, CORRIDOR_WIDTH)), COLOR_CORRIDOR, -8, "CorridorFloor")
			_create_wall(Rect2(Vector2(x_start, y - CORRIDOR_WIDTH * 0.5 - WALL_THICKNESS), Vector2(length, WALL_THICKNESS)), "CorridorWallTop")
			_create_wall(Rect2(Vector2(x_start, y + CORRIDOR_WIDTH * 0.5), Vector2(length, WALL_THICKNESS)), "CorridorWallBottom")
		else:
			var top_rect := rect_a if center_a.y < center_b.y else rect_b
			var bottom_rect := rect_b if center_a.y < center_b.y else rect_a
			var y_start := top_rect.end.y
			var y_end := bottom_rect.position.y
			var length := y_end - y_start
			var x := center_a.x
			_create_rect_visual(floor_root, Rect2(Vector2(x - CORRIDOR_WIDTH * 0.5, y_start), Vector2(CORRIDOR_WIDTH, length)), COLOR_CORRIDOR, -8, "CorridorFloor")
			_create_wall(Rect2(Vector2(x - CORRIDOR_WIDTH * 0.5 - WALL_THICKNESS, y_start), Vector2(WALL_THICKNESS, length)), "CorridorWallLeft")
			_create_wall(Rect2(Vector2(x + CORRIDOR_WIDTH * 0.5, y_start), Vector2(WALL_THICKNESS, length)), "CorridorWallRight")


func _create_rooms() -> void:
	for room in rooms:
		var room_id: String = room["id"]
		var rect: Rect2 = room_rects[room_id]
		_create_rect_visual(floor_root, rect, COLOR_FLOOR, -10, str(room["name"]))
		var openings: Dictionary = room_openings[room_id]
		_create_room_walls(rect, openings)


func _spawn_level_objects() -> void:
	game_manager = _get_node_from_path_or_group(game_manager_path, "game_manager")
	var player := _get_node_from_path_or_group(player_path, "player") as Node2D
	if player:
		var start_rect: Rect2 = room_rects["start"]
		player.global_position = start_rect.get_center()

	for room in rooms:
		var room_id: String = room["id"]
		var room_rect: Rect2 = room_rects[room_id]
		var center := room_rect.get_center()
		var rat_count := int(room.get("rats", 0))
		_spawn_rats(center, rat_count)

		if bool(room.get("has_key", false)):
			_spawn_key(center + Vector2(0, -24))

		if bool(room.get("has_exit", false)):
			_spawn_exit(center)

		if room_id == "map":
			var room_size: Vector2 = room["size"]
			_spawn_lore_area(center, room_size)


func _spawn_rats(room_center: Vector2, count: int) -> void:
	var offsets := [
		Vector2(-48, -28),
		Vector2(54, 26),
		Vector2(4, 48),
	]

	for index in range(count):
		var rat := BLIND_RAT_SCENE.instantiate() as Node2D
		rat.global_position = room_center + offsets[index % offsets.size()]
		enemy_root.add_child(rat)


func _spawn_key(position: Vector2) -> void:
	var key := KEY_SCENE.instantiate() as Node2D
	key.global_position = position
	pickup_root.add_child(key)


func _spawn_exit(position: Vector2) -> void:
	var exit := EXIT_SCENE.instantiate() as Node2D
	exit.global_position = position
	pickup_root.add_child(exit)


func _spawn_lore_area(position: Vector2, room_size: Vector2) -> void:
	var area := Area2D.new()
	area.name = "LoreArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = room_size * 0.72
	shape.shape = rect_shape
	area.add_child(shape)

	area.global_position = position
	area.body_entered.connect(_on_lore_area_body_entered)
	trigger_root.add_child(area)


func _on_lore_area_body_entered(body: Node) -> void:
	if lore_shown or not body.is_in_group("player"):
		return

	lore_shown = true
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("show_message"):
		game_manager.show_message(LORE_MESSAGE, 3.5)


func _mark_openings(first_id: String, second_id: String) -> void:
	var first: Dictionary = room_by_id[first_id]
	var second: Dictionary = room_by_id[second_id]
	var first_grid: Vector2i = first["grid"]
	var second_grid: Vector2i = second["grid"]
	var delta := second_grid - first_grid

	if delta.x > 0:
		room_openings[first_id]["right"] = true
		room_openings[second_id]["left"] = true
	elif delta.x < 0:
		room_openings[first_id]["left"] = true
		room_openings[second_id]["right"] = true
	elif delta.y > 0:
		room_openings[first_id]["down"] = true
		room_openings[second_id]["up"] = true
	elif delta.y < 0:
		room_openings[first_id]["up"] = true
		room_openings[second_id]["down"] = true


func _room_rect(room: Dictionary) -> Rect2:
	var grid: Vector2i = room["grid"]
	var center := Vector2(grid.x * ROOM_SPACING.x, grid.y * ROOM_SPACING.y)
	var size: Vector2 = room["size"]
	return Rect2(center - size * 0.5, size)


func _create_room_walls(rect: Rect2, openings: Dictionary) -> void:
	_create_horizontal_wall(rect.position.x, rect.end.x, rect.position.y - WALL_THICKNESS * 0.5, rect.get_center().x, openings.has("up"), "WallTop")
	_create_horizontal_wall(rect.position.x, rect.end.x, rect.end.y + WALL_THICKNESS * 0.5, rect.get_center().x, openings.has("down"), "WallBottom")
	_create_vertical_wall(rect.position.y, rect.end.y, rect.position.x - WALL_THICKNESS * 0.5, rect.get_center().y, openings.has("left"), "WallLeft")
	_create_vertical_wall(rect.position.y, rect.end.y, rect.end.x + WALL_THICKNESS * 0.5, rect.get_center().y, openings.has("right"), "WallRight")


func _create_horizontal_wall(x_start: float, x_end: float, y_center: float, opening_center: float, has_opening: bool, wall_name: String) -> void:
	if not has_opening:
		_create_wall(Rect2(Vector2(x_start, y_center - WALL_THICKNESS * 0.5), Vector2(x_end - x_start, WALL_THICKNESS)), wall_name)
		return

	var gap_half := (CORRIDOR_WIDTH + 10.0) * 0.5
	_create_wall_segment(Rect2(Vector2(x_start, y_center - WALL_THICKNESS * 0.5), Vector2(opening_center - gap_half - x_start, WALL_THICKNESS)), wall_name)
	_create_wall_segment(Rect2(Vector2(opening_center + gap_half, y_center - WALL_THICKNESS * 0.5), Vector2(x_end - opening_center - gap_half, WALL_THICKNESS)), wall_name)


func _create_vertical_wall(y_start: float, y_end: float, x_center: float, opening_center: float, has_opening: bool, wall_name: String) -> void:
	if not has_opening:
		_create_wall(Rect2(Vector2(x_center - WALL_THICKNESS * 0.5, y_start), Vector2(WALL_THICKNESS, y_end - y_start)), wall_name)
		return

	var gap_half := (CORRIDOR_WIDTH + 10.0) * 0.5
	_create_wall_segment(Rect2(Vector2(x_center - WALL_THICKNESS * 0.5, y_start), Vector2(WALL_THICKNESS, opening_center - gap_half - y_start)), wall_name)
	_create_wall_segment(Rect2(Vector2(x_center - WALL_THICKNESS * 0.5, opening_center + gap_half), Vector2(WALL_THICKNESS, y_end - opening_center - gap_half)), wall_name)


func _create_wall_segment(rect: Rect2, wall_name: String) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	_create_wall(rect, wall_name)


func _create_wall(rect: Rect2, wall_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = COLOR_WALL
	visual.z_index = 5
	var half := rect.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	body.add_child(visual)
	wall_root.add_child(body)


func _create_rect_visual(parent: Node, rect: Rect2, color: Color, z_index: int, visual_name: String) -> void:
	var visual := Polygon2D.new()
	visual.name = visual_name
	visual.color = color
	visual.z_index = z_index
	visual.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	parent.add_child(visual)


func _get_node_from_path_or_group(path: NodePath, group_name: String) -> Node:
	if not path.is_empty():
		var found := get_node_or_null(path)
		if found:
			return found
	return get_tree().get_first_node_in_group(group_name)
