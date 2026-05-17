extends CharacterBody3D

const WEAPON_MANAGER_SCRIPT := preload("res://scripts/weapon_manager_2_5d.gd")

signal health_changed(current_hp: int, max_hp: int)
signal dash_cooldown_changed(is_ready: bool, remaining: float)
signal weapon_changed(display_name: String, slots_text: String)
signal died

@export var max_hp := 5
@export var move_speed := 4.2
@export var acceleration := 22.0
@export var dash_speed := 11.5
@export var dash_duration := 0.14
@export var dash_cooldown := 0.8
@export var attack_damage := 1
@export var attack_cooldown := 0.35
@export var attack_active_time := 0.12
@export var combo_window := 0.7
@export var combo_slow_factor := 0.2
@export var combo_3_damage_multiplier := 2
@export var combo_3_visual_scale := 1.6
@export var invulnerable_time := 0.45
@export var ground_y := 0.0

@onready var model: Node3D = $Model
@onready var attack_area: Area3D = $Model/AttackArea
@onready var attack_shape: CollisionShape3D = $Model/AttackArea/CollisionShape3D
@onready var attack_visual: MeshInstance3D = $Model/AttackArea/AttackVisual

var current_hp := 0
var last_direction := Vector3.BACK
var dash_direction := Vector3.BACK
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
# İki silah için ayrı cooldownlar
var attack_cooldown_remaining := 0.0  # Slot 1 (sol tık)
var attack_cooldown_2_remaining := 0.0  # Slot 2 (sağ tık)

# İki silah için ayrı combolar
var combo_count_2 := 0
var combo_window_2_remaining := 0.0

# Şu an saldıran slot (1 veya 2)
var current_attack_slot := 1
var invulnerable_remaining := 0.0
var hit_targets := {}
var combo_count := 0
var combo_window_remaining := 0.0
var attacking := false
var attack_visual_base_scale := Vector3.ONE
var story_manager: Node
var weapon_manager: WeaponManager25D
var current_weapon: WeaponData


func _ready() -> void:
	add_to_group("player_2_5d")
	_ensure_input_actions()
	_setup_weapon_manager()

	current_hp = max_hp
	global_position.y = ground_y
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true
	attack_visual.visible = false
	attack_visual_base_scale = attack_visual.scale
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	call_deferred("_sync_story_manager")
	health_changed.emit(current_hp, max_hp)
	dash_cooldown_changed.emit(true, 0.0)
	call_deferred("_emit_weapon_state")


func _physics_process(delta: float) -> void:
	if story_manager == null:
		_sync_story_manager()

	_tick_timers(delta)
	_emit_dash_state()

	if _run_is_locked():
		velocity = Vector3.ZERO
		_lock_to_ground()
		move_and_slide()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if move_direction.length_squared() > 0.001:
		last_direction = move_direction.normalized()
		model.rotation.y = atan2(last_direction.x, last_direction.z)

	_handle_weapon_switch_input()

	if Input.is_action_just_pressed("attack"):
		_start_attack_with_slot(1)
	if Input.is_action_just_pressed("attack_secondary"):
		_start_attack_with_slot(2)

	if dash_time_remaining > 0.0:
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
		velocity = dash_direction * dash_speed
	else:
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0:
			_start_dash(move_direction)
		if dash_time_remaining > 0.0:
			velocity = dash_direction * dash_speed
		else:
			var current_speed := move_speed
			if attacking:
				current_speed *= combo_slow_factor
			var target_velocity := move_direction * current_speed
			velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	velocity.y = 0.0
	move_and_slide()
	_lock_to_ground()
	
	

func get_health_state() -> Dictionary:
	return {
		"current": current_hp,
		"max": max_hp,
	}


func take_damage(amount: int) -> void:
	if current_hp <= 0 or invulnerable_remaining > 0.0 or _run_is_locked():
		return

	current_hp = maxi(current_hp - amount, 0)
	_trigger_hit_flash()
	invulnerable_remaining = invulnerable_time
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		died.emit()
		if story_manager and story_manager.has_method("player_died"):
			story_manager.call("player_died")


func add_weapon_to_inventory(weapon_id: String) -> bool:
	if weapon_manager and weapon_manager.has_method("add_weapon"):
		var added: bool = weapon_manager.add_weapon(weapon_id)
		_emit_weapon_state()
		return added
	return false


func get_weapon_display_name(weapon_id: String) -> String:
	if weapon_manager and weapon_manager.has_method("get_weapon"):
		var weapon: WeaponData = weapon_manager.get_weapon(weapon_id)
		if weapon:
			return weapon.display_name
	return weapon_id


func _tick_timers(delta: float) -> void:
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	attack_cooldown_2_remaining = maxf(attack_cooldown_2_remaining - delta, 0.0)
	invulnerable_remaining = maxf(invulnerable_remaining - delta, 0.0)
	combo_window_remaining = maxf(combo_window_remaining - delta, 0.0)
	combo_window_2_remaining = maxf(combo_window_2_remaining - delta, 0.0)
	if combo_window_remaining <= 0.0:
		combo_count = 0
	if combo_window_2_remaining <= 0.0:
		combo_count_2 = 0


func _start_dash(move_direction: Vector3) -> void:
	dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.001 else last_direction
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	_emit_dash_state()


func _start_attack_with_slot(slot: int) -> void:
	if not weapon_manager:
		return
	var weapon: WeaponData = weapon_manager.get_weapon_at_slot(slot)
	if not weapon:
		return  # O slot boş
	
	# Doğru cooldown'u kontrol et
	if slot == 1:
		if attack_cooldown_remaining > 0.0:
			return
		attack_cooldown_remaining = weapon.attack_cooldown
		combo_count = (combo_count + 1) if combo_window_remaining > 0.0 else 1
		if combo_count > 3:
			combo_count = 1
		combo_window_remaining = weapon.combo_window
	else:
		if attack_cooldown_2_remaining > 0.0:
			return
		attack_cooldown_2_remaining = weapon.attack_cooldown
		combo_count_2 = (combo_count_2 + 1) if combo_window_2_remaining > 0.0 else 1
		if combo_count_2 > 3:
			combo_count_2 = 1
		combo_window_2_remaining = weapon.combo_window
	
	current_attack_slot = slot
	_swing_weapon_for_slot(slot, weapon)


# Eski _start_attack'ı geriye uyumluluk için tut (combo gibi başka yerden çağrılıyor olabilir)
func _start_attack() -> void:
	_start_attack_with_slot(1)

	var weapon := _get_current_weapon()
	attack_cooldown_remaining = weapon.attack_cooldown if weapon else attack_cooldown

	combo_count = (combo_count + 1) if combo_window_remaining > 0.0 else 1
	if combo_count > 3:
		combo_count = 1
	combo_window_remaining = weapon.combo_window if weapon else combo_window

	_swing_weapon()


func _swing_weapon_for_slot(slot: int, weapon: WeaponData) -> void:
	hit_targets.clear()
	attacking = true
	var combo := combo_count if slot == 1 else combo_count_2
	var is_combo_finisher := combo == 3

	_configure_attack_area(weapon)
	attack_visual.visible = true

	if is_combo_finisher:
		attack_visual.scale = attack_visual_base_scale * combo_3_visual_scale
		_set_attack_visual_color(Color(1.5, 0.4, 0.4))
	else:
		attack_visual.scale = attack_visual_base_scale
		_set_attack_visual_color(weapon.color if weapon else Color(1.0, 1.0, 1.0))

	_animate_attack_visual(weapon, is_combo_finisher)

	if weapon and weapon.is_ranged:
		attack_area.monitoring = false
		attack_area.monitorable = false
		attack_shape.disabled = true
		_fire_projectile(weapon)
		await get_tree().create_timer(attack_active_time).timeout
		_finish_attack()
		return

	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_shape.disabled = false

	await get_tree().physics_frame
	_damage_overlapping_enemies()
	await get_tree().create_timer(attack_active_time).timeout
	_finish_attack()


# Eski _swing_weapon'u geriye uyumluluk için tut
func _swing_weapon() -> void:
	var weapon := _get_current_weapon()
	if weapon:
		_swing_weapon_for_slot(1, weapon)


func _damage_overlapping_enemies() -> void:
	for body in attack_area.get_overlapping_bodies():
		_damage_enemy(body)


func _on_attack_area_body_entered(body: Node) -> void:
	if attack_area.monitoring:
		_damage_enemy(body)


func _damage_enemy(body: Node) -> void:
	if body == self or not body.has_method("take_damage"):
		return

	var body_id := body.get_instance_id()
	if hit_targets.has(body_id):
		return

	hit_targets[body_id] = true
	var weapon: WeaponData = weapon_manager.get_weapon_at_slot(current_attack_slot) if weapon_manager else null
	var final_damage: int = weapon.damage if weapon else attack_damage
	var combo: int = combo_count if current_attack_slot == 1 else combo_count_2
	if combo == 3:
		final_damage *= combo_3_damage_multiplier
	body.call("take_damage", final_damage)
	if weapon and body.has_method("apply_knockback"):
		body.call("apply_knockback", global_position, weapon.knockback)
	if combo == 3:
		_hit_pause()


func _setup_weapon_manager() -> void:
	weapon_manager = WEAPON_MANAGER_SCRIPT.new() as WeaponManager25D
	weapon_manager.name = "WeaponManager25D"
	weapon_manager.weapon_changed.connect(_on_weapon_manager_changed)
	add_child(weapon_manager)
	if weapon_manager.has_method("setup_default_weapons"):
		weapon_manager.setup_default_weapons()


func _get_current_weapon() -> WeaponData:
	if weapon_manager and weapon_manager.has_method("get_current_weapon"):
		return weapon_manager.get_current_weapon()
	return null


func _handle_weapon_switch_input() -> void:
	if not weapon_manager:
		return
	for i in range(5):
		if Input.is_action_just_pressed(StringName("weapon_%d" % [i + 1])):
			weapon_manager.switch_to_slot(i + 1)


func _on_weapon_manager_changed(weapon: WeaponData, _owned_weapons: Array[String]) -> void:
	current_weapon = weapon
	_emit_weapon_state()


func _emit_weapon_state() -> void:
	var weapon := _get_current_weapon()
	if not weapon:
		return
	var slots_text := ""
	if weapon_manager and weapon_manager.has_method("get_owned_display_text"):
		slots_text = weapon_manager.get_owned_display_text()
	weapon_changed.emit(weapon.display_name, slots_text)


func _configure_attack_area(weapon: WeaponData) -> void:
	var weapon_range := weapon.range if weapon else 1.25
	if weapon and weapon.is_ranged:
		weapon_range = 0.9
	var width := maxf(0.95, weapon_range * 0.72)
	attack_area.position = Vector3(0.0, 0.58, 0.42 + weapon_range * 0.5)
	attack_area.rotation = Vector3.ZERO
	var box_shape := attack_shape.shape as BoxShape3D
	if box_shape:
		box_shape.size = Vector3(width, 0.9, weapon_range)
	var box_mesh := attack_visual.mesh as BoxMesh
	if box_mesh:
		box_mesh.size = Vector3(width, 0.08, weapon_range)
	attack_visual.position = Vector3(0.0, -0.4, 0.0)


func _animate_attack_visual(weapon: WeaponData, is_combo_finisher: bool) -> void:
	if not weapon:
		return
	var tween := create_tween()
	match weapon.animation_style:
		"heavy":
			attack_area.rotation.x = -0.65
			tween.tween_property(attack_area, "rotation:x", 0.35, 0.18)
		"thrust":
			attack_visual.position.z = -0.35
			tween.tween_property(attack_visual, "position:z", 0.28, 0.10)
		"ember":
			attack_area.rotation.y = -0.55
			attack_visual.scale = attack_visual_base_scale * (1.35 if not is_combo_finisher else combo_3_visual_scale)
			tween.tween_property(attack_area, "rotation:y", 0.55, 0.13)
		"sling":
			attack_visual.scale = attack_visual_base_scale * 0.75
			tween.tween_property(attack_visual, "scale", attack_visual_base_scale * 1.15, 0.08)
		_:
			attack_area.rotation.y = -0.45
			tween.tween_property(attack_area, "rotation:y", 0.45, 0.09)


func _fire_projectile(weapon: WeaponData) -> void:
	if not weapon.projectile_scene:
		return
	var projectile := weapon.projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(projectile)
	var start_position := global_position + Vector3(0.0, 0.45, 0.0) + last_direction.normalized() * 0.85
	if projectile.has_method("setup"):
		projectile.call("setup", start_position, last_direction, weapon.damage, self)
	else:
		projectile.global_position = start_position


func _finish_attack() -> void:
	attacking = false
	if is_instance_valid(attack_area):
		attack_area.monitoring = false
		attack_area.monitorable = false
		attack_area.rotation = Vector3.ZERO
	if is_instance_valid(attack_shape):
		attack_shape.disabled = true
	if is_instance_valid(attack_visual):
		attack_visual.visible = false
		attack_visual.scale = attack_visual_base_scale
		attack_visual.position = Vector3(0.0, -0.4, 0.0)


func _lock_to_ground() -> void:
	global_position.y = ground_y
	velocity.y = 0.0


func _sync_story_manager() -> void:
	story_manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _run_is_locked() -> bool:
	return story_manager and story_manager.has_method("is_run_locked") and story_manager.is_run_locked()


func _emit_dash_state() -> void:
	dash_cooldown_changed.emit(dash_cooldown_remaining <= 0.0, dash_cooldown_remaining)


func _ensure_input_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("dash", KEY_SPACE)
	_add_key_action("attack", KEY_J)
	_add_mouse_action("attack", MOUSE_BUTTON_LEFT)
	_add_key_action("attack_secondary", KEY_K)
	_add_mouse_action("attack_secondary", MOUSE_BUTTON_RIGHT)
	for i in range(5):
		_add_key_action(StringName("weapon_%d" % [i + 1]), KEY_1 + i)


func _add_key_action(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
			return

	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _add_mouse_action(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			return

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _set_attack_visual_color(color: Color) -> void:
	if attack_visual is MeshInstance3D:
		var mesh_instance := attack_visual as MeshInstance3D
		if mesh_instance.material_override == null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mesh_instance.material_override = mat
		else:
			var mat := mesh_instance.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = color
				mat.emission = color


func _trigger_hit_flash() -> void:
	var ui_node := get_tree().get_first_node_in_group("ui_2_5d")
	if ui_node and ui_node.has_method("flash_damage"):
		ui_node.flash_damage()


func _hit_pause(duration: float = 0.06, scale: float = 0.05) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
