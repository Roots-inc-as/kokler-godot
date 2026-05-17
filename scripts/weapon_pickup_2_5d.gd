extends Area3D

@export var weapon_id := "mace"
@export var spin_speed := 1.3

var manager: Node
var _picked_up := false
var _full_message_cooldown := 0.0

@onready var handle: MeshInstance3D = $Handle
@onready var head: MeshInstance3D = $Head
@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not manager:
		manager = get_tree().current_scene
	_apply_weapon_appearance()


func _process(delta: float) -> void:
	rotation.y += spin_speed * delta
	position.y = 0.45 + sin(Time.get_ticks_msec() * 0.003) * 0.05
	_full_message_cooldown = maxf(_full_message_cooldown - delta, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if _picked_up or not body.is_in_group("player_2_5d"):
		return
	if not (manager and manager.has_method("collect_weapon")):
		return
	
	var wm: WeaponManager25D = body.get("weapon_manager") as WeaponManager25D
	if wm:
		var full: bool = wm.is_inventory_full()
		var already: bool = wm.owned_weapons.has(weapon_id)
		
		if full and not already:
			if _full_message_cooldown > 0.0:
				return
			_full_message_cooldown = 2.5
			# Popup için kendimizi manager'a haber verelim
			if manager.has_method("set_pending_swap_pickup"):
				manager.set_pending_swap_pickup(self)
			manager.collect_weapon(weapon_id)
			return
	
	_picked_up = true
	manager.collect_weapon(weapon_id)
	queue_free()


# Silaha göre görüntüyü ayarla
func _apply_weapon_appearance() -> void:
	match weapon_id:
		"knife":
			_set_knife()
		"mace":
			_set_mace()
		"spear":
			_set_spear()
		"ember_staff":
			_set_ember_staff()
		"mushroom_sling":
			_set_mushroom_sling()
		_:
			_set_knife()  # bilinmeyen → varsayılan


# ─── Knife: ince uzun handle + küçük head ───
func _set_knife() -> void:
	_set_handle(Vector3(0.08, 0.08, 0.7), Color(0.85, 0.78, 0.55))
	if head:
		head.visible = false
	_set_ring(Vector3.ZERO, Color.WHITE, false)


# ─── Mace: kısa handle + büyük kalın head ───
func _set_mace() -> void:
	_set_handle(Vector3(0.08, 0.08, 0.4), Color(0.35, 0.28, 0.2))
	_set_head(Vector3(0.28, 0.28, 0.28), Color(0.55, 0.52, 0.5), Vector3(0, 0, 0.32))
	_set_ring(Vector3(0.0, 0.0, 0.0), Color(0.6, 0.5, 0.3), false)


# ─── Spear: uzun ince handle + sivri head ───
func _set_spear() -> void:
	_set_handle(Vector3(0.05, 0.05, 0.75), Color(0.45, 0.3, 0.2))
	_set_head(Vector3(0.08, 0.08, 0.28), Color(0.85, 0.82, 0.7), Vector3(0, 0, 0.55))
	_set_ring(Vector3(0.0, 0.0, 0.0), Color(0.6, 0.5, 0.3), false)


# ─── Ember Staff: uzun handle + parlak head ───
func _set_ember_staff() -> void:
	_set_handle(Vector3(0.07, 0.07, 0.65), Color(0.3, 0.2, 0.15))
	_set_head(Vector3(0.18, 0.18, 0.18), Color(1.5, 0.5, 0.15), Vector3(0, 0, 0.45))
	_set_ring(Vector3(0.0, 0.0, 0.0), Color(0.6, 0.5, 0.3), false)
	# Emission ile parlatma
	if head.material_override is StandardMaterial3D:
		var mat := head.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.1)
		mat.emission_energy_multiplier = 0.8


# ─── Mushroom Sling: kısa handle + yuvarlak head + halka belirgin ───
func _set_mushroom_sling() -> void:
	_set_handle(Vector3(0.06, 0.06, 0.35), Color(0.4, 0.25, 0.2))
	_set_head(Vector3(0.16, 0.12, 0.16), Color(0.78, 0.36, 0.45), Vector3(0, 0.05, 0.3))
	_set_ring(Vector3(-0.18, 0.0, 0.18), Color(0.55, 0.25, 0.3), true)


# ─── Yardımcı fonksiyonlar ───
func _set_handle(size: Vector3, color: Color) -> void:
	if not handle:
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	handle.mesh = mesh
	handle.position = Vector3.ZERO
	handle.material_override = _make_material(color)


func _set_head(size: Vector3, color: Color, position: Vector3) -> void:
	if not head:
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	head.mesh = mesh
	head.position = position
	head.material_override = _make_material(color)


func _set_ring(position: Vector3, color: Color, visible_ring: bool) -> void:
	if not ring:
		return
	ring.visible = visible_ring
	if visible_ring:
		ring.position = position
		ring.material_override = _make_material(color)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
