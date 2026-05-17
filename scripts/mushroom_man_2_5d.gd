extends CharacterBody3D

const HEALTH_BAR_SCRIPT := preload("res://scripts/health_bar_3d.gd")

@export var max_hp := 3
@export var move_speed := 1.65
@export var preferred_distance := 3.4
@export var pulse_range := 4.4
@export var damage := 1
@export var pulse_cooldown := 1.35
@export var ground_y := 0.05
# AI ayarları
@export var detect_radius := 5.0
@export var lose_radius := 8.0

var hp := max_hp
var target: Node3D
var manager: Node
var _pulse_timer := 0.4
var _health_bar: HealthBar3D
var _anim_time := 0.0
var _base_model_position := Vector3.ZERO
var _cap_base_scale := Vector3.ONE
var _dying := false
# AI state machine
enum State { IDLE, CHASE, LOST }
var state: int = State.IDLE
var last_known_player_pos := Vector3.ZERO
var lost_timer := 0.0

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

	# Duruma göre hareket
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.CHASE:
			# Preferred distance koruma davranışı
			if distance > preferred_distance + 0.45:
				velocity = direction * move_speed
			elif distance < preferred_distance - 0.45:
				velocity = -direction * move_speed * 0.75
			else:
				velocity = Vector3.ZERO
		State.LOST:
			var to_last := last_known_player_pos - global_position
			to_last.y = 0.0
			if to_last.length() > 0.3:
				velocity = to_last.normalized() * move_speed * 0.7
			else:
				velocity = Vector3.ZERO

	move_and_slide()
	global_position.y = ground_y

	if direction.length_squared() > 0.001 and state != State.IDLE:
		model.look_at(global_position + direction, Vector3.UP)

	_animate_body(delta)

	# Pulse saldırısı sadece CHASE durumundayken
	if state == State.CHASE:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0 and distance <= pulse_range:
			_pulse_timer = pulse_cooldown
			_poison_pulse()

	if pulse_visual and pulse_visual.visible:
		pulse_visual.scale = pulse_visual.scale.lerp(Vector3(3.1, 0.04, 3.1), delta * 8.0)


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
	var away := global_position - from_position
	away.y = 0.0
	if away.length_squared() > 0.001:
		velocity += away.normalized() * force


func _poison_pulse() -> void:
	if _run_is_locked():
		return
	if pulse_visual:
		pulse_visual.visible = true
		pulse_visual.scale = Vector3(0.35, 0.04, 0.35)
		var tween := create_tween()
		tween.tween_property(pulse_visual, "scale", Vector3(3.1, 0.04, 3.1), 0.22)
		tween.tween_callback(func() -> void:
			if pulse_visual:
				pulse_visual.visible = false
		)
	if target and global_position.distance_to(target.global_position) <= pulse_range and target.has_method("take_damage"):
		target.call("take_damage", damage)


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


func _flash_hit() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.08, 0.92, 1.08), 0.05)
	tween.tween_property(model, "scale", Vector3.ONE, 0.08)


func _die() -> void:
	if _dying:
		return
	_dying = true
	collision_layer = 0
	collision_mask = 0
	if manager and manager.has_method("enemy_died"):
		manager.call("enemy_died", "mushroom_man", global_position)
	if _health_bar:
		_health_bar.visible = false
	if pulse_visual:
		pulse_visual.visible = true
		pulse_visual.scale = Vector3(0.5, 0.04, 0.5)
		var pulse_tween := create_tween()
		pulse_tween.tween_property(pulse_visual, "scale", Vector3(3.5, 0.04, 3.5), 0.2)
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.18, 0.12, 1.18), 0.2)
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
