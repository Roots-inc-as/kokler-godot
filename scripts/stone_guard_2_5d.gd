extends CharacterBody3D

const HEALTH_BAR_SCRIPT := preload("res://scripts/health_bar_3d.gd")

@export var max_hp := 6
@export var move_speed := 1.15
@export var attack_range := 1.35
@export var damage := 2
@export var attack_cooldown := 1.15
@export var ground_y := 0.05
# AI ayarları
@export var detect_radius := 8.0
@export var nav_active_distance := 3.0
@export var lose_radius := 16.0

var hp := max_hp
var target: Node3D
var manager: Node
var _attack_timer := 0.0
var _health_bar: HealthBar3D
var _anim_time := 0.0
var _base_model_position := Vector3.ZERO
var _dying := false
# AI state machine
enum State { IDLE, CHASE, LOST }
var state: int = State.IDLE
var last_known_player_pos := Vector3.ZERO
var lost_timer := 0.0
var nav_agent: NavigationAgent3D
var nav_update_timer := 0.0

@onready var model: Node3D = $Model
@onready var hit_visual: MeshInstance3D = $Model/HitVisual


func _ready() -> void:
	add_to_group("enemy_2_5d")
	add_to_group("stone_guard_2_5d")
	hp = max_hp
	target = get_tree().get_first_node_in_group("player_2_5d")
	manager = get_tree().current_scene
	_anim_time = randf() * TAU
	if model:
		_base_model_position = model.position
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.y_offset = 1.65
	_health_bar.width = 1.15
	add_child(_health_bar)
	_health_bar.set_health(hp, max_hp)
	if hit_visual:
		hit_visual.visible = false
		# NavigationAgent3D ekle
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.radius = 0.2
	nav_agent.height = 1.2
	nav_agent.avoidance_enabled = false
	nav_agent.path_max_distance = 50.0
	add_child(nav_agent)
	


func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector3.ZERO
		global_position.y = ground_y
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player_2_5d")
		velocity = Vector3.ZERO
		move_and_slide()
		global_position.y = ground_y
		return

	if _run_is_locked():
		velocity = Vector3.ZERO
		move_and_slide()
		global_position.y = ground_y
		return

	# AI durumunu güncelle
	_update_state(delta)

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var direction := to_target.normalized() if distance > 0.05 else Vector3.ZERO

	# Duruma göre hareket
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.CHASE:
			# Yakındayken NavAgent'i bırak, direkt yaklaş (yoksa NavAgent durdurur)
			if distance > attack_range + nav_active_distance:
				# Uzaktayken NavAgent ile dolan
				velocity = _navigation_movement(target.global_position) * move_speed
			elif distance > attack_range:
				# Yakındayken doğrudan hedefe yaklaş
				velocity = direction * move_speed
			else:
				# attack_range içindeyken vur
				velocity = Vector3.ZERO
				if _attack_timer <= 0.0:
					_attack_timer = attack_cooldown
					_slam()
		State.LOST:
			# Son bilinen yere NavAgent ile git
			var to_last := last_known_player_pos - global_position
			to_last.y = 0.0
			if to_last.length() > 0.5:
				velocity = _navigation_movement(last_known_player_pos) * move_speed * 0.7
			else:
				velocity = Vector3.ZERO

	move_and_slide()
	global_position.y = ground_y

	if direction.length_squared() > 0.001 and state != State.IDLE:
		model.look_at(global_position + direction, Vector3.UP)
	_animate_heavy_idle(delta, velocity.length())


func take_damage(amount: int) -> void:
	if _dying:
		return
	var reduced := amount
	if amount > 1:
		reduced = max(amount - 1, 1)
	hp -= reduced
	if state == State.IDLE:
		state = State.CHASE
	_flash_hit()
	if _health_bar:
		_health_bar.set_health(hp, max_hp)
	if hp <= 0:
		_die()


func apply_knockback(from_position: Vector3, force: float) -> void:
	var away := global_position - from_position
	away.y = 0.0
	if away.length_squared() > 0.001:
		velocity += away.normalized() * force * 0.35


func _slam() -> void:
	if _run_is_locked():
		return
	if model:
		var body_tween := create_tween()
		body_tween.tween_property(model, "scale", Vector3(1.08, 0.92, 1.08), 0.08)
		body_tween.tween_property(model, "scale", Vector3.ONE, 0.12)
	if hit_visual:
		hit_visual.visible = true
		hit_visual.scale = Vector3(0.4, 0.05, 0.4)
		var tween := create_tween()
		tween.tween_property(hit_visual, "scale", Vector3(2.2, 0.05, 2.2), 0.12)
		tween.tween_callback(func() -> void:
			if hit_visual:
				hit_visual.visible = false
		)
	if target and target.has_method("take_damage"):
		target.call("take_damage", damage)


func _run_is_locked() -> bool:
	return manager and manager.has_method("is_run_locked") and manager.is_run_locked()


func _animate_heavy_idle(delta: float, speed: float) -> void:
	if not model:
		return
	_anim_time += delta * (2.6 if speed > 0.05 else 1.15)
	model.position = _base_model_position + Vector3(0.0, absf(sin(_anim_time)) * (0.025 if speed > 0.05 else 0.01), 0.0)
	model.rotation.z = sin(_anim_time) * (0.04 if speed > 0.05 else 0.018)


func _flash_hit() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.04, 0.96, 1.04), 0.05)
	tween.tween_property(model, "scale", Vector3.ONE, 0.08)


func _die() -> void:
	if _dying:
		return
	_dying = true
	collision_layer = 0
	collision_mask = 0
	if manager and manager.has_method("enemy_died"):
		manager.call("enemy_died", "stone_guard", global_position)
	if _health_bar:
		_health_bar.visible = false
	_spawn_crumble_piece(Vector3(-0.22, 0.4, 0.0))
	_spawn_crumble_piece(Vector3(0.22, 0.3, 0.08))
	_spawn_crumble_piece(Vector3(0.0, 0.75, -0.08))
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.15, 0.18, 1.15), 0.24)
	tween.tween_callback(Callable(self, "queue_free"))


func _spawn_crumble_piece(local_offset: Vector3) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.16, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.33, 0.31)
	mat.roughness = 1.0
	var piece := MeshInstance3D.new()
	piece.name = "stone_guard_crumble"
	piece.mesh = mesh
	piece.material_override = mat
	parent.add_child(piece)
	piece.global_position = global_position + local_offset
	piece.rotation = Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)
	var tween := piece.create_tween()
	tween.tween_property(piece, "position", piece.position + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35)), 0.32)
	tween.parallel().tween_property(piece, "scale", Vector3(0.05, 0.05, 0.05), 0.32)
	tween.tween_callback(Callable(piece, "queue_free"))

# ─── AI STATE MACHINE ───
func _update_state(delta: float) -> void:
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	match state:
		State.IDLE:
			if distance <= detect_radius:
				state = State.CHASE
		State.CHASE:
			if distance > lose_radius:
				state = State.LOST
				last_known_player_pos = target.global_position
				lost_timer = 5.0
			else:
				last_known_player_pos = target.global_position
		State.LOST:
			lost_timer -= delta
			if distance <= detect_radius:
				state = State.CHASE
			elif lost_timer <= 0.0:
				state = State.IDLE

func _navigation_movement(destination: Vector3) -> Vector3:
	if nav_agent == null:
		return Vector3.ZERO
	
	# Hedefi periyodik güncelle
	nav_update_timer -= get_physics_process_delta_time()
	if nav_update_timer <= 0.0:
		nav_agent.target_position = destination
		nav_update_timer = 0.3
	
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	
	var next_pos := nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		return dir.normalized()
	return Vector3.ZERO
