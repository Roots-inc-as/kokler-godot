extends Area3D

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered or not body.is_in_group("player_2_5d"):
		return

	var story_manager := get_tree().get_first_node_in_group("mini_story_manager_2_5d")
	if story_manager and story_manager.has_method("try_exit"):
		story_manager.try_exit()
		if story_manager.has_method("has_player_key") and story_manager.has_player_key():
			triggered = true
