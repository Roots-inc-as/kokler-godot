extends CharacterBody3D

signal health_changed(current_hp: int, max_hp: int)
signal dash_cooldown_changed(is_ready: bool, remaining: float)
signal died

@export var max_hp := 5
@export var move_speed := 4.2
@export var acceleration := 22.0
@export var dash_speed := 11.5
@export var dash_duration := 0.14
@export var dash_cooldown := 0.8
@export var attack_damage := 1
@export var attack_cooldown := 0.35
@export var attack_active_time := 0.12
@export var invulnerable_time := 0.45
@export var ground_y := 0.0

@onready var model: Node3D = $Model
@onready var attack_area: Area3D = $Model/AttackArea
@onready var attack_shape: CollisionShape3D = $Model/AttackArea/CollisionShape3D
@onready var attack_visual: MeshInstance3D = $Model/AttackArea/AttackVisual

var current_hp := 0
var last_direction := Vector3.BACK
var dash_direction := Vector3.BACK
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var attack_cooldown_remaining := 0.0
var invulnerable_remaining := 0.0
var hit_targets := {}
var story_manager: Node


func _ready() -> void:
	add_to_group("player_2_5d")
	_ensure_input_actions()

	current_hp = max_hp
	global_position.y = ground_y
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true
	attack_visual.visible = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	call_deferred("_sync_story_manager")
	health_changed.emit(current_hp, max_hp)
	dash_cooldown_changed.emit(true, 0.0)


func _physics_process(delta: float) -> void:
	if story_manager == null:
		_sync_story_manager()

	_tick_timers(delta)
	_emit_dash_state()

	if _run_is_locked():
		velocity = Vector3.ZERO
		_lock_to_ground()
		move_and_slide()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if move_direction.length_squared() > 0.001:
		last_direction = move_direction.normalized()
		model.rotation.y = atan2(last_direction.x, last_direction.z)

	if Input.is_action_just_pressed("attack"):
		_start_attack()

	if dash_time_remaining > 0.0:
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
		velocity = dash_direction * dash_speed
	else:
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0:
			_start_dash(move_direction)
		if dash_time_remaining > 0.0:
			velocity = dash_direction * dash_speed
		else:
			var target_velocity := move_direction * move_speed
			velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	velocity.y = 0.0
	move_and_slide()
	_lock_to_ground()


func get_health_state() -> Dictionary:
	return {
		"current": current_hp,
		"max": max_hp,
	}


func take_damage(amount: int) -> void:
	if current_hp <= 0 or invulnerable_remaining > 0.0 or _run_is_locked():
		return

	current_hp = maxi(current_hp - amount, 0)
	invulnerable_remaining = invulnerable_time
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		died.emit()
		if story_manager and story_manager.has_method("player_died"):
			story_manager.player_died()


func _tick_timers(delta: float) -> void:
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	invulnerable_remaining = maxf(invulnerable_remaining - delta, 0.0)


func _start_dash(move_direction: Vector3) -> void:
	dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.001 else last_direction
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	_emit_dash_state()


func _start_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	attack_cooldown_remaining = attack_cooldown
	_swing_weapon()


func _swing_weapon() -> void:
	hit_targets.clear()
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_shape.disabled = false
	attack_visual.visible = true

	await get_tree().physics_frame
	_damage_overlapping_enemies()
	await get_tree().create_timer(attack_active_time).timeout

	if is_instance_valid(attack_area):
		attack_area.monitoring = false
		attack_area.monitorable = false
	if is_instance_valid(attack_shape):
		attack_shape.disabled = true
	if is_instance_valid(attack_visual):
		attack_visual.visible = false


func _damage_overlapping_enemies() -> void:
	for body in attack_area.get_overlapping_bodies():
		_damage_enemy(body)


func _on_attack_area_body_entered(body: Node) -> void:
	if attack_area.monitoring:
		_damage_enemy(body)


func _damage_enemy(body: Node) -> void:
	if body == self or not body.has_method("take_damage"):
		return

	var body_id := body.get_instance_id()
	if hit_targets.has(body_id):
		return

	hit_targets[body_id] = true
	body.take_damage(attack_damage)


func _lock_to_ground() -> void:
	global_position.y = ground_y
	velocity.y = 0.0


func _sync_story_manager() -> void:
	story_manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _run_is_locked() -> bool:
	return story_manager and story_manager.has_method("is_run_locked") and story_manager.is_run_locked()


func _emit_dash_state() -> void:
	dash_cooldown_changed.emit(dash_cooldown_remaining <= 0.0, dash_cooldown_remaining)


func _ensure_input_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("dash", KEY_SPACE)
	_add_key_action("attack", KEY_J)
	_add_mouse_action("attack", MOUSE_BUTTON_LEFT)


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


func _add_mouse_action(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			return

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)
