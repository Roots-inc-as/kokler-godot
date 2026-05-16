extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal dash_cooldown_changed(is_ready: bool, remaining: float)

@export var max_hp := 5
@export var move_speed := 180.0
@export var dash_speed := 520.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.8
@export var attack_damage := 1
@export var attack_cooldown := 0.35
@export var attack_active_time := 0.12

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape
@onready var attack_visual: CanvasItem = $AttackArea/AttackVisual
@onready var body_visual: Polygon2D = $Body

var current_hp := 0
var last_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var attack_cooldown_remaining := 0.0
var invulnerable_remaining := 0.0
var hit_targets := {}
var game_manager: Node


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()

	current_hp = max_hp
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true
	attack_visual.visible = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	call_deferred("_sync_manager")
	health_changed.emit(current_hp, max_hp)
	dash_cooldown_changed.emit(true, 0.0)


func _physics_process(delta: float) -> void:
	if game_manager == null:
		_sync_manager()

	_tick_timers(delta)
	_emit_dash_state()

	if _run_is_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		last_direction = input_vector.normalized()

	if Input.is_action_just_pressed("attack"):
		_start_attack()

	if dash_time_remaining > 0.0:
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
		velocity = dash_direction * dash_speed
		move_and_slide()
		return

	if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0:
		_start_dash(input_vector)

	if dash_time_remaining > 0.0:
		velocity = dash_direction * dash_speed
	else:
		velocity = input_vector * move_speed
	move_and_slide()


func get_health_state() -> Dictionary:
	return {
		"current": current_hp,
		"max": max_hp,
	}


func take_damage(amount: int) -> void:
	if current_hp <= 0 or invulnerable_remaining > 0.0 or _run_is_locked():
		return

	current_hp = maxi(current_hp - amount, 0)
	invulnerable_remaining = 0.45
	body_visual.modulate = Color(1.5, 0.75, 0.65, 1.0)
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		velocity = Vector2.ZERO
		if game_manager and game_manager.has_method("player_died"):
			game_manager.player_died()


func _tick_timers(delta: float) -> void:
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	invulnerable_remaining = maxf(invulnerable_remaining - delta, 0.0)
	if invulnerable_remaining <= 0.0 and current_hp > 0:
		body_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _start_dash(input_vector: Vector2) -> void:
	dash_direction = input_vector.normalized() if input_vector != Vector2.ZERO else last_direction
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	_emit_dash_state()


func _start_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	attack_cooldown_remaining = attack_cooldown
	var attack_direction := last_direction
	var mouse_delta := get_global_mouse_position() - global_position
	if mouse_delta.length() > 12.0:
		attack_direction = mouse_delta.normalized()
		last_direction = attack_direction

	_swing_weapon(attack_direction)


func _swing_weapon(attack_direction: Vector2) -> void:
	hit_targets.clear()
	attack_area.rotation = attack_direction.angle()
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


func _sync_manager() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager")


func _run_is_locked() -> bool:
	return game_manager and game_manager.has_method("is_run_locked") and game_manager.is_run_locked()


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
