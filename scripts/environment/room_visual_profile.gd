class_name RoomVisualProfile
extends Resource

@export var id: StringName
@export var floor_material: Material
@export var wall_material: Material
@export var allowed_prop_tags: Array[StringName] = []
@export var landmark_chance := 0.0
@export var prop_density_min := 1
@export var prop_density_max := 4
@export var root_density := 0.25
@export var fungal_density := 0.0
@export var lighting_profile: StringName
@export var decal_tags: Array[StringName] = []
