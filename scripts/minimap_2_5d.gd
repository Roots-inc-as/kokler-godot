extends Control

const ROOM_SIZE_SMALL := Vector2(12.0, 9.0)
const ROOM_SIZE_MEDIUM := Vector2(15.0, 11.0)
const ROOM_SIZE_LARGE := Vector2(18.0, 13.0)

@export var cell_spacing := 24.0

var rooms: Dictionary = {}
var connections: Array = []
var visited: Dictionary = {}
var known: Dictionary = {}
var uncertain: Dictionary = {}
var room_states: Dictionary = {}

var start_room_id := ""
var key_room_id := ""
var exit_room_id := ""
var current_room_id := ""
var min_cell := Vector2i.ZERO
var max_cell := Vector2i.ZERO


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 18.0
	offset_top = -198.0
	offset_right = 250.0
	offset_bottom = -18.0
	custom_minimum_size = Vector2(232.0, 180.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_map(map_data: Dictionary) -> void:
	var rooms_variant: Variant = map_data.get("rooms", {})
	var connections_variant: Variant = map_data.get("connections", [])
	if rooms_variant is Dictionary:
		rooms = rooms_variant as Dictionary
	else:
		rooms = {}
	if connections_variant is Array:
		connections = connections_variant as Array
	else:
		connections = []
	start_room_id = String(map_data.get("start_room_id", ""))
	key_room_id = String(map_data.get("key_room_id", ""))
	exit_room_id = String(map_data.get("exit_room_id", ""))
	visited.clear()
	known.clear()
	uncertain.clear()
	room_states.clear()
	for room_id_variant in rooms.keys():
		var room_id := String(room_id_variant)
		var room_info: Dictionary = rooms[room_id] as Dictionary
		room_states[room_id] = String(room_info.get("state", "unknown"))
	current_room_id = ""
	_calculate_bounds()
	if not start_room_id.is_empty():
		visit_room(start_room_id)
	queue_redraw()


func visit_room(room_id: String) -> void:
	if room_id.is_empty() or not rooms.has(room_id):
		return
	current_room_id = room_id
	visited[room_id] = true
	known[room_id] = true
	uncertain.erase(room_id)
	if String(room_states.get(room_id, "unknown")) == "unknown" or String(room_states.get(room_id, "unknown")) == "shifted":
		room_states[room_id] = "discovered"
	for neighbor_id in _neighbors_for(room_id):
		known[String(neighbor_id)] = true
	queue_redraw()


func mark_uncertain(room_ids: Array) -> void:
	for id_variant in room_ids:
		var room_id := String(id_variant)
		if room_id.is_empty() or room_id == current_room_id or room_id == start_room_id:
			continue
		if known.has(room_id):
			uncertain[room_id] = true
			visited.erase(room_id)
			room_states[room_id] = "shifted"
	queue_redraw()


func set_room_state(room_id: String, state: String) -> void:
	if room_id.is_empty() or not rooms.has(room_id):
		return
	room_states[room_id] = state
	if state == "shifted" and known.has(room_id) and room_id != current_room_id:
		uncertain[room_id] = true
		visited.erase(room_id)
	elif state == "cleared" or state == "active_combat" or state == "discovered":
		known[room_id] = true
		uncertain.erase(room_id)
	queue_redraw()


func reveal_rooms(room_ids: Array) -> void:
	for id_variant in room_ids:
		var room_id := String(id_variant)
		if room_id.is_empty() or not rooms.has(room_id):
			continue
		known[room_id] = true
	queue_redraw()


func _draw() -> void:
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, Color(0.035, 0.026, 0.018, 0.82), true)
	draw_rect(panel_rect, Color(0.42, 0.29, 0.15, 0.65), false, 1.0)
	draw_rect(Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)), Color(0.12, 0.075, 0.038, 0.55), false, 1.0)

	var font := get_theme_default_font()
	var font_size := 11
	draw_string(font, Vector2(12.0, 18.0), "Kök Haritası", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.82, 0.68, 0.42, 0.95))

	for pair_variant in connections:
		var pair: Array = pair_variant as Array
		if pair.size() < 2:
			continue
		var a_id: String = String(pair[0])
		var b_id: String = String(pair[1])
		if not known.has(a_id) or not known.has(b_id):
			continue
		var a_pos := _room_position(a_id)
		var b_pos := _room_position(b_id)
		var line_color := Color(0.33, 0.22, 0.12, 0.85)
		if visited.has(a_id) and visited.has(b_id) and not uncertain.has(a_id) and not uncertain.has(b_id):
			line_color = Color(0.62, 0.43, 0.19, 0.95)
		draw_line(a_pos, b_pos, line_color, 3.0)

	for room_id_variant in rooms.keys():
		var room_id := String(room_id_variant)
		if not known.has(room_id):
			continue
		_draw_room(room_id, font)


func _draw_room(room_id: String, font: Font) -> void:
	var room_info: Dictionary = rooms[room_id] as Dictionary
	var room_type: String = String(room_info.get("type", "root_tunnel"))
	var room_state: String = String(room_states.get(room_id, room_info.get("state", "unknown")))
	var room_size := _draw_size_for_type(room_type)
	var pos := _room_position(room_id)
	var rect := Rect2(pos - room_size * 0.5, room_size)
	var fill := Color(0.13, 0.085, 0.045, 0.95)
	var border := Color(0.46, 0.31, 0.15, 0.9)
	var label := ""

	if room_id == current_room_id:
		fill = Color(0.78, 0.52, 0.20, 0.95)
		border = Color(1.0, 0.82, 0.42, 1.0)
	elif room_state == "active_combat":
		fill = Color(0.34, 0.11, 0.06, 0.96)
		border = Color(0.92, 0.32, 0.14, 0.95)
	elif uncertain.has(room_id) or room_state == "shifted" or not visited.has(room_id):
		fill = Color(0.055, 0.043, 0.035, 0.94)
		border = Color(0.24, 0.18, 0.12, 0.85)
		label = "?"
	elif room_state == "cleared":
		fill = Color(0.18, 0.18, 0.095, 0.95)
		border = Color(0.62, 0.48, 0.24, 0.95)
	else:
		match room_type:
			"mushroom_cellar":
				fill = Color(0.12, 0.18, 0.13, 0.95)
			"forgotten_exit", "sealed_white_door":
				fill = Color(0.17, 0.20, 0.17, 0.95)
			"key_alcove", "loot_niche":
				fill = Color(0.22, 0.15, 0.055, 0.95)
			_:
				pass

	if visited.has(room_id) and not uncertain.has(room_id):
		if room_id == start_room_id:
			label = "S"
		elif room_id == key_room_id:
			label = "K"
		elif room_id == exit_room_id:
			label = "E"

	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 1.2)
	if not label.is_empty():
		var text_pos := rect.position + Vector2(room_size.x * 0.32, room_size.y * 0.78)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.92, 0.82, 0.58, 1.0))


func _draw_size_for_type(room_type: String) -> Vector2:
	match room_type:
		"stone_watch_room", "forgotten_exit":
			return ROOM_SIZE_LARGE
		"wake", "fathers_map_room", "broken_shrine", "key_alcove", "mushroom_cellar", "rat_nest", "shifting_root_gate":
			return ROOM_SIZE_MEDIUM
		_:
			return ROOM_SIZE_SMALL


func _room_position(room_id: String) -> Vector2:
	if not rooms.has(room_id):
		return size * 0.5
	var room_info: Dictionary = rooms[room_id] as Dictionary
	var cell := _cell_from_room_info(room_info)
	var grid_size := Vector2(float(max_cell.x - min_cell.x + 1), float(max_cell.y - min_cell.y + 1))
	var map_origin := Vector2(
		(size.x - grid_size.x * cell_spacing) * 0.5 + cell_spacing * 0.5,
		30.0 + (size.y - 42.0 - grid_size.y * cell_spacing) * 0.5 + cell_spacing * 0.5
	)
	return map_origin + Vector2(float(cell.x - min_cell.x), float(cell.y - min_cell.y)) * cell_spacing


func _neighbors_for(room_id: String) -> Array:
	if not rooms.has(room_id):
		return []
	var room_info: Dictionary = rooms[room_id] as Dictionary
	var neighbors_variant: Variant = room_info.get("neighbors", [])
	if neighbors_variant is Array:
		return neighbors_variant as Array
	return []


func _calculate_bounds() -> void:
	var first := true
	for room_id_variant in rooms.keys():
		var room_id := String(room_id_variant)
		var room_info: Dictionary = rooms[room_id] as Dictionary
		var cell := _cell_from_room_info(room_info)
		if first:
			min_cell = cell
			max_cell = cell
			first = false
		else:
			min_cell.x = mini(min_cell.x, cell.x)
			min_cell.y = mini(min_cell.y, cell.y)
			max_cell.x = maxi(max_cell.x, cell.x)
			max_cell.y = maxi(max_cell.y, cell.y)


func _cell_from_room_info(room_info: Dictionary) -> Vector2i:
	var cell_variant: Variant = room_info.get("cell", Vector2i.ZERO)
	if cell_variant is Vector2i:
		return cell_variant
	if cell_variant is Vector2:
		return Vector2i(cell_variant)
	return Vector2i.ZERO
