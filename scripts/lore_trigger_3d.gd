extends Area3D

@export_multiline var message := ""
@export var duration := 3.5
@export var show_once := true

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered and show_once:
		return
	if not body.is_in_group("player_2_5d"):
		return

	triggered = true
	var story_manager := get_tree().get_first_node_in_group("mini_story_manager_2_5d")
	if story_manager and story_manager.has_method("show_lore_message"):
		story_manager.call("show_lore_message", message, duration)
	elif story_manager and story_manager.has_method("show_message"):
		story_manager.call("show_message", message, duration)
