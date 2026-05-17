extends Area3D

@export var weapon_id := "mace"
@export var spin_speed := 1.3

var manager: Node
var _picked_up := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not manager:
		manager = get_tree().current_scene


func _process(delta: float) -> void:
	rotation.y += spin_speed * delta
	position.y = 0.45 + sin(Time.get_ticks_msec() * 0.003) * 0.05


func _on_body_entered(body: Node3D) -> void:
	if _picked_up or not body.is_in_group("player_2_5d"):
		return
	_picked_up = true
	if manager and manager.has_method("collect_weapon"):
		manager.collect_weapon(weapon_id)
	queue_free()
