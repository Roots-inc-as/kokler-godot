extends CharacterBody3D

@export var move_speed := 4.2
@export var acceleration := 20.0
@export var ground_y := 0.0

@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group("player_2_5d_test")
	_ensure_input_actions()
	global_position.y = ground_y


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)

	var target_x := move_direction.x * move_speed
	var target_z := move_direction.z * move_speed
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_z, acceleration * delta)
	velocity.y = 0.0

	if move_direction.length_squared() > 0.01:
		model.rotation.y = atan2(move_direction.x, move_direction.z)

	move_and_slide()
	global_position.y = ground_y
	velocity.y = 0.0


func _ensure_input_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)


func _add_key_action(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
			return

	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)
