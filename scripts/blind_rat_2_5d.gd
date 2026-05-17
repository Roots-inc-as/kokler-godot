extends CharacterBody3D

const HEALTH_BAR_SCRIPT := preload("res://scripts/health_bar_3d.gd")

@export var max_hp := 2
@export var move_speed := 2.45
@export var acceleration := 12.0
@export var contact_damage := 1
@export var contact_damage_cooldown := 0.75
@export var contact_radius := 0.85
@export var detect_radius := 7.5
@export var ground_y := 0.0

@onready var model: Node3D = $Model

var current_hp := 0
var contact_cooldown_remaining := 0.0
var target: Node3D
var story_manager: Node
var manager: Node
var knockback_velocity := Vector3.ZERO
var knockback_remaining := 0.0
var _health_bar: HealthBar3D
var _anim_time := 0.0
var _base_model_position := Vector3.ZERO
var _dying := false


func _ready() -> void:
	add_to_group("enemy_2_5d")
	add_to_group("blind_rat_2_5d")
	current_hp = max_hp
	global_position.y = ground_y
	_anim_time = randf() * TAU
	manager = get_tree().current_scene
	if model:
		_base_model_position = model.position
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.y_offset = 0.82
	_health_bar.width = 0.75
	add_child(_health_bar)
	_health_bar.set_health(current_hp, max_hp)
	call_deferred("_find_refs")


func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector3.ZERO
		_lock_to_ground()
		return

	if target == null or not is_instance_valid(target):
		_find_refs()

	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)

	if target == null or _run_is_locked():
		velocity = Vector3.ZERO
		_lock_to_ground()
		move_and_slide()
		return

	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var desired_velocity := Vector3.ZERO
	if distance <= detect_radius and distance > 0.05:
		desired_velocity = to_player.normalized() * move_speed

	if knockback_remaining > 0.0:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
	else:
		velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	velocity.y = 0.0

	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		model.rotation.y = atan2(velocity.x, velocity.z)
	_animate_crawl(delta, Vector2(velocity.x, velocity.z).length())

	move_and_slide()
	_lock_to_ground()

	if distance <= contact_radius and contact_cooldown_remaining <= 0.0 and target.has_method("take_damage"):
		contact_cooldown_remaining = contact_damage_cooldown
		_bite_lunge()
		target.call("take_damage", contact_damage)


func take_damage(amount: int) -> void:
	if _dying:
		return
	current_hp -= max(amount, 1)
	_flash_hit()
	if _health_bar:
		_health_bar.set_health(current_hp, max_hp)
	if current_hp <= 0:
		_die()


func apply_knockback(from_position: Vector3, force: float) -> void:
	var push_dir := global_position - from_position
	push_dir.y = 0.0
	if push_dir.length_squared() > 0.01:
		knockback_velocity = push_dir.normalized() * force
		knockback_remaining = 0.08


func _find_refs() -> void:
	target = get_tree().get_first_node_in_group("player_2_5d") as Node3D
	story_manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _run_is_locked() -> bool:
	return story_manager and story_manager.has_method("is_run_locked") and story_manager.is_run_locked()


func _lock_to_ground() -> void:
	global_position.y = ground_y
	velocity.y = 0.0


func _flash_hit() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.16, 0.85, 1.16), 0.05)
	tween.tween_property(model, "scale", Vector3.ONE, 0.08)


func _animate_crawl(delta: float, speed: float) -> void:
	if not model:
		return
	_anim_time += delta * (7.0 if speed > 0.1 else 2.2)
	model.position = _base_model_position + Vector3(0.0, sin(_anim_time) * 0.025, 0.0)
	model.rotation.z = sin(_anim_time * 1.7) * (0.055 if speed > 0.1 else 0.025)


func _bite_lunge() -> void:
	if not model or _dying:
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.08, 0.78, 1.2), 0.06)
	tween.tween_property(model, "scale", Vector3.ONE, 0.08)


func _die() -> void:
	if _dying:
		return
	_dying = true
	collision_layer = 0
	collision_mask = 0
	if manager and manager.has_method("enemy_died"):
		manager.call("enemy_died", "blind_rat", global_position)
	if _health_bar:
		_health_bar.visible = false
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.25, 0.18, 1.25), 0.16)
	tween.tween_callback(Callable(self, "queue_free"))
