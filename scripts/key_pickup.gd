extends Area2D

var collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if collected or not body.is_in_group("player"):
		return

	collected = true
	var game_manager := get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("collect_key"):
		game_manager.collect_key()
	queue_free()
