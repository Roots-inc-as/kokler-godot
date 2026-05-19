extends Resource
class_name WeaponData

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_type: String = "melee"
@export var damage: int = 1
@export var attack_cooldown: float = 0.35
@export var range: float = 1.25
@export var knockback: float = 2.0
@export var animation_style: String = "slash"
@export var color: Color = Color(0.9, 0.85, 0.7)
@export var is_ranged: bool = false
@export var projectile_scene: PackedScene
@export var combo_window: float = 0.7
@export var always_knockback: bool = false


static func create(
	weapon_id: String,
	weapon_name: String,
	type_name: String,
	weapon_damage: int,
	cooldown: float,
	weapon_range: float,
	weapon_knockback: float,
	style: String,
	weapon_color: Color,
	ranged := false,
	projectile: PackedScene = null,
	combo_win: float = 0.7,
	always_kb: bool = false
) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = weapon_id
	weapon.display_name = weapon_name
	weapon.weapon_type = type_name
	weapon.damage = weapon_damage
	weapon.attack_cooldown = cooldown
	weapon.range = weapon_range
	weapon.knockback = weapon_knockback
	weapon.animation_style = style
	weapon.color = weapon_color
	weapon.is_ranged = ranged
	weapon.projectile_scene = projectile
	weapon.combo_window = combo_win
	weapon.always_knockback = always_kb
	return weapon
