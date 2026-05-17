extends Area3D

@export var spin_speed := 1.8

var manager: Node
var _picked_up := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not manager:
		manager = get_tree().current_scene


func _process(delta: float) -> void:
	rotation.y += spin_speed * delta


func _on_body_entered(body: Node3D) -> void:
	if _picked_up or not body.is_in_group("player_2_5d"):
		return
	_picked_up = true
	if manager and manager.has_method("collect_root_fragment"):
		manager.collect_root_fragment(1)
	queue_free()
