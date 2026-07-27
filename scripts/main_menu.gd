extends Control

const GAME_SCENE_PATH := "res://scenes/main_2_5d.tscn"
const FPS_COUNTER_SCRIPT := preload("res://scripts/fps_counter.gd")

var _transition_pending := false
var _buttons: Array[Button] = []
var _status_label: Label
var _how_to_panel: PanelContainer
var _settings_panel: PanelContainer
var _fps_counter: FPSCounter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	_build_ui()
	_ensure_fps_counter()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.015, 0.01, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := MarginContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("margin_left", 72)
	root.add_theme_constant_override("margin_right", 72)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_bottom", 48)
	add_child(root)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 42)
	root.add_child(hbox)

	var menu_box := VBoxContainer.new()
	menu_box.custom_minimum_size = Vector2(380, 0)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 14)
	hbox.add_child(menu_box)

	var title := Label.new()
	title.text = "KÖKLER"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.86, 0.68, 0.38))
	menu_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Kökaltı seni hatırlıyor."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.62, 0.48))
	menu_box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	menu_box.add_child(spacer)

	_add_menu_button(menu_box, "Yeni Koşu", _on_new_run_pressed)
	_add_menu_button(menu_box, "Nasıl Oynanır", _show_how_to_panel)
	_add_menu_button(menu_box, "Ayarlar", _show_settings_panel)
	_add_menu_button(menu_box, "Çıkış", _on_exit_pressed)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(340, 0)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.64, 0.50, 0.34))
	menu_box.add_child(_status_label)

	var panel_holder := CenterContainer.new()
	panel_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(panel_holder)

	var panel_stack := Control.new()
	panel_stack.custom_minimum_size = Vector2(520, 420)
	panel_stack.anchor_right = 1.0
	panel_stack.anchor_bottom = 1.0
	panel_holder.add_child(panel_stack)
	_how_to_panel = _make_panel("Nasıl Oynanır", [
		"WASD: Hareket",
		"Space: Dash",
		"Sol Tık / J: Slot 1 saldırı",
		"Sağ Tık / K: Slot 2 saldırı",
		"1-2: Silah seç",
		"E: Kök Sunağı",
		"Amaç: Anahtarı bul, çıkışa ulaş, ölmeden daha derine in.",
	])
	panel_stack.add_child(_how_to_panel)

	_settings_panel = _make_settings_panel()
	panel_stack.add_child(_settings_panel)
	_show_how_to_panel()


func _add_menu_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 46)
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)


func _make_panel(title_text: String, lines: Array[String]) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.82, 0.68, 0.42))
	box.add_child(title)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
		box.add_child(label)
	return panel


func _make_settings_panel() -> PanelContainer:
	var panel := _make_panel("Ayarlar", [])
	var box := panel.get_child(0) as VBoxContainer
	var fullscreen := CheckButton.new()
	fullscreen.text = "Tam ekran"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	box.add_child(fullscreen)
	var show_fps := CheckButton.new()
	show_fps.text = "FPS Göster"
	show_fps.button_pressed = FPS_COUNTER_SCRIPT.load_preference()
	show_fps.toggled.connect(_on_show_fps_toggled)
	box.add_child(show_fps)
	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(_show_how_to_panel)
	box.add_child(back)
	return panel


func _show_how_to_panel() -> void:
	if _how_to_panel:
		_how_to_panel.visible = true
	if _settings_panel:
		_settings_panel.visible = false


func _show_settings_panel() -> void:
	if _how_to_panel:
		_how_to_panel.visible = false
	if _settings_panel:
		_settings_panel.visible = true


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_show_fps_toggled(enabled: bool) -> void:
	var saved := FPS_COUNTER_SCRIPT.save_preference(enabled)
	if _fps_counter:
		_fps_counter.set_counter_enabled(enabled)
	if not saved and _status_label:
		_status_label.text = "FPS ayarı kaydedilemedi."


func _ensure_fps_counter() -> void:
	if _fps_counter:
		return
	_fps_counter = FPS_COUNTER_SCRIPT.new() as FPSCounter
	_fps_counter.name = "FPSCounter"
	add_child(_fps_counter)


func _on_new_run_pressed() -> void:
	if _transition_pending:
		return
	_transition_pending = true
	_set_buttons_disabled(true)
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", GAME_SCENE_PATH)


func _on_exit_pressed() -> void:
	if _transition_pending:
		return
	if OS.has_feature("editor") or OS.has_feature("debug"):
		_status_label.text = "Debug modunda güvenli kapatma için pencereyi kapatın."
		return
	_transition_pending = true
	_set_buttons_disabled(true)
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().call_deferred("quit")


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		if button:
			button.disabled = disabled
