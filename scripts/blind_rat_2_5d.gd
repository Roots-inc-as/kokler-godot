extends CharacterBody3D

@export var max_hp := 2
@export var move_speed := 2.15
@export var acceleration := 10.0
@export var contact_damage := 1
@export var contact_damage_cooldown := 0.8
@export var contact_radius := 0.85
@export var ground_y := 0.0

@onready var model: Node3D = $Model

var current_hp := 0
var contact_cooldown_remaining := 0.0
var target: Node3D
var story_manager: Node


func _ready() -> void:
	add_to_group("blind_rat_2_5d")
	current_hp = max_hp
	global_position.y = ground_y
	call_deferred("_find_refs")


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_find_refs()

	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)

	if target == null or _run_is_locked():
		velocity = Vector3.ZERO
		_lock_to_ground()
		move_and_slide()
		return

	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var desired_velocity := Vector3.ZERO
	if distance > 0.12:
		desired_velocity = to_player.normalized() * move_speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	velocity.y = 0.0

	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		model.rotation.y = atan2(velocity.x, velocity.z)

	move_and_slide()
	_lock_to_ground()

	if distance <= contact_radius and contact_cooldown_remaining <= 0.0 and target.has_method("take_damage"):
		contact_cooldown_remaining = contact_damage_cooldown
		target.take_damage(contact_damage)


func take_damage(amount: int) -> void:
	current_hp -= amount

	if current_hp <= 0:
		queue_free()


func _find_refs() -> void:
	target = get_tree().get_first_node_in_group("player_2_5d") as Node3D
	story_manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _run_is_locked() -> bool:
	return story_manager and story_manager.has_method("is_run_locked") and story_manager.is_run_locked()


func _lock_to_ground() -> void:
	global_position.y = ground_y
	velocity.y = 0.0
