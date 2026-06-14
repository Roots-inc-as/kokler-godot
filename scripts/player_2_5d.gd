extends CharacterBody3D

const WEAPON_MANAGER_SCRIPT := preload("res://scripts/weapon_manager_2_5d.gd")

signal health_changed(current_hp: int, max_hp: int)
signal dash_cooldown_changed(is_ready: bool, remaining: float)
signal weapon_changed(display_name: String, slots_text: String)
signal died

@export var max_hp := 15
@export var move_speed := 4.5
@export var acceleration := 22.0
@export var dash_speed := 11.5
@export var dash_duration := 0.14
@export var dash_cooldown := 1.2
@export var attack_damage := 1
@export var attack_cooldown := 0.35
@export var attack_active_time := 0.12
@export var combo_window := 0.7
@export var combo_slow_factor := 0.2
@export var combo_3_damage_multiplier := 2
@export var combo_3_visual_scale := 1.6
# ─── Charged saldırı ayarları ───
@export var charge_time := 0.7
@export var charged_damage_multiplier := 2
@export var charged_knockback_multiplier := 1.5
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
# Charge durumu — her slot için ayrı
var charging_slot: int = 0           # 0=hiçbiri, 1 veya 2
var charge_elapsed: float = 0.0      # Geçen süre
var charge_ready: bool = false       # Charge tamamlandı mı?
var story_manager: Node
var weapon_manager: WeaponManager25D
var current_weapon: WeaponData
var _is_charged_swing: bool = false
var _pending_charged_damage: int = 0
var _pending_charged_knockback: float = 0.0


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
	call_deferred("_emit_health_state")
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
	
	if Input.is_action_just_pressed("inventory"):
		if not (_active_inventory_screen and is_instance_valid(_active_inventory_screen)) and not _ignore_inventory_key:
			_toggle_inventory_screen()
	# Kapatmadan sonra aynı basışı yuttuk; bayrağı her durumda temizle
	_ignore_inventory_key = false
	# ESC ile pause menü (envanter açıkken karışmasın)
	if Input.is_action_just_pressed("ui_cancel"):
		if not (_active_inventory_screen and is_instance_valid(_active_inventory_screen)) and not _ignore_pause_key:
			_toggle_pause_menu()
	_ignore_pause_key = false
	# TEST: B tuşu → doğrudan boss (son) mikro katına ışınlan
	if Input.is_physical_key_pressed(KEY_B) and not _debug_boss_key_held:
		_debug_boss_key_held = true
		if story_manager and story_manager.has_method("debug_jump_to_boss"):
			story_manager.call("debug_jump_to_boss")
	elif not Input.is_physical_key_pressed(KEY_B):
		_debug_boss_key_held = false
	# Sol tık (slot 1)
	if Input.is_action_just_pressed("attack"):
		_begin_charge(1)
	if Input.is_action_just_released("attack"):
		_release_charge(1)
	
	# Sağ tık (slot 2)
	if Input.is_action_just_pressed("attack_secondary"):
		_begin_charge(2)
	if Input.is_action_just_released("attack_secondary"):
		_release_charge(2)
	
	# Charge ilerleyişi
	_tick_charge(delta)

	if dash_time_remaining > 0.0:
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
		velocity = dash_direction * dash_speed
	else:
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0 and charging_slot == 0:
			_start_dash(move_direction)
		if dash_time_remaining > 0.0:
			velocity = dash_direction * dash_speed
		else:
			var current_speed := move_speed
			if attacking:
				current_speed *= combo_slow_factor
			elif charging_slot != 0:
				current_speed *= 0.5
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
	var final_knockback: float = 0.0
	
	if _is_charged_swing:
		final_damage = _pending_charged_damage
		final_knockback = _pending_charged_knockback
	else:
		var combo: int = combo_count if current_attack_slot == 1 else combo_count_2
		if combo == 3:
			final_damage *= combo_3_damage_multiplier
		if weapon and weapon.always_knockback:
			final_knockback = weapon.knockback
	
	body.call("take_damage", final_damage)
	if final_knockback > 0.0 and body.has_method("apply_knockback"):
		body.call("apply_knockback", global_position, final_knockback)
	
	if _is_charged_swing or (current_attack_slot == 1 and combo_count == 3) or (current_attack_slot == 2 and combo_count_2 == 3):
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

func _emit_health_state() -> void:
	health_changed.emit(current_hp, max_hp)

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
	if projectile == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(projectile)
	else:
		add_child(projectile)
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
		_add_key_action("inventory", KEY_I)


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

const INVENTORY_SCREEN_SCRIPT := preload("res://scripts/inventory_screen.gd")

var _active_inventory_screen: CanvasLayer
var _ignore_inventory_key := false

func _toggle_inventory_screen() -> void:
	# Zaten açıksa kapat
	if _active_inventory_screen and is_instance_valid(_active_inventory_screen):
		_active_inventory_screen.queue_free()
		_active_inventory_screen = null
		get_tree().paused = false
		return
	# Aç
	var screen: CanvasLayer = INVENTORY_SCREEN_SCRIPT.new()
	get_tree().current_scene.add_child(screen)
	screen.setup(weapon_manager)
	screen.closed.connect(_on_inventory_screen_closed)
	_active_inventory_screen = screen
	get_tree().paused = true


func _on_inventory_screen_closed() -> void:
	_active_inventory_screen = null
	get_tree().paused = false
	_ignore_inventory_key = true
	
	# ─── PAUSE MENÜ ───

const PAUSE_MENU_SCRIPT := preload("res://scripts/pause_menu_screen.gd")

var _active_pause_menu: CanvasLayer
var _ignore_pause_key := false
var _debug_boss_key_held := false

func _toggle_pause_menu() -> void:
	if _active_pause_menu and is_instance_valid(_active_pause_menu):
		_active_pause_menu.queue_free()
		_active_pause_menu = null
		get_tree().paused = false
		return
	var menu: CanvasLayer = PAUSE_MENU_SCRIPT.new()
	get_tree().current_scene.add_child(menu)
	menu.resumed.connect(_on_pause_menu_resumed)
	menu.restart_requested.connect(_on_pause_menu_restart)
	_active_pause_menu = menu
	get_tree().paused = true


func _on_pause_menu_resumed() -> void:
	_active_pause_menu = null
	get_tree().paused = false
	_ignore_pause_key = true
	


func _on_pause_menu_restart() -> void:
	_active_pause_menu = null
	get_tree().paused = false
	get_tree().reload_current_scene()

# ─── CHARGE SİSTEMİ ───

func _begin_charge(slot: int) -> void:
	# Henüz başka bir slot charge ediyorsa, başlama
	if charging_slot != 0:
		return
	# Bu slot'ta silah yoksa, başlama
	if not weapon_manager:
		return
	var weapon: WeaponData = weapon_manager.get_weapon_at_slot(slot)
	if not weapon:
		return
	# Cooldown kontrolü
	if slot == 1 and attack_cooldown_remaining > 0.0:
		return
	if slot == 2 and attack_cooldown_2_remaining > 0.0:
		return
	
	charging_slot = slot
	charge_elapsed = 0.0
	charge_ready = false


func _tick_charge(delta: float) -> void:
	if charging_slot == 0:
		return
	
	charge_elapsed += delta
	
	# Charge tamamlandı mı?
	if not charge_ready and charge_elapsed >= charge_time:
		charge_ready = true
		_on_charge_full()


func _release_charge(slot: int) -> void:
	# Bu slot charge etmiyorsa, normal saldırı (combo) tetiklenir
	if charging_slot != slot:
		return
	
	var was_charged := charge_ready
	var fired_slot := charging_slot
	
	# State temizle
	charging_slot = 0
	charge_elapsed = 0.0
	charge_ready = false
	_clear_charge_visual()
	
	# Charged ya da normal saldırı
	if was_charged:
		_perform_charged_attack(fired_slot)
	else:
		_start_attack_with_slot(fired_slot)


func _on_charge_full() -> void:
	# Charge dolduğunda görsel feedback
	if attack_visual:
		attack_visual.visible = true
		attack_visual.scale = attack_visual_base_scale * 1.3
		_set_attack_visual_color(Color(2.0, 1.8, 0.5))  # sarı parıltı


func _clear_charge_visual() -> void:
	if attack_visual and not attacking:
		attack_visual.visible = false
		attack_visual.scale = attack_visual_base_scale


func _perform_charged_attack(slot: int) -> void:
	if not weapon_manager:
		return
	var weapon: WeaponData = weapon_manager.get_weapon_at_slot(slot)
	if not weapon:
		return
	
	# Cooldown ayarla (normal saldırının iki katı)
	if slot == 1:
		attack_cooldown_remaining = weapon.attack_cooldown * 1.5
	else:
		attack_cooldown_2_remaining = weapon.attack_cooldown * 1.5
	
	# Comboyu sıfırla (charged bağımsız)
	if slot == 1:
		combo_count = 0
		combo_window_remaining = 0.0
	else:
		combo_count_2 = 0
		combo_window_2_remaining = 0.0
	
	current_attack_slot = slot
	_swing_charged(slot, weapon)

func _swing_charged(slot: int, weapon: WeaponData) -> void:
	hit_targets.clear()
	attacking = true
	
	_configure_attack_area(weapon)
	attack_visual.visible = true
	attack_visual.scale = attack_visual_base_scale * 1.8
	_set_attack_visual_color(Color(1.5, 0.4, 0.4))
	
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
	
	# Charged damage'i hazırla
	_pending_charged_damage = weapon.damage * charged_damage_multiplier
	_pending_charged_knockback = weapon.knockback * charged_knockback_multiplier
	_is_charged_swing = true
	
	await get_tree().physics_frame
	_damage_overlapping_enemies()  # mevcut fonksiyon kullanılacak
	await get_tree().create_timer(attack_active_time).timeout
	_finish_attack()
	
	_is_charged_swing = false
	_hit_pause()
