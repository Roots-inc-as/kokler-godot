class_name PropDefinition
extends Resource

@export var id: StringName
@export var scene: PackedScene
@export var placement_tags: Array[StringName] = []
@export var room_tags: Array[StringName] = []
@export var weight := 1.0
@export var minimum_clearance := 1.0
@export var blocks_navigation := false
@export var landmark := false
@export var interactive := false
@export var corruption_variant: PackedScene
@export var minimap_symbol := ""
