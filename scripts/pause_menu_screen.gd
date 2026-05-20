extends CanvasLayer

signal resumed
signal restart_requested

var _root_control: Control


func _build_ui() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root_control = Control.new()
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_root_control.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Duraklatıldı"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var resume_button := Button.new()
	resume_button.text = "Devam Et (ESC)"
	resume_button.custom_minimum_size = Vector2(280, 50)
	resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_button)

	var restart_button := Button.new()
	restart_button.text = "Yeniden Başla"
	restart_button.custom_minimum_size = Vector2(280, 50)
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.text = "Çıkış"
	quit_button.custom_minimum_size = Vector2(280, 50)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)


func _ready() -> void:
	_build_ui()


func _on_resume_pressed() -> void:
	resumed.emit()
	queue_free()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
