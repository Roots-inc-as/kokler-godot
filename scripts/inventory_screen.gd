extends CanvasLayer

signal closed

var weapon_manager: Node

var _root_control: Control
var _slot1_container: VBoxContainer
var _slot2_container: VBoxContainer


func setup(manager: Node) -> void:
	weapon_manager = manager
	_build_ui()


func _build_ui() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_root_control = Control.new()
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)
	
	# Arka plan (yarı saydam siyah)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(bg)
	
	# Merkez container
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_root_control.add_child(center)
	
	# Ana dikey kutu
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Başlık
	var title := Label.new()
	title.text = "Envanter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)
	
	# 2 slot yan yana (HBox)
	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 30)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_hbox)
	
	# Slot 1
	_slot1_container = _create_slot_container("Slot 1", 1)
	slots_hbox.add_child(_slot1_container)
	
	# Slot 2
	_slot2_container = _create_slot_container("Slot 2", 2)
	slots_hbox.add_child(_slot2_container)
	
	# Yer değiştir butonu
	var swap_button := Button.new()
	swap_button.text = "↔ Yer Değiştir (R)"
	swap_button.custom_minimum_size = Vector2(280, 50)
	swap_button.pressed.connect(_on_swap_pressed)
	vbox.add_child(swap_button)
	
	# Boşluk
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Kapat butonu
	var close_button := Button.new()
	close_button.text = "Kapat (I)"
	close_button.custom_minimum_size = Vector2(280, 40)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)
	
	# İçeriği doldur
	_refresh_slots()


func _create_slot_container(slot_title: String, slot_number: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 220)
	box.add_theme_constant_override("separation", 6)
	box.set_meta("slot_number", slot_number)
	return box


func _refresh_slots() -> void:
	_fill_slot(_slot1_container, 1)
	_fill_slot(_slot2_container, 2)


func _fill_slot(container: VBoxContainer, slot_number: int) -> void:
	# Mevcut çocukları temizle
	for child in container.get_children():
		child.queue_free()
	
	# Slot başlığı
	var slot_label := Label.new()
	slot_label.text = "— Slot " + str(slot_number) + " —"
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 20)
	container.add_child(slot_label)
	
	# Silah datası
	var weapon: WeaponData = null
	if weapon_manager and weapon_manager.has_method("get_weapon_at_slot"):
		weapon = weapon_manager.get_weapon_at_slot(slot_number)
	
	if not weapon:
		var empty_label := Label.new()
		empty_label.text = "(Boş)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		container.add_child(empty_label)
		return
	
	# Silah adı
	var name_label := Label.new()
	name_label.text = weapon.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", weapon.color)
	container.add_child(name_label)
	
	# Tip
	_add_stat_line(container, "Tip:", _translate_type(weapon.weapon_type))
	# Hasar
	_add_stat_line(container, "Hasar:", str(weapon.damage))
	# Cooldown
	_add_stat_line(container, "Cooldown:", str(weapon.attack_cooldown) + " sn")
	# Combo penceresi
	_add_stat_line(container, "Combo süresi:", str(weapon.combo_window) + " sn")
	# Menzil
	_add_stat_line(container, "Menzil:", str(weapon.range) + " m")
	# Geri itme
	_add_stat_line(container, "Geri itme:", str(weapon.knockback))


func _add_stat_line(container: VBoxContainer, label: String, value: String) -> void:
	var line := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 15)
	line.add_child(lbl)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 15)
	line.add_child(val)
	container.add_child(line)


func _translate_type(t: String) -> String:
	match t:
		"melee": return "Yakın dövüş"
		"ranged": return "Uzaktan"
		_: return t


func _on_swap_pressed() -> void:
	if weapon_manager and weapon_manager.has_method("swap_slots"):
		weapon_manager.swap_slots()
		_refresh_slots()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC kapat
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
		# R ile slot yer değiştir
		elif event.keycode == KEY_R:
			_on_swap_pressed()
			get_viewport().set_input_as_handled()
