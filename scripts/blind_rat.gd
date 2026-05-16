extends CharacterBody2D

@export var max_hp := 2
@export var move_speed := 85.0
@export var contact_damage := 1
@export var contact_damage_cooldown := 0.8
@export var contact_radius := 24.0

@onready var body_visual: Polygon2D = $Body

var current_hp := 0
var player: Node2D
var game_manager: Node
var contact_cooldown_remaining := 0.0


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	call_deferred("_find_refs")


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_refs()

	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)

	if player == null or _run_is_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	velocity = to_player.normalized() * move_speed if distance > 8.0 else Vector2.ZERO
	move_and_slide()

	if distance <= contact_radius and contact_cooldown_remaining <= 0.0 and player.has_method("take_damage"):
		contact_cooldown_remaining = contact_damage_cooldown
		player.take_damage(contact_damage)


func take_damage(amount: int) -> void:
	current_hp -= amount
	body_visual.modulate = Color(1.25, 0.35, 0.3, 1.0)

	if current_hp <= 0:
		queue_free()


func _find_refs() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	game_manager = get_tree().get_first_node_in_group("game_manager")


func _run_is_locked() -> bool:
	return game_manager and game_manager.has_method("is_run_locked") and game_manager.is_run_locked()
