extends Area3D

@export var spin_speed := 0.65

const OPTIONS: Array[String] = ["heal", "reveal", "empower"]

var manager: Node
var _player_near := false
var _option_index := 0
var _prompt_token := 0

@onready var visual: Node3D = get_node_or_null("Visual") as Node3D
@onready var glow: MeshInstance3D = get_node_or_null("Visual/Glow") as MeshInstance3D


func _ready() -> void:
	_ensure_interact_action()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if manager == null:
		manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _process(delta: float) -> void:
	if visual:
		visual.rotate_y(spin_speed * delta)
	if glow:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.08
		glow.scale = Vector3(pulse, pulse, pulse)
	if _player_near and Input.is_action_just_pressed("interact"):
		_use_current_option()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player_2_5d"):
		return
	_player_near = true
	_show_prompt()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player_2_5d"):
		return
	_player_near = false
	_prompt_token += 1


func _use_current_option() -> void:
	if manager == null or not manager.has_method("use_root_shrine_option"):
		return
	var option_id := OPTIONS[_option_index]
	manager.call("use_root_shrine_option", option_id)
	_option_index = (_option_index + 1) % OPTIONS.size()
	_prompt_token += 1
	var token := _prompt_token
	await get_tree().create_timer(1.15).timeout
	if token == _prompt_token and _player_near:
		_show_prompt()


func _show_prompt() -> void:
	if manager == null or not manager.has_method("show_message"):
		return
	var option_id := OPTIONS[_option_index]
	var label := option_id
	if manager.has_method("get_root_shrine_option_label"):
		label = String(manager.call("get_root_shrine_option_label", option_id))
	manager.call("show_message", "E: Kök Sunağı - " + label, 2.0)


func _ensure_interact_action() -> void:
	var action := StringName("interact")
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	InputMap.action_add_event(action, event)
