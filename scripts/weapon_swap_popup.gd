extends CanvasLayer

signal slot_chosen(slot: int)
signal cancelled

var new_weapon_id: String = ""
var slot1_weapon_name: String = ""
var slot2_weapon_name: String = ""

var _root_control: Control
var _slot1_button: Button
var _slot2_button: Button
var _cancel_button: Button


func setup(new_id: String, new_name: String, slot1_name: String, slot2_name: String) -> void:
	new_weapon_id = new_id
	slot1_weapon_name = slot1_name
	slot2_weapon_name = slot2_name
	_build_ui(new_name, slot1_name, slot2_name)


func _build_ui(new_name: String, slot1_name: String, slot2_name: String) -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_root_control = Control.new()
	_root_control.name = "Root"
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)
	
	# Arka plan
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(bg)
	
	# Merkez container
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_root_control.add_child(center)
	
	# Dikey kutu
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)
	
	# Başlık
	var title := Label.new()
	title.text = "Yeni silah: " + new_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Hangi silahını bırakmak istiyorsun?"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)
	
	# Boşluk
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Slot 1 butonu
	_slot1_button = Button.new()
	_slot1_button.text = "1. " + slot1_name + "  (bırak)"
	_slot1_button.custom_minimum_size = Vector2(280, 50)
	_slot1_button.pressed.connect(_on_slot1_pressed)
	vbox.add_child(_slot1_button)
	
	# Slot 2 butonu
	_slot2_button = Button.new()
	_slot2_button.text = "2. " + slot2_name + "  (bırak)"
	_slot2_button.custom_minimum_size = Vector2(280, 50)
	_slot2_button.pressed.connect(_on_slot2_pressed)
	vbox.add_child(_slot2_button)
	
	# İptal
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	_cancel_button = Button.new()
	_cancel_button.text = "İptal"
	_cancel_button.custom_minimum_size = Vector2(280, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_button)


func _on_slot1_pressed() -> void:
	slot_chosen.emit(1)
	queue_free()


func _on_slot2_pressed() -> void:
	slot_chosen.emit(2)
	queue_free()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()
