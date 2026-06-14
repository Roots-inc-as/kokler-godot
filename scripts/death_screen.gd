extends CanvasLayer

signal restart_requested

var _lore_text := "Kökler unutmaz."


func setup(lore_text: String) -> void:
	_lore_text = lore_text


func _build_ui() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root_control := Control.new()
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.03, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	root_control.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "ÖLDÜN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.75, 0.18, 0.22))
	vbox.add_child(title)

	var lore := Label.new()
	lore.text = _lore_text
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(460, 0)
	lore.add_theme_font_size_override("font_size", 22)
	lore.add_theme_color_override("font_color", Color(0.82, 0.78, 0.74))
	vbox.add_child(lore)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var restart_button := Button.new()
	restart_button.text = "Yeniden Başla"
	restart_button.custom_minimum_size = Vector2(280, 52)
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.text = "Çıkış"
	quit_button.custom_minimum_size = Vector2(280, 52)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)


func _ready() -> void:
	_build_ui()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
