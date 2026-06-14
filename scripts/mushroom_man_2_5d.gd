extends CharacterBody3D

const HEALTH_BAR_SCRIPT := preload("res://scripts/health_bar_3d.gd")
const SPORE_PROJECTILE_SCENE := preload("res://scenes/spore_projectile_2_5d.tscn")

@export var max_hp := 3
@export var move_speed := 1.65
@export var preferred_distance := 3.4
@export var pulse_range := 8.0
@export var damage := 1
@export var pulse_cooldown := 1.35
@export var ground_y := 0.05
# AI ayarları
@export var detect_radius := 22.0
@export var lose_radius := 24.0
@export var nav_active_distance := 3.0

var hp := max_hp
var target: Node3D
var manager: Node
var _pulse_timer := 0.4
var _health_bar: HealthBar3D
var _anim_time := 0.0
var _base_model_position := Vector3.ZERO
var _cap_base_scale := Vector3.ONE
var _model_base_scale := Vector3.ONE
var _dying := false
# AI state machine
enum State { IDLE, CHASE, LOST }
var state: int = State.IDLE
var last_known_player_pos := Vector3.ZERO
var lost_timer := 0.0
var knockback_velocity := Vector3.ZERO
var knockback_remaining := 0.0
var nav_agent: NavigationAgent3D
var nav_update_timer := 0.0

@onready var model: Node3D = $Model
@onready var cap: MeshInstance3D = $Model/Cap
@onready var pulse_visual: MeshInstance3D = $Model/PulseVisual


func _ready() -> void:
	add_to_group("enemy_2_5d")
	add_to_group("mushroom_man_2_5d")
	hp = max_hp
	target = get_tree().get_first_node_in_group("player_2_5d")
	manager = get_tree().current_scene
	_anim_time = randf() * TAU
	if model:
		_base_model_position = model.position
		_model_base_scale = model.scale
	if cap:
		_cap_base_scale = cap.scale
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.y_offset = 1.35
	add_child(_health_bar)
	_health_bar.set_health(hp, max_hp)
	if pulse_visual:
		pulse_visual.visible = false


func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector3.ZERO
		global_position.y = ground_y
		return

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

	# Knockback timer
	if knockback_remaining > 0.0:
		knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	# Duruma göre hareket
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.CHASE:
			# Çok uzaktayken NavAgent ile yaklaş
			if distance > preferred_distance + nav_active_distance:
				velocity = _navigation_movement(target.global_position) * move_speed
			# Preferred mesafenin biraz üstündeyken direkt yaklaş
			elif distance > preferred_distance + 0.45:
				velocity = direction * move_speed
			# Çok yakındaysa geri çekil (NavAgent kullanmıyoruz, direkt geri)
			elif distance < preferred_distance - 0.45:
				velocity = -direction * move_speed * 0.75
			else:
				velocity = Vector3.ZERO
		State.LOST:
			var to_last := last_known_player_pos - global_position
			to_last.y = 0.0
			if to_last.length() > 0.5:
				velocity = _navigation_movement(last_known_player_pos) * move_speed * 0.7
			else:
				velocity = Vector3.ZERO
	# Knockback aktifse normal hareketi geçersiz kıl
	if knockback_remaining > 0.0:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z

	move_and_slide()
	global_position.y = ground_y

	if direction.length_squared() > 0.001 and state != State.IDLE:
		model.look_at(global_position + direction, Vector3.UP)

	_animate_body(delta)

	# Pulse saldırısı sadece CHASE ve knockback yokken
	if state == State.CHASE and knockback_remaining <= 0.0:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0 and distance <= pulse_range:
			_pulse_timer = pulse_cooldown
			_fire_spores()

	if pulse_visual and pulse_visual.visible:
		pulse_visual.scale = pulse_visual.scale.lerp(Vector3(3.1, 0.04, 3.1), delta * 8.0)
		
		# NavigationAgent3D ekle
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.radius = 0.2
	nav_agent.height = 1.2
	nav_agent.avoidance_enabled = false
	nav_agent.path_max_distance = 200
	add_child(nav_agent)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= max(amount, 1)
	if state == State.IDLE:
		state = State.CHASE
	_flash_hit()
	if _health_bar:
		_health_bar.set_health(hp, max_hp)
	if hp <= 0:
		_die()


func apply_knockback(from_position: Vector3, force: float) -> void:
	var push_dir := global_position - from_position
	push_dir.y = 0.0
	if push_dir.length_squared() > 0.01:
		knockback_velocity = push_dir.normalized() * force * 1.5
		knockback_remaining = 0.15

func _fire_spores() -> void:
	if _run_is_locked() or _dying:
		return
	# Görsel: kısa bir nabız efekti
	if pulse_visual:
		pulse_visual.visible = true
		pulse_visual.scale = Vector3(0.35, 0.04, 0.35)
		var tween := create_tween()
		tween.tween_property(pulse_visual, "scale", Vector3(2.2, 0.04, 2.2), 0.18)
		tween.tween_callback(func() -> void:
			if pulse_visual:
				pulse_visual.visible = false
		)

	# Boss 8 yöne, normal 4 yöne ateş eder
	var is_boss: bool = has_meta("is_boss") and get_meta("is_boss")
	var base_angles: Array = []
	if is_boss:
		for i in range(8):
			base_angles.append(deg_to_rad(float(i) * 45.0))
	else:
		for i in range(4):
			base_angles.append(deg_to_rad(float(i) * 90.0))

	# Her yönde 2 mermi
	var spread := deg_to_rad(8.0)
	for angle in base_angles:
		for offset in [-spread, spread]:
			var a: float = angle + offset
			var dir := Vector3(sin(a), 0.0, cos(a))
			_spawn_spore(dir)


func _spawn_spore(dir: Vector3) -> void:
	var spore := SPORE_PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(spore)
	var start_pos := global_position + dir * 0.6
	start_pos.y = 0.35
	spore.setup(start_pos, dir, damage, self)


func _run_is_locked() -> bool:
	return manager and manager.has_method("is_run_locked") and manager.is_run_locked()


func _animate_body(delta: float) -> void:
	if not model:
		return
	_anim_time += delta * 2.8
	model.position = _base_model_position + Vector3(0.0, sin(_anim_time) * 0.035, 0.0)
	if cap:
		var pulse := 1.0 + sin(_anim_time * 1.35) * 0.055
		cap.scale = Vector3(_cap_base_scale.x * pulse, _cap_base_scale.y * (1.0 - (pulse - 1.0) * 0.6), _cap_base_scale.z * pulse)


func refresh_base_scale() -> void:
	if model:
		_model_base_scale = model.scale


func _flash_hit() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", _model_base_scale * Vector3(1.08, 0.92, 1.08), 0.05)
	tween.tween_property(model, "scale", _model_base_scale, 0.08)


func _die() -> void:
	if _dying:
		return
	_dying = true
	collision_layer = 0
	collision_mask = 0
	if manager and manager.has_method("enemy_died"):
		manager.call("enemy_died", "mushroom_man", global_position, self)
	if _health_bar:
		_health_bar.visible = false
	if pulse_visual:
		pulse_visual.visible = true
		pulse_visual.scale = Vector3(0.5, 0.04, 0.5)
		var pulse_tween := create_tween()
		pulse_tween.tween_property(pulse_visual, "scale", Vector3(3.5, 0.04, 3.5), 0.2)
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(_model_base_scale.x * 1.18, _model_base_scale.y * 0.12, _model_base_scale.z * 1.18), 0.2)
	tween.tween_callback(Callable(self, "queue_free"))

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
				lost_timer = 2.5
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
