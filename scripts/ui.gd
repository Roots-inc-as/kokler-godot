extends CanvasLayer

const MINIMAP_SCRIPT := preload("res://scripts/minimap_2_5d.gd")

@onready var hp_label: Label = $HPLabel
@onready var key_label: Label = $KeyLabel
@onready var dash_label: Label = $DashLabel
@onready var weapon_label: Label = get_node_or_null("WeaponLabel") as Label
@onready var root_fragment_label: Label = get_node_or_null("RootFragmentLabel") as Label
@onready var weapon_slots_label: Label = get_node_or_null("WeaponSlotsLabel") as Label
@onready var objective_label: Label = get_node_or_null("ObjectiveLabel") as Label
@onready var controls_label: Label = get_node_or_null("ControlsHelpLabel") as Label
@onready var minimap: Control = get_node_or_null("Minimap") as Control
@onready var message_label: Label = $MessageLabel
@onready var victory_panel: ColorRect = $VictoryPanel
@onready var victory_label: Label = $VictoryPanel/VictoryLabel
@onready var hit_flash: ColorRect = %HitFlash
var upgrades_label: Label

var message_token := 0


func _ready() -> void:
	add_to_group("ui_2_5d")
	_ensure_objective_label()
	_ensure_controls_label()
	_ensure_minimap()
	_apply_compact_top_left_style()
	set_key_status(false)
	set_dash_ready(true, 0.0)
	set_weapon("Haritacı Bıçağı", "1 Haritacı Bıçağı")
	set_root_fragments(0)
	set_objective_text("Anahtarı bul")
	set_controls_help_text(_default_controls_help_text())
	message_label.visible = false
	victory_panel.visible = false
	var upgrades_label: Label


func _ensure_upgrades_label() -> void:
	if get_node_or_null("UpgradesLabel"):
		return
	upgrades_label = Label.new()
	upgrades_label.name = "UpgradesLabel"
	upgrades_label.position = Vector2(12, 120)
	upgrades_label.add_theme_font_size_override("font_size", 14)
	upgrades_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.45))
	add_child(upgrades_label)
	upgrades_label.text = ""


func set_upgrades(ids: Array) -> void:
	if not upgrades_label:
		_ensure_upgrades_label()
	if ids.is_empty():
		upgrades_label.text = ""
		return
	var counts := {}
	var order := []
	for id in ids:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var lines := ["— Kartlar —"]
	for id in order:
		var title: String = _upgrade_title(id)
		var n: int = counts[id]
		if n > 1:
			lines.append("%s x%d" % [title, n])
		else:
			lines.append(title)
	upgrades_label.text = "\n".join(lines)


func _upgrade_title(id: String) -> String:
	var defs = load("res://scripts/upgrade_screen.gd").UPGRADES
	if defs.has(id):
		return String(defs[id]["title"])
	return id


func set_hp(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]


func set_key_status(has_key: bool) -> void:
	key_label.text = "Anahtar: Alındı" if has_key else "Anahtar: Yok"


func set_dash_ready(is_ready: bool, remaining: float) -> void:
	dash_label.text = "Dash: Hazır" if is_ready else "Dash: %.1f" % remaining


func set_weapon(display_name: String, slots_text := "") -> void:
	if weapon_label:
		weapon_label.text = "Silah: " + display_name
	if weapon_slots_label:
		weapon_slots_label.text = slots_text


func set_root_fragments(count: int) -> void:
	if root_fragment_label:
		root_fragment_label.text = "Kök: %d | E: Sunağı" % count


func set_objective_text(text: String) -> void:
	_ensure_objective_label()
	if objective_label:
		objective_label.text = "Amaç: " + text


func set_controls_help_text(text: String) -> void:
	_ensure_controls_label()
	if controls_label:
		controls_label.text = text


func setup_minimap(map_data: Dictionary) -> void:
	_ensure_minimap()
	if minimap and minimap.has_method("setup_map"):
		minimap.call("setup_map", map_data)


func visit_minimap_room(room_id: String) -> void:
	_ensure_minimap()
	if minimap and minimap.has_method("visit_room"):
		minimap.call("visit_room", room_id)


func mark_minimap_uncertain(room_ids: Array) -> void:
	_ensure_minimap()
	if minimap and minimap.has_method("mark_uncertain"):
		minimap.call("mark_uncertain", room_ids)


func set_minimap_room_state(room_id: String, state: String) -> void:
	_ensure_minimap()
	if minimap and minimap.has_method("set_room_state"):
		minimap.call("set_room_state", room_id, state)


func reveal_minimap_rooms(room_ids: Array) -> void:
	_ensure_minimap()
	if minimap and minimap.has_method("reveal_rooms"):
		minimap.call("reveal_rooms", room_ids)


func show_message(text: String, duration := 3.0) -> void:
	if not is_inside_tree():
		return
	message_token += 1
	var token := message_token
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree():
		return
	if token == message_token and not victory_panel.visible:
		message_label.visible = false


func show_victory(text: String) -> void:
	message_token += 1
	victory_label.text = text
	victory_panel.visible = true
	message_label.visible = false


func show_death(text: String) -> void:
	show_message(text, 1.0)


func flash_damage() -> void:
	if hit_flash == null:
		return
	hit_flash.color = Color(1.0, 0.0, 0.0, 0.15)
	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.0, 0.5)


func _ensure_minimap() -> void:
	if minimap:
		return
	minimap = MINIMAP_SCRIPT.new() as Control
	minimap.name = "Minimap"
	add_child(minimap)


func _ensure_objective_label() -> void:
	if objective_label:
		return
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.anchor_left = 1.0
	objective_label.anchor_right = 1.0
	objective_label.offset_left = -360.0
	objective_label.offset_top = 18.0
	objective_label.offset_right = -18.0
	objective_label.offset_bottom = 46.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.54, 1.0))
	add_child(objective_label)


func _ensure_controls_label() -> void:
	if controls_label:
		return
	controls_label = Label.new()
	controls_label.name = "ControlsHelpLabel"
	controls_label.offset_left = 18.0
	controls_label.offset_top = 156.0
	controls_label.offset_right = 560.0
	controls_label.offset_bottom = 206.0
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_color_override("font_color", Color(0.62, 0.56, 0.43, 0.95))
	add_child(controls_label)


func _default_controls_help_text() -> String:
	return "WASD hareket | Space dash | Sol/Sağ tık (J/K) saldırı\n1-2 silah | I envanter | E sunağı | Esc menü | F11 tam ekran"


func _apply_compact_top_left_style() -> void:
	var status_labels: Array[Label] = [
		hp_label,
		key_label,
		dash_label,
		weapon_label,
		root_fragment_label,
		weapon_slots_label,
	]
	for label in status_labels:
		if label:
			label.add_theme_font_size_override("font_size", 13)
	_set_label_bounds(hp_label, 18.0, 12.0, 220.0, 30.0)
	_set_label_bounds(key_label, 18.0, 31.0, 220.0, 49.0)
	_set_label_bounds(dash_label, 18.0, 50.0, 220.0, 68.0)
	_set_label_bounds(weapon_label, 18.0, 69.0, 390.0, 87.0)
	_set_label_bounds(root_fragment_label, 18.0, 88.0, 390.0, 106.0)
	_set_label_bounds(weapon_slots_label, 18.0, 107.0, 620.0, 126.0)
	if weapon_slots_label:
		weapon_slots_label.add_theme_font_size_override("font_size", 12)
	if controls_label:
		controls_label.add_theme_font_size_override("font_size", 11)
		_set_label_bounds(controls_label, 18.0, 130.0, 560.0, 176.0)
	if objective_label:
		objective_label.add_theme_font_size_override("font_size", 13)


func _set_label_bounds(label: Label, left: float, top: float, right: float, bottom: float) -> void:
	if label == null:
		return
	label.offset_left = left
	label.offset_top = top
	label.offset_right = right
	label.offset_bottom = bottom
