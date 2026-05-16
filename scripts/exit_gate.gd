extends Area2D

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered or not body.is_in_group("player"):
		return

	var game_manager := get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("try_exit"):
		game_manager.try_exit()
		if bool(game_manager.get("has_key")):
			triggered = true
