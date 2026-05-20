extends Area3D

var _armed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	await get_tree().create_timer(0.6).timeout
	_armed = true
	for body in get_overlapping_bodies():
		if body.is_in_group("player_2_5d"):
			_armed = false
			break


func _on_body_entered(body: Node) -> void:
	if not _armed or not body.is_in_group("player_2_5d"):
		return
	var story_manager := get_tree().get_first_node_in_group("mini_story_manager_2_5d")
	if story_manager and story_manager.has_method("go_back_micro_floor"):
		_armed = false
		story_manager.go_back_micro_floor()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player_2_5d"):
		_armed = true
