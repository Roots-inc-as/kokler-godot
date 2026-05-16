extends Area3D

@export var visual_path: NodePath = NodePath("KeyVisual")
@export var spin_speed := 1.0

var collected := false
var visual: Node3D


func _ready() -> void:
	visual = get_node_or_null(visual_path) as Node3D
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if visual and is_instance_valid(visual):
		visual.rotate_y(delta * spin_speed)


func _on_body_entered(body: Node) -> void:
	if collected or not body.is_in_group("player_2_5d"):
		return

	collected = true
	var story_manager := get_tree().get_first_node_in_group("mini_story_manager_2_5d")
	if story_manager and story_manager.has_method("collect_key"):
		story_manager.collect_key()
	queue_free()
