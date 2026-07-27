class_name FPSCounter
extends Label

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "display"
const SETTINGS_KEY := "show_fps"
const UPDATE_INTERVAL := 0.25

var settings_path := DEFAULT_SETTINGS_PATH
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -118.0
	offset_top = 52.0
	offset_right = -18.0
	offset_bottom = 76.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color(0.86, 0.78, 0.62, 0.95))
	add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.9))
	add_theme_constant_override("outline_size", 2)
	set_counter_enabled(load_preference(settings_path))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = fmod(_elapsed, UPDATE_INTERVAL)
	_refresh_text()


func set_counter_enabled(enabled: bool, persist := false) -> bool:
	visible = enabled
	set_process(enabled)
	_elapsed = 0.0
	if enabled:
		_refresh_text()
	if not persist:
		return true
	return save_preference(enabled, settings_path)


func _refresh_text() -> void:
	text = "FPS: %d" % roundi(Engine.get_frames_per_second())


static func load_preference(path: String = DEFAULT_SETTINGS_PATH) -> bool:
	var config := ConfigFile.new()
	var load_error: Error = config.load(path)
	if load_error != OK:
		return false
	return bool(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, false))


static func save_preference(enabled: bool, path: String = DEFAULT_SETTINGS_PATH) -> bool:
	var config := ConfigFile.new()
	var load_error: Error = config.load(path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("FPS setting could not be loaded: %s" % error_string(load_error))
		return false
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, enabled)
	var save_error: Error = config.save(path)
	if save_error != OK:
		push_warning("FPS setting could not be saved: %s" % error_string(save_error))
		return false
	return true
