extends CanvasLayer

signal restart_requested
signal exit_requested

var _lore_text := "Kökler unutmaz."
var _summary: Dictionary = {}
var _action_pending := false
var _restart_button: Button
var _quit_button: Button


func setup(lore_text: String, summary: Dictionary = {}) -> void:
	_lore_text = lore_text
	_summary = summary


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
	lore.custom_minimum_size = Vector2(520, 0)
	lore.add_theme_font_size_override("font_size", 18)
	lore.add_theme_color_override("font_color", Color(0.82, 0.78, 0.74))
	vbox.add_child(lore)

	var summary_label := Label.new()
	summary_label.text = _summary_text()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(520, 0)
	summary_label.add_theme_font_size_override("font_size", 15)
	summary_label.add_theme_color_override("font_color", Color(0.74, 0.62, 0.42))
	if not summary_label.text.is_empty():
		vbox.add_child(summary_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_restart_button = Button.new()
	_restart_button.text = "Yeniden Başla"
	_restart_button.custom_minimum_size = Vector2(280, 52)
	_restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_button)

	_quit_button = Button.new()
	_quit_button.text = "Ana Menüye Dön"
	_quit_button.custom_minimum_size = Vector2(280, 52)
	_quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(_quit_button)


func _ready() -> void:
	_build_ui()


func _on_restart_pressed() -> void:
	if not _claim_action():
		return
	restart_requested.emit()


func _on_quit_pressed() -> void:
	# The game manager decides what "exit" means. Calling quit() here can close
	# the editor debug session during death-screen testing.
	if not _claim_action():
		return
	exit_requested.emit()


func _claim_action() -> bool:
	if _action_pending:
		return false
	_action_pending = true
	_set_buttons_disabled(true)
	return true


func _set_buttons_disabled(disabled: bool) -> void:
	if _restart_button:
		_restart_button.disabled = disabled
	if _quit_button:
		_quit_button.disabled = disabled


func _summary_text() -> String:
	if _summary.is_empty():
		return ""
	var lines: Array[String] = [
		"Katman: %d" % int(_summary.get("main_layer", 1)),
		"Mikro Kat: %d/%d" % [int(_summary.get("micro_floor", 1)), int(_summary.get("total_micro_floors", 1))],
		"Temizlenen Oda: %d" % int(_summary.get("rooms_cleared", 0)),
		"Öldürülen Düşman: %d" % int(_summary.get("enemies_killed", 0)),
		"Toplanan Kök: %d" % int(_summary.get("root_fragments_collected", 0)),
		"Kurutulmuş Kök: +%d" % int(_summary.get("dried_roots_gained", 0)),
	]
	return "\n".join(lines)
