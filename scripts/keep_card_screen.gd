extends CanvasLayer

signal kept(id: String)

var _card_ids: Array = []


func setup(card_ids: Array) -> void:
	_card_ids = card_ids.duplicate()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root_control := Control.new()
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04, 0.88)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	root_control.add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	root_control.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Kökaltı derinleşiyor..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Yanında yalnızca bir gücü taşıyabilirsin. Diğerleri karanlıkta kalacak."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(560, 0)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var counts := {}
	var order := []
	for id in _card_ids:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1

	var defs = load("res://scripts/upgrade_screen.gd").UPGRADES

	if order.is_empty():
		var none_label := Label.new()
		none_label.text = "Taşıyacak bir şeyin yok."
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(none_label)
		var cont := Button.new()
		cont.text = "Devam Et"
		cont.custom_minimum_size = Vector2(260, 46)
		cont.pressed.connect(_on_none)
		vbox.add_child(cont)
		return

	for id in order:
		var title_text: String = String(defs[id]["title"]) if defs.has(id) else id
		var desc_text: String = String(defs[id]["desc"]) if defs.has(id) else ""
		var n: int = counts[id]
		if n > 1:
			title_text += " x%d" % n
		var btn := Button.new()
		btn.text = "%s — %s" % [title_text, desc_text]
		btn.custom_minimum_size = Vector2(560, 48)
		btn.pressed.connect(_on_kept.bind(id))
		vbox.add_child(btn)


func _on_kept(id: String) -> void:
	kept.emit(id)
	queue_free()


func _on_none() -> void:
	kept.emit("")
	queue_free()
