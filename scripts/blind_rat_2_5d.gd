extends CharacterBody3D

# ─── Stat'lar ───
@export var max_hp := 2
@export var move_speed := 2.15
@export var acceleration := 10.0
@export var contact_damage := 1
@export var contact_damage_cooldown := 0.8
@export var contact_radius := 0.85
@export var ground_y := 0.0

# ─── AI mesafe ayarları ───
@export var detect_radius := 5.0          # Bu mesafede oyuncuyu fark eder
@export var lose_radius := 8.0            # Bu mesafede oyuncuyu kaybeder
@export var idle_wander_chance := 0.005   # Her frame'de bu olasılıkla rastgele yön değiştirir
@export var idle_wander_speed := 0.6      # Idle'dayken yürüme hızı

@onready var model: Node3D = $Model

enum State { IDLE, CHASE, LOST }

var current_hp := 0
var contact_cooldown_remaining := 0.0
var target: Node3D
var story_manager: Node

# AI durumu
var state: int = State.IDLE
var last_known_player_pos := Vector3.ZERO
var idle_direction := Vector3.ZERO
var lost_timer := 0.0
var nav_agent: NavigationAgent3D
var nav_update_timer := 0.0


func _ready() -> void:
	add_to_group("blind_rat_2_5d")
	current_hp = max_hp
	global_position.y = ground_y
	
	# NavigationAgent3D ekle
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 0.4
	nav_agent.target_desired_distance = 0.4
	nav_agent.radius = 0.2
	nav_agent.height = 1.2
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)
	
	call_deferred("_find_refs")


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_find_refs()

	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)

	if target == null or _run_is_locked():
		velocity = Vector3.ZERO
		_lock_to_ground()
		move_and_slide()
		return

	# AI durumunu güncelle
	_update_state(delta)
	
	# Duruma göre hareket et
	var desired_velocity := Vector3.ZERO
	match state:
		State.IDLE:
			desired_velocity = _idle_movement(delta)
		State.CHASE:
			desired_velocity = _chase_movement()
		State.LOST:
			desired_velocity = _lost_movement()
	
	# Velocity'i smooth uygula
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	velocity.y = 0.0
	
	# Modeli yürüdüğü yöne döndür
	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		model.rotation.y = atan2(velocity.x, velocity.z)
	
	move_and_slide()
	_lock_to_ground()
	
	# Temas hasarı (sadece CHASE durumundayken)
	if state == State.CHASE:
		var distance := target.global_position.distance_to(global_position)
		if distance <= contact_radius and contact_cooldown_remaining <= 0.0 and target.has_method("take_damage"):
			contact_cooldown_remaining = contact_damage_cooldown
			target.take_damage(contact_damage)


# ─── AI STATE MACHINE ───
func _update_state(delta: float) -> void:
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	
	match state:
		State.IDLE:
			# Oyuncu yakına gelirse chase'e geç
			if distance <= detect_radius:
				state = State.CHASE
				print("Rat: oyuncuyu fark etti")
		
		State.CHASE:
			# Oyuncu çok uzaklaşırsa kaybet
			if distance > lose_radius:
				state = State.LOST
				last_known_player_pos = target.global_position
				lost_timer = 2.0  # 2 saniye son bilinen yere git
				print("Rat: oyuncuyu kaybetti")
			else:
				# Hâlâ görünüyor — son bilinen yeri güncelle
				last_known_player_pos = target.global_position
		
		State.LOST:
			lost_timer -= delta
			# Eğer oyuncu tekrar yakına gelirse hemen chase
			if distance <= detect_radius:
				state = State.CHASE
				print("Rat: oyuncuyu tekrar fark etti")
			elif lost_timer <= 0.0:
				# Süre bitti, idle'a dön
				state = State.IDLE
				idle_direction = Vector3.ZERO
				print("Rat: arayışı bıraktı")


# ─── HAREKET FONKSİYONLARI ───
func _idle_movement(_delta: float) -> Vector3:
	# Çoğunlukla yerinde dur, ara sıra rastgele yöne yürü
	if randf() < idle_wander_chance:
		var random_angle := randf() * TAU
		idle_direction = Vector3(cos(random_angle), 0.0, sin(random_angle))
	
	# Kısa bir mesafeden sonra yürüyüşü durdur
	if idle_direction.length_squared() > 0.01 and randf() < 0.01:
		idle_direction = Vector3.ZERO
	
	return idle_direction * idle_wander_speed


func _chase_movement() -> Vector3:
	if nav_agent == null:
		return Vector3.ZERO
	
	# Hedefi her frame değil, periyodik olarak güncelle (performans)
	nav_update_timer -= get_physics_process_delta_time()
	if nav_update_timer <= 0.0:
		nav_agent.target_position = target.global_position
		nav_update_timer = 0.25
	
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	
	var next_pos := nav_agent.get_next_path_position()
	var direction := next_pos - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		return direction.normalized() * move_speed
	return Vector3.ZERO


func _lost_movement() -> Vector3:
	if nav_agent == null:
		return Vector3.ZERO
	
	nav_update_timer -= get_physics_process_delta_time()
	if nav_update_timer <= 0.0:
		nav_agent.target_position = last_known_player_pos
		nav_update_timer = 0.5
	
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	
	var next_pos := nav_agent.get_next_path_position()
	var direction := next_pos - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		return direction.normalized() * move_speed * 0.8
	return Vector3.ZERO


# ─── HASAR ───
func take_damage(amount: int) -> void:
	current_hp -= amount
	# Hasar alınca oyuncuyu otomatik fark et (görünmez bir yumruk yedi)
	if state == State.IDLE:
		state = State.CHASE
		print("Rat: hasar aldı, saldırıya geçti")
	
	if current_hp <= 0:
		queue_free()


# ─── YARDIMCI ───
func _find_refs() -> void:
	target = get_tree().get_first_node_in_group("player_2_5d") as Node3D
	story_manager = get_tree().get_first_node_in_group("mini_story_manager_2_5d")


func _run_is_locked() -> bool:
	return story_manager and story_manager.has_method("is_run_locked") and story_manager.is_run_locked()


func _lock_to_ground() -> void:
	global_position.y = ground_y
	velocity.y = 0.0
