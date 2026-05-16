extends Node

class_name GameManager

const LOCKED_EXIT_MESSAGE := "Anahtar olmadan Kökaltı seni bırakmaz."
const KEY_MESSAGE := "Bir kapı açıldı. Bir şey seni içeri saydı."
const VICTORY_MESSAGE := "Şimdilik kaçtın. Ama Kökler seni hatırlıyor."
const DEATH_MESSAGE := "Asha yeniden hatırlıyor..."

@export var player_path: NodePath
@export var ui_path: NodePath

var has_key := false
var victory := false
var restarting := false

var player: Node
var ui: Node


func _ready() -> void:
	add_to_group("game_manager")
	call_deferred("_wire_nodes")


func _wire_nodes() -> void:
	player = _get_node_or_group(player_path, "player")
	ui = _get_node_or_group(ui_path, "ui")

	if player:
		var health_callable := Callable(self, "_on_player_health_changed")
		if player.has_signal("health_changed") and not player.is_connected("health_changed", health_callable):
			player.connect("health_changed", health_callable)

		var dash_callable := Callable(self, "_on_player_dash_cooldown_changed")
		if player.has_signal("dash_cooldown_changed") and not player.is_connected("dash_cooldown_changed", dash_callable):
			player.connect("dash_cooldown_changed", dash_callable)

		if player.has_method("get_health_state"):
			var health_state: Dictionary = player.get_health_state()
			_on_player_health_changed(health_state.get("current", 0), health_state.get("max", 0))

	if ui and ui.has_method("set_key_status"):
		ui.set_key_status(has_key)


func _get_node_or_group(path: NodePath, group_name: String) -> Node:
	if not path.is_empty():
		var found := get_node_or_null(path)
		if found:
			return found
	return get_tree().get_first_node_in_group(group_name)


func collect_key() -> void:
	if victory or restarting or has_key:
		return

	has_key = true
	if ui and ui.has_method("set_key_status"):
		ui.set_key_status(true)
	show_message(KEY_MESSAGE, 3.0)


func try_exit() -> void:
	if victory or restarting:
		return

	if has_key:
		trigger_victory()
	else:
		show_message(LOCKED_EXIT_MESSAGE, 2.5)


func trigger_victory() -> void:
	if victory:
		return

	victory = true
	if ui and ui.has_method("show_victory"):
		ui.show_victory(VICTORY_MESSAGE)


func player_died() -> void:
	if victory or restarting:
		return

	restarting = true
	if ui and ui.has_method("show_death"):
		ui.show_death(DEATH_MESSAGE)
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()


func show_message(text: String, duration := 3.0) -> void:
	if ui and ui.has_method("show_message"):
		ui.show_message(text, duration)


func is_run_locked() -> bool:
	return victory or restarting


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if ui and ui.has_method("set_hp"):
		ui.set_hp(current_hp, max_hp)


func _on_player_dash_cooldown_changed(is_ready: bool, remaining: float) -> void:
	if ui and ui.has_method("set_dash_ready"):
		ui.set_dash_ready(is_ready, remaining)
