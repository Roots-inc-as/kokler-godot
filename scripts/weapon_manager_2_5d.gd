extends Node
class_name WeaponManager25D

signal weapon_changed(weapon: WeaponData, owned_weapons: Array[String])

const PROJECTILE_SCENE := preload("res://scenes/spore_projectile_2_5d.tscn")
const MAX_WEAPONS := 2

var weapons: Dictionary = {}
var owned_weapons: Array[String] = []
var current_index := 0


func _ready() -> void:
	if weapons.is_empty():
		setup_default_weapons()


func setup_default_weapons() -> void:
	weapons.clear()
	_add_weapon_data(WeaponData.create("knife", "Haritacı Bıçağı", "melee", 1, 0.35, 1.25, 2.0, "slash", Color(0.95, 0.88, 0.68), false, null, 0.9))
	_add_weapon_data(WeaponData.create("mace", "Taş Tokmak", "melee", 3, 0.80, 1.20, 3.0, "heavy", Color(0.58, 0.55, 0.50), false, null, 1.4, true))
	_add_weapon_data(WeaponData.create("spear", "Kemik Mızrak", "melee", 2, 0.55, 1.85, 3.0, "thrust", Color(0.82, 0.78, 0.62), false, null, 1.2))
	_add_weapon_data(WeaponData.create("ember_staff", "Kor Çubuğu", "melee", 1, 0.70, 1.55, 2.5, "ember", Color(0.95, 0.35, 0.12), false, null, 1.3))
	_add_weapon_data(WeaponData.create("mushroom_sling", "Mantar Sapanı", "ranged", 1, 0.65, 5.5, 1.5, "sling", Color(0.78, 0.36, 0.45), true, PROJECTILE_SCENE, 1.3))
	if owned_weapons.is_empty():
		add_weapon("knife")
	current_index = clampi(current_index, 0, max(owned_weapons.size() - 1, 0))
	_emit_weapon_changed()


func _add_weapon_data(weapon: WeaponData) -> void:
	weapons[weapon.id] = weapon


func add_weapon(weapon_id: String) -> bool:
	if not weapons.has(weapon_id):
		return false
	if owned_weapons.has(weapon_id):
		return false
	# Envanter doluysa eklemeyi reddet — popup'la yer açıldıktan sonra eklenecek
	if owned_weapons.size() >= MAX_WEAPONS:
		return false
	owned_weapons.append(weapon_id)
	_emit_weapon_changed()
	return true


func is_inventory_full() -> bool:
	return owned_weapons.size() >= MAX_WEAPONS


# Belirli slottaki silahı çıkarır, ID'sini döner
func drop_weapon_at_slot(slot: int) -> String:
	var index := slot - 1
	if index < 0 or index >= owned_weapons.size():
		return ""
	var dropped_id: String = owned_weapons[index]
	owned_weapons.remove_at(index)
	# Current index'i güvenli aralıkta tut
	if owned_weapons.is_empty():
		current_index = 0
	else:
		current_index = clampi(current_index, 0, owned_weapons.size() - 1)
	_emit_weapon_changed()
	return dropped_id
	
	# Envanter dolu olsa bile silah ekler (popup sonrası kullanılır)
func force_add_weapon(weapon_id: String) -> bool:
	if not weapons.has(weapon_id):
		return false
	if owned_weapons.has(weapon_id):
		return false
	owned_weapons.append(weapon_id)
	_emit_weapon_changed()
	return true
	
	# Silahı belirli bir slot'a koyar (slot boş olmalı)
func add_weapon_at_slot(weapon_id: String, slot: int) -> bool:
	if not weapons.has(weapon_id):
		return false
	if owned_weapons.has(weapon_id):
		return false
	var index := slot - 1
	if index < 0 or index >= MAX_WEAPONS:
		return false
	# Yeni silahı seçilen slot'a yerleştir
	# Eğer o pozisyonda zaten bir şey yoksa append, varsa insert
	if index >= owned_weapons.size():
		owned_weapons.append(weapon_id)
	else:
		owned_weapons.insert(index, weapon_id)
	_emit_weapon_changed()
	return true


# İki slot'u yer değiştir (envanter ekranı için)
func swap_slots() -> bool:
	if owned_weapons.size() < 2:
		return false
	var temp = owned_weapons[0]
	owned_weapons[0] = owned_weapons[1]
	owned_weapons[1] = temp
	_emit_weapon_changed()
	return true


# Slottaki silahı getir (1 veya 2)
func get_weapon_at_slot(slot: int) -> WeaponData:
	var index := slot - 1
	if index < 0 or index >= owned_weapons.size():
		return null
	return weapons.get(owned_weapons[index]) as WeaponData


func switch_to_slot(slot: int) -> bool:
	var index := slot - 1
	if index < 0 or index >= owned_weapons.size():
		return false
	current_index = index
	_emit_weapon_changed()
	return true


func get_current_weapon() -> WeaponData:
	if owned_weapons.is_empty():
		add_weapon("knife")
	if owned_weapons.is_empty():
		return null
	current_index = clampi(current_index, 0, owned_weapons.size() - 1)
	return weapons.get(owned_weapons[current_index]) as WeaponData


func get_weapon(weapon_id: String) -> WeaponData:
	return weapons.get(weapon_id) as WeaponData


func get_owned_display_text() -> String:
	var parts: Array[String] = []
	for i in range(owned_weapons.size()):
		var weapon: WeaponData = weapons.get(owned_weapons[i]) as WeaponData
		if weapon:
			var prefix := str(i + 1)
			if i == current_index:
				prefix = "[" + prefix + "]"
			parts.append(prefix + " " + weapon.display_name)
	return "  ".join(parts)


func get_random_loot_weapon_id() -> String:
	var candidates: Array[String] = ["mace", "spear", "ember_staff", "mushroom_sling"]
	candidates.shuffle()
	for weapon_id in candidates:
		if not owned_weapons.has(weapon_id):
			return weapon_id
	return candidates[0]


func _emit_weapon_changed() -> void:
	var weapon := get_current_weapon()
	if weapon:
		weapon_changed.emit(weapon, owned_weapons)
