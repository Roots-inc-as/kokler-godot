extends Node3D

const BLIND_RAT_SCENE := preload("res://scenes/blind_rat_2_5d.tscn")
const MUSHROOM_MAN_SCENE := preload("res://scenes/mushroom_man_2_5d.tscn")
const STONE_GUARD_SCENE := preload("res://scenes/stone_guard_2_5d.tscn")
const ROOT_FRAGMENT_SCENE := preload("res://scenes/root_fragment_pickup_2_5d.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/weapon_pickup_2_5d.tscn")
const ROOT_SHRINE_SCENE := preload("res://scenes/root_shrine_2_5d.tscn")
const KEY_PICKUP_SCRIPT := preload("res://scripts/key_pickup_2_5d.gd")
const EXIT_GATE_SCRIPT := preload("res://scripts/exit_gate_2_5d.gd")
const BACK_STAIR_SCRIPT := preload("res://scripts/back_stair_2_5d.gd")
const LORE_TRIGGER_SCRIPT := preload("res://scripts/lore_trigger_3d.gd")
const DEATH_SCREEN_SCRIPT := preload("res://scripts/death_screen.gd")

const GRID_SIZE := 10
const CELL_SPACING := 23.0
const MIN_ROOMS := 10
const MAX_ROOMS := 14
const CORRIDOR_WIDTH := 3.1
const DOOR_GAP := 3.2
const WALL_THICKNESS := 0.38
const WALL_HEIGHT := 1.45

const ROOM_STATE_UNKNOWN := "unknown"
const ROOM_STATE_DISCOVERED := "discovered"
const ROOM_STATE_ACTIVE_COMBAT := "active_combat"
const ROOM_STATE_CLEARED := "cleared"
const ROOM_STATE_SHIFTED := "shifted"
const MAIN_SCENE_PATH := "res://scenes/main_2_5d.tscn"
const NORMAL_ROOM_GATE_CLOSE_CHANCE := 0.20

static var dried_roots_bank := 0

# TODO: Future passive item resources can grow from these ids without touching
# weapon loot. v0.4 only keeps this catalogue as design-facing placeholder data.
const FUTURE_PASSIVE_ITEM_IDS: Array[String] = [
	"yara_bezi",
	"hiz_tasi",
	"kor_tozu",
	"kok_gozu",
	"golge_adimi",
	"kırık_hafıza",
	"kok_sarmasi",
	"keskin_bakis",
	"unutus_tasi",
	"olum_yankisi",
	"kan_pakti",
	"kor_yurek",
	"zaman_hirsizi",
]

@export var player_path: NodePath
@export var restart_delay := 1.1
@export var generation_seed := 0
@export var debug_print_generation := true
@export var debug_room_labels := false
@export var start_fullscreen := true
@export var spawn_debug_start_weapons := false

var player: Node3D
var ui: Node
var dungeon_root: Node3D
var has_key := false
var root_fragments := 0
var dried_roots := 0
var run_locked := false
# ─── Katman sistemi ───
var current_main_layer := 1            # Şu anki ana katman (1-4)
var max_main_layers := 4               # Toplam ana katman
var current_micro_floor := 1           # Mikro kat sayacı
var total_micro_floors := 3            # Bu ana katmanın toplam mikro kat sayısı
var key_floor := 1                     # Anahtar hangi mikro katta
# ─── Mikro kat state ───
var micro_floor_seeds: Dictionary = {}    # micro_floor_number → seed
var micro_floor_state: Dictionary = {}    # micro_floor_number → {"collected": [...], "dead_enemies": [...]}
var _spawn_at_exit_room := false
var _boss_required := false
var _boss_defeated := false
var _active_death_screen: CanvasLayer
var puzzle_message_time_msec := -10000
var current_room_id := ""
var labyrinth_shift_count := 0
var entropy_value := 0.0
var entropy_message_time_msec := -10000
var puzzle_shift_done := false
var key_shift_done := false
var death_reload_pending := false

var rooms: Dictionary = {}
var room_order: Array[String] = []
var cell_to_room_id: Dictionary = {}
var graph: Dictionary = {}
var corridor_variants: Dictionary = {}
var room_enemy_counts: Dictionary = {}
var room_states: Dictionary = {}
var room_combat_gates: Dictionary = {}
var room_clear_rewards_spawned: Dictionary = {}
var blocking_prop_positions: Dictionary = {}
var discovered_rooms: Dictionary = {}
var shown_lore_messages: Dictionary = {}
var mats: Dictionary = {}

var start_cell := Vector2i.ZERO
var key_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var start_room_id := ""
var key_room_id := ""
var exit_room_id := ""


func _ready() -> void:
	add_to_group("mini_story_manager_2_5d")
	get_tree().paused = false
	Engine.time_scale = 1.0
	dried_roots = dried_roots_bank
	_apply_startup_presentation()
	if generation_seed != 0:
		seed(generation_seed)
	else:
		randomize()
	_build_materials()
	_connect_player()
	_setup_new_main_layer()
	_build_dungeon()
	_update_key_ui()
	_update_root_fragment_ui()
	_refresh_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()


func collect_key() -> void:
	has_key = true
	_update_key_ui()
	_refresh_objective()
	if not key_shift_done:
		key_shift_done = true
		call_deferred("_delayed_key_shift")
	show_message("Bir kapı açıldı. Bir şey seni içeri saydı.", 3.2)


func has_player_key() -> bool:
	return has_key


func try_exit() -> void:
	# Son mikro katta anahtar gerekli
	var is_last_floor := current_micro_floor >= total_micro_floors
	
	if is_last_floor and not has_key:
		show_message("Anahtar olmadan Kökaltı seni bırakmaz.", 2.6)
		return
	
	if is_last_floor and _boss_required and not _boss_defeated:
		show_message("Yaşlı şey yolu tutuyor. Önce onu geç.", 2.4)
		return
	
	if is_last_floor:
		# Son mikro kat geçildi — ana katmanı bitir
		_finish_main_layer()
	else:
		# Mikro kata geç
		_advance_micro_floor()


func _finish_main_layer() -> void:
	print("=== ANA KATMAN ", current_main_layer, " bitti")
	
	# 4 ana katman bitti mi?
	if current_main_layer >= max_main_layers:
		run_locked = true
		if ui and ui.has_method("show_victory"):
			ui.call("show_victory", "Şimdilik kaçtın. Ama Kökler seni hatırlıyor.")
		return
	
	# Yeni ana katmana geç
	current_main_layer += 1
	show_message("Ana Katman %d" % current_main_layer, 2.0)
	_setup_new_main_layer()
	
	run_locked = false
	has_key = false
	_update_key_ui()
	
	_clear_dungeon()
	_build_dungeon()


func show_message(text: String, duration := 3.0) -> void:
	if ui and ui.has_method("show_message"):
		ui.call("show_message", text, duration)


func show_lore_message(text: String, duration := 3.0) -> void:
	if shown_lore_messages.has(text):
		return
	shown_lore_messages[text] = true
	show_message(text, duration)


func collect_root_fragment(amount: int = 1) -> void:
	add_root_fragments(amount)


func get_root_fragments() -> int:
	return root_fragments


func add_root_fragments(amount: int = 1, show_feedback: bool = true) -> int:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return root_fragments
	root_fragments += safe_amount
	_update_root_fragment_ui()
	if show_feedback:
		show_message("Kök Parçası +%d" % safe_amount, 1.5)
	return root_fragments


func spend_root_fragments(amount: int) -> bool:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return true
	if root_fragments < safe_amount:
		return false
	root_fragments -= safe_amount
	_update_root_fragment_ui()
	return true


func get_dried_roots() -> int:
	return dried_roots


func convert_root_fragments_on_death() -> int:
	var converted: int = int(floor(float(root_fragments) * 0.5))
	if converted <= 0:
		return 0
	dried_roots += converted
	dried_roots_bank = dried_roots
	root_fragments = 0
	_update_root_fragment_ui()
	return converted


func use_root_shrine_option(option_id: String) -> bool:
	match option_id:
		"heal":
			return _use_root_shrine_heal()
		"reveal":
			return _use_root_shrine_reveal()
		"empower":
			return _use_root_shrine_empower()
		_:
			show_message("Kök Sunağı sessiz kaldı.", 1.6)
			return false


func get_root_shrine_option_label(option_id: String) -> String:
	match option_id:
		"heal":
			return "Şifa (3 Kök Parçası)"
		"reveal":
			return "Yolları Fısılda (4 Kök Parçası)"
		"empower":
			return "Silahı Güçlendir (5 Kök Parçası)"
		_:
			return "Sessiz Kök"


func _use_root_shrine_heal() -> bool:
	if player == null or not is_instance_valid(player) or not player.has_method("heal"):
		show_message("Kökler yaranı bulamadı.", 1.8)
		return false
	if int(player.get("current_hp")) >= int(player.get("max_hp")):
		show_message("Asha'nın yarası yok.", 1.6)
		return false
	if not spend_root_fragments(3):
		show_message("Yeterli Kök Parçası yok. Gerekli: 3", 1.8)
		return false
	var healed: int = int(player.call("heal", 25))
	if healed <= 0:
		add_root_fragments(3, false)
		show_message("Kökler yaranı bulamadı.", 1.8)
		return false
	show_message("Kökler yaranı sardı. (-3 Kök Parçası)", 2.0)
	return true


func _use_root_shrine_reveal() -> bool:
	if not ui or not ui.has_method("reveal_minimap_rooms"):
		show_message("Harita henüz bu fısıltıyı taşıyamıyor.", 2.0)
		return false
	var reveal_ids := _nearby_room_ids_for_reveal()
	if reveal_ids.is_empty():
		show_message("Harita henüz bu fısıltıyı taşıyamıyor.", 2.0)
		return false
	if not spend_root_fragments(4):
		show_message("Yeterli Kök Parçası yok. Gerekli: 4", 1.8)
		return false
	ui.call("reveal_minimap_rooms", reveal_ids)
	show_message("Kökler çevredeki yolları fısıldadı. (-4 Kök Parçası)", 2.1)
	return true


func _use_root_shrine_empower() -> bool:
	if player == null or not is_instance_valid(player) or not player.has_method("add_run_damage_bonus"):
		show_message("Silah bu kökü kabul etmedi.", 1.8)
		return false
	if not spend_root_fragments(5):
		show_message("Yeterli Kök Parçası yok. Gerekli: 5", 1.8)
		return false
	player.call("add_run_damage_bonus", 1)
	show_message("Kökler silahına işledi. (-5 Kök Parçası)", 2.0)
	return true


func _nearby_room_ids_for_reveal() -> Array[String]:
	var reveal_ids: Array[String] = []
	var anchor_room_id := current_room_id
	if anchor_room_id.is_empty() and player:
		anchor_room_id = _room_id_at_position(player.global_position)
	if anchor_room_id.is_empty():
		return reveal_ids
	for neighbor_id in _neighbor_room_ids_for(anchor_room_id):
		if not reveal_ids.has(neighbor_id):
			reveal_ids.append(neighbor_id)
		for second_id in _neighbor_room_ids_for(neighbor_id):
			if second_id != anchor_room_id and not reveal_ids.has(second_id):
				reveal_ids.append(second_id)
	return reveal_ids


const WEAPON_SWAP_POPUP_SCRIPT := preload("res://scripts/weapon_swap_popup.gd")

var _active_swap_popup: CanvasLayer
var _pending_swap_pickup: Node3D

func collect_weapon(weapon_id: String) -> void:
	if not player or not player.has_method("add_weapon_to_inventory"):
		return
	var weapon_name := weapon_id
	if player.has_method("get_weapon_display_name"):
		weapon_name = player.call("get_weapon_display_name", weapon_id)
	
	var manager := _get_player_weapon_manager()
	var inventory_full := false
	var already_owned := false
	if manager:
		inventory_full = manager.is_inventory_full()
		already_owned = manager.owned_weapons.has(weapon_id)
	
	# Popup zaten açıksa hiçbir şey yapma
	if _active_swap_popup and is_instance_valid(_active_swap_popup):
		return
	
	# Zaten sahip olunan silah
	if already_owned:
		add_root_fragments(1, false)
		show_message("Zaten vardı. Kök Parçası +1", 1.8)
		return
	
	# Envanter dolu — popup aç
	if inventory_full:
		_open_weapon_swap_popup(weapon_id, weapon_name)
		return
	
	# Normal ekleme
	var added: bool = player.call("add_weapon_to_inventory", weapon_id)
	if added:
		show_message("Silah bulundu: " + weapon_name, 2.2)


func _open_weapon_swap_popup(new_weapon_id: String, new_weapon_name: String) -> void:
	var manager := _get_player_weapon_manager()
	if not manager:
		return
	
	# Slot 1 ve 2'deki silahların adlarını al
	var slot1: WeaponData = manager.get_weapon_at_slot(1)
	var slot2: WeaponData = manager.get_weapon_at_slot(2)
	if not slot1 or not slot2:
		# İki silah olmadan popup gereksiz
		return
	
	# Popup oluştur
	var popup := WEAPON_SWAP_POPUP_SCRIPT.new() as CanvasLayer
	if popup == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(popup)
	else:
		add_child(popup)
	if not popup.has_method("setup") or not popup.has_signal("slot_chosen") or not popup.has_signal("cancelled"):
		popup.queue_free()
		return
	popup.call("setup", new_weapon_id, new_weapon_name, slot1.display_name, slot2.display_name)
	popup.connect("slot_chosen", Callable(self, "_on_weapon_swap_chosen").bind(new_weapon_id))
	popup.connect("cancelled", Callable(self, "_on_weapon_swap_cancelled"))
	_active_swap_popup = popup
	get_tree().paused = true
	
	# Oyunu duraklatma — popup üstünde olsa bile oyun devam etsin (sade tercih)
	# Eğer pause istersen: get_tree().paused = true


func _on_weapon_swap_chosen(slot: int, new_weapon_id: String) -> void:
	_active_swap_popup = null
	get_tree().paused = false
	var manager := _get_player_weapon_manager()
	if not manager:
		return
	
	# O slottaki silahı bırak
	var dropped_id: String = manager.drop_weapon_at_slot(slot)
	
	# Bırakılan silahı oyuncunun ayakucuna pickup olarak düşür
	if not dropped_id.is_empty():
		var drop_position := player.global_position + Vector3(0.0, 0.0, 0.8)
		_spawn_weapon_pickup(drop_position, dropped_id)
	
	# Yeni silahı oyuncunun seçtiği slot'a ekle
	manager.add_weapon_at_slot(new_weapon_id, slot)
	
	var dropped_name := dropped_id
	if player.has_method("get_weapon_display_name") and not dropped_id.is_empty():
		dropped_name = player.call("get_weapon_display_name", dropped_id)
	
	var new_name := new_weapon_id
	if player.has_method("get_weapon_display_name"):
		new_name = player.call("get_weapon_display_name", new_weapon_id)
	
	show_message(dropped_name + " bırakıldı, " + new_name + " alındı.", 2.5)
	
	# Yerdeki orijinal pickup'ı sil
	if _pending_swap_pickup and is_instance_valid(_pending_swap_pickup):
		_pending_swap_pickup.queue_free()
	_pending_swap_pickup = null
	
func _on_weapon_swap_cancelled() -> void:
	_active_swap_popup = null
	get_tree().paused = false
	_pending_swap_pickup = null
	show_message("İptal edildi.", 1.5)


func _get_player_weapon_manager() -> WeaponManager25D:
	if player == null or not is_instance_valid(player):
		return null
	return player.get("weapon_manager") as WeaponManager25D


func enemy_died(enemy_type: String, drop_position: Vector3, enemy: Node = null) -> void:
	var root_chance := 0.45
	var weapon_chance := 0.08
	match enemy_type:
		"mushroom_man":
			root_chance = 0.60
			weapon_chance = 0.18
		"stone_guard":
			root_chance = 0.80
			weapon_chance = 0.25

	if randf() <= root_chance:
		_spawn_root_fragment(drop_position + Vector3(0.25, 0.0, 0.0))
	if randf() <= weapon_chance:
		_spawn_weapon_pickup(drop_position + Vector3(-0.25, 0.0, 0.0), _get_random_weapon_id())

	var room_id := ""
	if enemy and is_instance_valid(enemy) and enemy.has_meta("room_id"):
		room_id = String(enemy.get_meta("room_id"))
	if room_id.is_empty():
		room_id = _room_id_at_position(drop_position)
	if not room_id.is_empty() and room_enemy_counts.has(room_id):
		var was_combat_room := _room_should_lock_on_entry(room_id)
		var remaining: int = maxi(int(room_enemy_counts[room_id]) - 1, 0)
		room_enemy_counts[room_id] = remaining
		if remaining == 0:
			if _room_state(room_id) == ROOM_STATE_ACTIVE_COMBAT or was_combat_room:
				_clear_room(room_id)
			elif discovered_rooms.has(room_id):
				_set_room_state(room_id, ROOM_STATE_CLEARED)
				_refresh_objective()


func player_died() -> void:
	if run_locked:
		return
	run_locked = true
	var death_lines := [
		"Kökler unutmaz. Adını da, düşüşünü de saklarlar.",
		"Kökaltı bir nefes daha içti. Asha'nın nefesini.",
		"Yukarıda kimse senin indiğini bilmiyordu. Şimdi kimse çıkmadığını da bilmeyecek.",
		"Toprak sabırlıdır; bekler, sarar, ve sahiplenir.",
		"Asha düştü. Kökler kıpırdandı, sanki tanıdık bir şeye dokunmuş gibi.",
		"Her ölüm bir tohumdur, demişti yaşlılar. Kökaltı bu tohumları toplar.",
		"Karanlık seni tanıdı. Bir dahaki sefere daha hızlı tanıyacak.",
		"Burada zaman yoktur, yalnızca derinlik. Ve sen yeterince derine indin.",
		"Kökler arasında bir ışık daha söndü. Kökaltı hiç bu kadar aydınlık olmamıştı.",
		"Annen seni buraya göndermedi. Kökaltı seni çağırdı. Ve çağırmaya devam edecek.",
	]
	var lore: String = death_lines[randi() % death_lines.size()]
	_show_death_screen(lore)


func _show_death_screen(lore: String) -> void:
	var screen: CanvasLayer = DEATH_SCREEN_SCRIPT.new()
	if screen.has_method("setup"):
		screen.call("setup", lore)
	screen.restart_requested.connect(_on_death_restart)
	get_tree().current_scene.add_child(screen)
	_active_death_screen = screen
	get_tree().paused = true


func _on_death_restart() -> void:
	print("[DEATH] Yeniden basla tetiklendi")
	if _active_death_screen and is_instance_valid(_active_death_screen):
		_active_death_screen.queue_free()
		_active_death_screen = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	_rebuild_scene.call_deferred()


func _rebuild_scene() -> void:
	print("[DEATH] sahne elle yeniden kuruluyor")
	var tree := get_tree()
	var scene_res: PackedScene = load("res://scenes/main_2_5d.tscn")
	if scene_res == null:
		print("[DEATH] HATA: main_2_5d.tscn yuklenemedi")
		return
	var root := tree.root
	var old_scene := tree.current_scene
	# Eski sahneyi önce ağaçtan çıkar ki yeni oyuncu eski (kilitli) manager'a bağlanmasın
	if old_scene and is_instance_valid(old_scene):
		tree.current_scene = null
		root.remove_child(old_scene)
		old_scene.queue_free()
	var new_scene := scene_res.instantiate()
	root.add_child(new_scene)
	tree.current_scene = new_scene
	print("[DEATH] yeni sahne eklendi")


func _do_restart() -> void:
	print("[DEATH] change_scene cagriliyor")
	var err := get_tree().change_scene_to_file("res://scenes/main_2_5d.tscn")
	print("[DEATH] change_scene sonuc kodu: ", err)


func _reload_run_after_death() -> void:
	await get_tree().create_timer(restart_delay, true, false, true).timeout
	if not is_inside_tree():
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	if not ResourceLoader.exists(MAIN_SCENE_PATH):
		push_error("Death reload target missing: " + MAIN_SCENE_PATH)
		return
	get_tree().call_deferred("change_scene_to_file", MAIN_SCENE_PATH)


func is_run_locked() -> bool:
	return run_locked


func _delayed_key_shift() -> void:
	await get_tree().create_timer(2.4).timeout
	if has_key and not run_locked:
		_trigger_labyrinth_shift(key_room_id, true, "Kökaltı yer değiştirdi.")


func _apply_startup_presentation() -> void:
	if start_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _connect_player() -> void:
	player = get_node_or_null(player_path) as Node3D
	ui = get_node_or_null("UI")
	if not player:
		player = get_tree().get_first_node_in_group("player_2_5d") as Node3D
	if not ui:
		ui = get_tree().get_first_node_in_group("ui_2_5d")

	if player:
		if player.has_signal("health_changed"):
			player.connect("health_changed", Callable(self, "_on_player_health_changed"))
		if player.has_signal("dash_cooldown_changed"):
			player.connect("dash_cooldown_changed", Callable(self, "_on_dash_cooldown_changed"))
		if player.has_signal("weapon_changed"):
			player.connect("weapon_changed", Callable(self, "_on_weapon_changed"))


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if ui and ui.has_method("set_hp"):
		ui.call("set_hp", current_hp, max_hp)


func _on_dash_cooldown_changed(is_ready: bool, remaining: float) -> void:
	if ui and ui.has_method("set_dash_ready"):
		ui.call("set_dash_ready", is_ready, remaining)


func _on_weapon_changed(display_name: String, slots_text: String) -> void:
	if ui and ui.has_method("set_weapon"):
		ui.call("set_weapon", display_name, slots_text)


func _update_key_ui() -> void:
	if ui and ui.has_method("set_key_status"):
		ui.call("set_key_status", has_key)


func _update_root_fragment_ui() -> void:
	if ui and ui.has_method("set_root_fragments"):
		ui.call("set_root_fragments", root_fragments)


func _set_objective(text: String) -> void:
	if ui and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text)


func _refresh_objective() -> void:
	if run_locked:
		return
	if not current_room_id.is_empty() and _room_state(current_room_id) == ROOM_STATE_ACTIVE_COMBAT:
		_set_objective("Odayı temizle")
	elif has_key:
		_set_objective("Çıkışa ulaş")
	else:
		_set_objective("Anahtarı bul")


func _room_state(room_id: String) -> String:
	return String(room_states.get(room_id, ROOM_STATE_UNKNOWN))


func get_entropy() -> float:
	return entropy_value


func add_entropy(amount: float, show_feedback: bool = true) -> float:
	if amount <= 0.0:
		return entropy_value
	entropy_value = clampf(entropy_value + amount, 0.0, 8.0)
	if show_feedback:
		_maybe_show_entropy_message()
	return entropy_value


func reduce_entropy(amount: float) -> float:
	if amount <= 0.0:
		return entropy_value
	entropy_value = maxf(entropy_value - amount, 0.0)
	return entropy_value


func play_entropy_pulse(position: Vector3 = Vector3.ZERO) -> void:
	var pulse_position: Vector3 = position
	if pulse_position == Vector3.ZERO and player:
		pulse_position = player.global_position + Vector3(0.0, 1.6, 0.0)
	if pulse_position == Vector3.ZERO or dungeon_root == null:
		return
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "EntropyPulseLight"
	light.light_color = Color(0.9, 0.38, 0.12, 1.0)
	light.light_energy = 0.35 + minf(entropy_value * 0.08, 0.45)
	light.omni_range = 4.5 + minf(entropy_value * 0.4, 2.5)
	dungeon_root.add_child(light)
	light.global_position = pulse_position
	var tween: Tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.42)
	tween.tween_callback(func() -> void:
		if is_instance_valid(light):
			light.queue_free()
	)


func _maybe_show_entropy_message() -> void:
	var now := Time.get_ticks_msec()
	if now - entropy_message_time_msec < 4500:
		return
	entropy_message_time_msec = now
	var line: String = "Kökler gerildi." if randf() < 0.5 else "Kökaltı seni duydu."
	show_message(line, 1.35)


func _set_room_state(room_id: String, state: String) -> void:
	if room_id.is_empty() or not rooms.has(room_id):
		return
	room_states[room_id] = state
	var room: Dictionary = rooms[room_id] as Dictionary
	room["state"] = state
	room["cleared"] = state == ROOM_STATE_CLEARED
	rooms[room_id] = room
	if ui and ui.has_method("set_minimap_room_state"):
		ui.call("set_minimap_room_state", room_id, state)


func _setup_minimap() -> void:
	if ui and ui.has_method("setup_minimap"):
		ui.call("setup_minimap", _build_minimap_data())


func _discover_room(room_id: String) -> void:
	if room_id.is_empty() or not rooms.has(room_id):
		return
	current_room_id = room_id
	discovered_rooms[room_id] = true
	var state := _room_state(room_id)
	if state == ROOM_STATE_UNKNOWN or state == ROOM_STATE_SHIFTED:
		_set_room_state(room_id, ROOM_STATE_DISCOVERED)
	if ui and ui.has_method("visit_minimap_room"):
		ui.call("visit_minimap_room", room_id)
	if ui and ui.has_method("set_minimap_room_state"):
		ui.call("set_minimap_room_state", room_id, _room_state(room_id))


func _on_room_entered(room_id: String) -> void:
	if run_locked or room_id.is_empty() or not rooms.has(room_id):
		return
	_discover_room(room_id)
	if _room_should_lock_on_entry(room_id):
		if _room_state(room_id) != ROOM_STATE_CLEARED and _room_state(room_id) != ROOM_STATE_ACTIVE_COMBAT:
			_start_room_combat(room_id)
	else:
		if int(room_enemy_counts.get(room_id, 0)) <= 0 and _room_state(room_id) != ROOM_STATE_CLEARED:
			_set_room_state(room_id, ROOM_STATE_DISCOVERED)
		_refresh_objective()


func _room_should_lock_on_entry(room_id: String) -> bool:
	if not rooms.has(room_id):
		return false
	if int(room_enemy_counts.get(room_id, 0)) <= 0:
		return false
	var room: Dictionary = rooms[room_id] as Dictionary
	var room_type: String = String(room.get("type", ""))
	if room_type in ["wake", "fathers_map_room", "loot_niche", "key_alcove", "forgotten_exit", "sealed_white_door", "shifting_root_gate"]:
		return false
	return true


func _start_room_combat(room_id: String) -> void:
	_set_room_state(room_id, ROOM_STATE_ACTIVE_COMBAT)
	var close_gates := _should_close_gates_for_room(room_id)
	_set_room_gates_closed_flag(room_id, close_gates)
	if close_gates:
		add_entropy(1.0)
		_set_room_gates_open(room_id, false)
		show_message("Kökler kapandı.", 1.25)
	else:
		_set_room_gates_open(room_id, true, true)
	_set_objective("Odayı temizle")


func _clear_room(room_id: String) -> void:
	if room_id.is_empty() or not rooms.has(room_id):
		return
	if _room_state(room_id) == ROOM_STATE_CLEARED:
		return
	_set_room_state(room_id, ROOM_STATE_CLEARED)
	reduce_entropy(1.0)
	if _room_gates_are_closed(room_id):
		_set_room_gates_open(room_id, true)
		_set_room_gates_closed_flag(room_id, false)
	show_message("Oda sustu.", 1.4)
	_spawn_room_clear_reward(room_id)
	_refresh_objective()


func _set_room_gates_open(room_id: String, open: bool, instant := false) -> void:
	if not room_combat_gates.has(room_id):
		return
	if not open and rooms.has(room_id):
		var room: Dictionary = rooms[room_id] as Dictionary
		play_entropy_pulse(_room_point(room, 0.0, 0.0, 1.6))
	var gates: Array = room_combat_gates[room_id] as Array
	for gate_variant in gates:
		var gate := gate_variant as Node3D
		if gate and is_instance_valid(gate):
			_set_shift_gate_open(gate, open, instant)


func _setup_room_states_and_combat_gates() -> void:
	room_combat_gates.clear()
	for room_id in room_order:
		_set_room_state(room_id, ROOM_STATE_UNKNOWN)
		_set_room_gates_closed_flag(room_id, false)
		if _room_should_lock_on_entry(room_id):
			_create_combat_gates_for_room(room_id)


func _should_close_gates_for_room(room_id: String) -> bool:
	if not room_combat_gates.has(room_id):
		return false
	if _room_forces_gate_close(room_id):
		return true
	return randf() < NORMAL_ROOM_GATE_CLOSE_CHANCE


func _room_forces_gate_close(room_id: String) -> bool:
	if not rooms.has(room_id):
		return false
	var room: Dictionary = rooms[room_id] as Dictionary
	var room_type: String = String(room.get("type", ""))
	var forced_gate_value: Variant = room.get("force_gate_close", false)
	return room_type == "boss" or bool(forced_gate_value)


func _set_room_gates_closed_flag(room_id: String, closed: bool) -> void:
	if not rooms.has(room_id):
		return
	var room: Dictionary = rooms[room_id] as Dictionary
	room["gates_closed"] = closed
	rooms[room_id] = room


func _room_gates_are_closed(room_id: String) -> bool:
	if not rooms.has(room_id):
		return false
	var room: Dictionary = rooms[room_id] as Dictionary
	var closed_value: Variant = room.get("gates_closed", false)
	return bool(closed_value)


func _create_combat_gates_for_room(room_id: String) -> void:
	var gates: Array[Node3D] = []
	for neighbor_id in _neighbor_room_ids_for(room_id):
		var gate_position := _connection_midpoint(room_id, neighbor_id)
		var gate_size := _connection_gate_size(room_id, neighbor_id)
		var gate_name := "%s_combat_gate_%s" % [room_id, neighbor_id]
		var gate := _add_shift_gate(gate_name, gate_position, gate_size, true)
		gates.append(gate)
	room_combat_gates[room_id] = gates


func _spawn_room_clear_reward(room_id: String) -> void:
	if room_clear_rewards_spawned.has(room_id) or not rooms.has(room_id):
		return
	room_clear_rewards_spawned[room_id] = true
	var room: Dictionary = rooms[room_id] as Dictionary
	var room_type: String = String(room.get("type", "root_tunnel"))
	var chances: Dictionary = _room_clear_reward_chances(room_type)
	var shrine_chance: float = float(chances.get("shrine", 0.08))
	var weapon_chance: float = float(chances.get("weapon", 0.10))
	var root_chance: float = float(chances.get("root", 0.45))
	var roll := randf()
	var spawn_position := _safe_room_spawn_position(room, _room_point(room, 0.0, 0.0, 0.45), 0.8)
	if roll < shrine_chance:
		_spawn_root_shrine(spawn_position)
	elif roll < shrine_chance + weapon_chance:
		_spawn_weapon_pickup(spawn_position, _get_random_weapon_id())
	elif roll < shrine_chance + weapon_chance + root_chance:
		_spawn_root_fragment(spawn_position)


func _room_clear_reward_chances(room_type: String) -> Dictionary:
	match room_type:
		"rat_nest":
			return {"root": 0.60, "weapon": 0.08, "shrine": 0.10}
		"mushroom_cellar":
			return {"root": 0.50, "weapon": 0.12, "shrine": 0.15}
		"stone_watch_room":
			return {"root": 0.50, "weapon": 0.18, "shrine": 0.15}
		_:
			return {"root": 0.45, "weapon": 0.10, "shrine": 0.15}


func _mark_minimap_uncertain(room_ids: Array) -> void:
	if ui and ui.has_method("mark_minimap_uncertain"):
		ui.call("mark_minimap_uncertain", room_ids)


func _build_minimap_data() -> Dictionary:
	var map_rooms: Dictionary = {}
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		var cell: Vector2i = room["cell"]
		map_rooms[room_id] = {
			"cell": cell,
			"type": String(room["type"]),
			"neighbors": _neighbor_room_ids_for(room_id),
			"is_start": room_id == start_room_id,
			"is_key": room_id == key_room_id,
			"is_exit": room_id == exit_room_id,
			"state": _room_state(room_id),
		}
	return {
		"rooms": map_rooms,
		"connections": _connection_pairs(),
		"start_room_id": start_room_id,
		"key_room_id": key_room_id,
		"exit_room_id": exit_room_id,
	}


func _neighbor_room_ids_for(room_id: String) -> Array[String]:
	var result: Array[String] = []
	if not rooms.has(room_id):
		return result
	var room: Dictionary = rooms[room_id] as Dictionary
	var cell: Vector2i = room["cell"]
	if not graph.has(cell):
		return result
	var neighbors: Array = graph[cell] as Array
	for neighbor_variant in neighbors:
		var neighbor: Vector2i = neighbor_variant
		if cell_to_room_id.has(neighbor):
			result.append(String(cell_to_room_id[neighbor]))
	return result


func _connection_pairs() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for cell in graph.keys():
		if not cell_to_room_id.has(cell):
			continue
		var room_id: String = String(cell_to_room_id[cell])
		var neighbors: Array = graph[cell] as Array
		for neighbor_variant in neighbors:
			var neighbor: Vector2i = neighbor_variant
			if not cell_to_room_id.has(neighbor):
				continue
			var other_id: String = String(cell_to_room_id[neighbor])
			var pair_key := _room_pair_key(room_id, other_id)
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			result.append([room_id, other_id])
	return result


func _build_dungeon() -> void:
	# Mikro kat seed'ini uygula
	if micro_floor_seeds.has(current_micro_floor):
		seed(micro_floor_seeds[current_micro_floor])
	
	dungeon_root = Node3D.new()
	dungeon_root.name = "KokTuneliDungeon"
	add_child(dungeon_root)

	_generate_room_graph()
	if room_order.is_empty() or not rooms.has(start_room_id) or not rooms.has(key_room_id) or not rooms.has(exit_room_id):
		push_error("Dungeon generation failed to produce reachable start/key/exit rooms.")
		return

	for room_id in room_order:
		_add_room(room_id)
		if debug_room_labels:
			_add_debug_room_label(room_id)

	_add_corridors()
	_add_room_details()
	_add_room_entry_triggers()
	_spawn_room_contents()
	_spawn_guaranteed_root_shrine()
	_setup_room_states_and_combat_gates()

	var key_room: Dictionary = rooms[key_room_id] as Dictionary
	var exit_room: Dictionary = rooms[exit_room_id] as Dictionary
	# Anahtar sadece key_floor numaralı mikro katta spawn olsun
	if current_micro_floor == key_floor:
		_add_key_pickup(_room_point(key_room, 0.0, 0.15, 0.45))
	var is_final_floor := current_micro_floor >= total_micro_floors
	_add_exit_gate(_room_point(exit_room, 0.22, 0.0, 0.7), is_final_floor)
	# İlk kat değilsek, start odasına bir üst kata çıkış merdiveni koy
	if current_micro_floor > 1:
		var start_room_for_stair: Dictionary = rooms[start_room_id] as Dictionary
		# Merdiveni kapının (komşu yönünün) tam tersine koy
		var stair_dir := _opposite_door_ratio(start_room_id)
		var stair_yaw := atan2(stair_dir.x, stair_dir.y)
		
		_add_back_stair(_room_point(start_room_for_stair, stair_dir.x, stair_dir.y, 0.7), stair_yaw)
	if player:
		if _spawn_at_exit_room:
			# Geri çıkış: bir alt kattan çıktık, exit odasında belir
			player.global_position = _room_point(exit_room, 0.22, 0.0, 0.0)
			_spawn_at_exit_room = false
		else:
			var start_room: Dictionary = rooms[start_room_id] as Dictionary
			player.global_position = _room_point(start_room, 0.0, 0.0, 0.0)

# Son mikro kat: exit odasında boss; yenilene kadar çıkış kilitli
		_boss_required = current_micro_floor >= total_micro_floors
		_boss_defeated = false
		if _boss_required:
			_spawn_boss(exit_room)

	_setup_minimap()
	var initial_room_id := start_room_id
	if player:
		var spawn_room_id := _room_id_at_position(player.global_position)
		if not spawn_room_id.is_empty():
			initial_room_id = spawn_room_id
	_on_room_entered(initial_room_id)

	if debug_print_generation:
		print("KÖKLER v0.4 room graph: ", room_order.size(), " rooms | start=", start_room_id, " key=", key_room_id, " exit=", exit_room_id)

	show_lore_message("KAT %d-%d" % [current_main_layer, current_micro_floor], 2.5)


func _generate_room_graph() -> void:
	for attempt in range(40):
		if _try_generate_room_graph():
			return
	push_warning("Dungeon generation used fallback graph.")
	_build_fallback_graph()


func _try_generate_room_graph() -> bool:
	rooms.clear()
	room_order.clear()
	cell_to_room_id.clear()
	graph.clear()
	corridor_variants.clear()
	room_enemy_counts.clear()
	room_states.clear()
	room_combat_gates.clear()
	room_clear_rewards_spawned.clear()
	blocking_prop_positions.clear()
	discovered_rooms.clear()
	current_room_id = ""
	puzzle_shift_done = false

	var used: Dictionary = {}
	var room_cells: Array[Vector2i] = []
	start_cell = Vector2i(4 + randi_range(-1, 1), 7 + randi_range(-1, 0))
	_add_graph_cell(start_cell, used, room_cells)

	var current := start_cell
	var main_path: Array[Vector2i] = [start_cell]
	var main_length := randi_range(7, 9)
	for i in range(main_length - 1):
		var candidates: Array[Vector2i] = _unused_neighbors(current, used)
		if candidates.is_empty():
			return false
		var next_cell := _choose_walk_neighbor(candidates, current, start_cell)
		_add_graph_cell(next_cell, used, room_cells)
		_connect_cells(current, next_cell)
		main_path.append(next_cell)
		current = next_cell

	var target_room_count := randi_range(MIN_ROOMS, MAX_ROOMS)
	var branch_sources: Array[Vector2i] = main_path.duplicate()
	branch_sources.shuffle()
	for source_cell in branch_sources:
		if room_cells.size() >= target_room_count:
			break
		if source_cell == start_cell:
			continue
		_try_add_branch(source_cell, used, room_cells, randi_range(1, 2), target_room_count)

	var guard := 0
	while room_cells.size() < MIN_ROOMS and guard < 30:
		guard += 1
		var source: Vector2i = room_cells.pick_random()
		_try_add_branch(source, used, room_cells, 1, target_room_count)

	if randf() < 0.75:
		_try_add_loop_connection(room_cells)

	if room_cells.size() < MIN_ROOMS or room_cells.size() > MAX_ROOMS:
		return false

	exit_cell = _farthest_cell_from(start_cell)
	var distances_from_start: Dictionary = _distances_from(start_cell)
	var distances_from_exit: Dictionary = _distances_from(exit_cell)
	var exit_distance: int = int(distances_from_start.get(exit_cell, 0))
	if exit_distance < 6:
		return false
	key_cell = _choose_key_cell(room_cells, distances_from_start, distances_from_exit, exit_distance)
	if key_cell == Vector2i.ZERO or key_cell == start_cell or key_cell == exit_cell:
		return false
	if int(distances_from_start.get(key_cell, 0)) < 3 or int(distances_from_exit.get(key_cell, 0)) < 2:
		return false

	_assign_rooms(room_cells, distances_from_start)
	return true


func _build_fallback_graph() -> void:
	rooms.clear()
	room_order.clear()
	cell_to_room_id.clear()
	graph.clear()
	corridor_variants.clear()
	room_enemy_counts.clear()
	room_states.clear()
	room_combat_gates.clear()
	room_clear_rewards_spawned.clear()
	blocking_prop_positions.clear()
	discovered_rooms.clear()
	current_room_id = ""
	var used: Dictionary = {}
	var room_cells: Array[Vector2i] = []
	start_cell = Vector2i(4, 7)
	var path: Array[Vector2i] = [
		start_cell,
		Vector2i(4, 6),
		Vector2i(5, 6),
		Vector2i(5, 5),
		Vector2i(6, 5),
		Vector2i(6, 4),
		Vector2i(7, 4),
		Vector2i(7, 3),
	]
	for i in range(path.size()):
		_add_graph_cell(path[i], used, room_cells)
		if i > 0:
			_connect_cells(path[i - 1], path[i])
	var branches: Array[Vector2i] = [Vector2i(3, 6), Vector2i(5, 7), Vector2i(6, 6), Vector2i(8, 4)]
	for branch_cell in branches:
		_add_graph_cell(branch_cell, used, room_cells)
		var nearest := _nearest_existing_neighbor(branch_cell, used)
		_connect_cells(branch_cell, nearest)
	_try_add_loop_connection(room_cells)
	exit_cell = path[path.size() - 1]
	key_cell = Vector2i(6, 6)
	var distances: Dictionary = _distances_from(start_cell)
	_assign_rooms(room_cells, distances)


func _add_graph_cell(cell: Vector2i, used: Dictionary, room_cells: Array[Vector2i]) -> void:
	used[cell] = true
	if not graph.has(cell):
		graph[cell] = []
	if not room_cells.has(cell):
		room_cells.append(cell)


func _connect_cells(a: Vector2i, b: Vector2i) -> void:
	if not graph.has(a):
		graph[a] = []
	if not graph.has(b):
		graph[b] = []
	var a_neighbors: Array = graph[a] as Array
	var b_neighbors: Array = graph[b] as Array
	if not a_neighbors.has(b):
		a_neighbors.append(b)
	if not b_neighbors.has(a):
		b_neighbors.append(a)
	graph[a] = a_neighbors
	graph[b] = b_neighbors


func _unused_neighbors(cell: Vector2i, used: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction in directions:
		var next_cell := cell + direction
		if _cell_in_bounds(next_cell) and not used.has(next_cell):
			result.append(next_cell)
	return result


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x < GRID_SIZE - 1 and cell.y >= 1 and cell.y < GRID_SIZE - 1


func _choose_walk_neighbor(candidates: Array[Vector2i], current: Vector2i, origin: Vector2i) -> Vector2i:
	var weights: Array[float] = []
	var total_weight := 0.0
	for cell in candidates:
		var weight := 1.0 + float(_manhattan(cell, origin)) * 0.65
		if cell.y < current.y:
			weight += 1.25
		if abs(cell.x - origin.x) > 1:
			weight += 0.35
		weights.append(weight)
		total_weight += weight
	var roll := randf() * total_weight
	var cursor := 0.0
	for i in range(candidates.size()):
		cursor += weights[i]
		if roll <= cursor:
			return candidates[i]
	return candidates[candidates.size() - 1]


func _try_add_branch(source: Vector2i, used: Dictionary, room_cells: Array[Vector2i], branch_length: int, target_count: int) -> bool:
	var current := source
	var added := false
	for i in range(branch_length):
		if room_cells.size() >= target_count:
			break
		var candidates: Array[Vector2i] = _unused_neighbors(current, used)
		if candidates.is_empty():
			break
		candidates.shuffle()
		var next_cell: Vector2i = candidates[0]
		_add_graph_cell(next_cell, used, room_cells)
		_connect_cells(current, next_cell)
		current = next_cell
		added = true
	return added


func _try_add_loop_connection(room_cells: Array[Vector2i]) -> bool:
	var candidates: Array = []
	var room_lookup: Dictionary = {}
	for cell in room_cells:
		room_lookup[cell] = true
	for cell in room_cells:
		var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for direction in directions:
			var neighbor := cell + direction
			if not room_lookup.has(neighbor):
				continue
			var neighbors: Array = graph[cell] as Array
			if neighbors.has(neighbor):
				continue
			if cell == start_cell or neighbor == start_cell:
				continue
			candidates.append([cell, neighbor])
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var pair: Array = candidates[0]
	var a_cell: Vector2i = pair[0]
	var b_cell: Vector2i = pair[1]
	_connect_cells(a_cell, b_cell)
	return true


func _nearest_existing_neighbor(cell: Vector2i, used: Dictionary) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction in directions:
		var neighbor := cell + direction
		if used.has(neighbor):
			return neighbor
	return start_cell


func _farthest_cell_from(origin: Vector2i) -> Vector2i:
	var distances: Dictionary = _distances_from(origin)
	var best := origin
	var best_distance := -1
	for cell in distances.keys():
		var distance: int = int(distances[cell])
		if distance > best_distance:
			best_distance = distance
			best = cell
	return best


func _choose_key_cell(room_cells: Array[Vector2i], distances_from_start: Dictionary, distances_from_exit: Dictionary, exit_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in room_cells:
		if cell == start_cell or cell == exit_cell:
			continue
		var start_distance: int = int(distances_from_start.get(cell, 0))
		var exit_distance_to_cell: int = int(distances_from_exit.get(cell, 0))
		if start_distance >= max(3, exit_distance / 2) and exit_distance_to_cell >= 2:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	var best: Vector2i = candidates[0]
	var best_score := -9999.0
	for cell in candidates:
		var score: float = float(int(distances_from_start.get(cell, 0))) * 1.3 + float(int(distances_from_exit.get(cell, 0))) * 0.45
		if _is_leaf(cell):
			score += 1.5
		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best = cell
	return best


func _distances_from(origin: Vector2i) -> Dictionary:
	var distances: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distances[current])
		var neighbors: Array = graph[current] as Array
		for neighbor_variant in neighbors:
			var neighbor: Vector2i = neighbor_variant
			if not distances.has(neighbor):
				distances[neighbor] = current_distance + 1
				queue.append(neighbor)
	return distances


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _is_leaf(cell: Vector2i) -> bool:
	var neighbors: Array = graph[cell] as Array
	return neighbors.size() <= 1


func _assign_rooms(room_cells: Array[Vector2i], distances_from_start: Dictionary) -> void:
	room_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(distances_from_start.get(a, 0)) < int(distances_from_start.get(b, 0))
	)

	var special_types: Dictionary = {}
	special_types[start_cell] = "wake"
	special_types[key_cell] = "key_alcove"
	special_types[exit_cell] = "forgotten_exit"
	_assign_special_room(special_types, room_cells, "fathers_map_room", 1, 3)
	_assign_special_room(special_types, room_cells, "shifting_root_gate", 2, 8)
	_assign_special_room(special_types, room_cells, "broken_shrine", 3, 7)
	_assign_special_leaf_room(special_types, room_cells, "loot_niche")
	_assign_special_leaf_room(special_types, room_cells, "sealed_white_door")
	_assign_special_room(special_types, room_cells, "stone_watch_room", 4, 9)
	_assign_special_room(special_types, room_cells, "mushroom_cellar", 3, 9)
	_assign_special_room(special_types, room_cells, "rat_nest", 2, 8)

	for i in range(room_cells.size()):
		var cell: Vector2i = room_cells[i]
		var room_id := "room_%02d" % i
		if cell == start_cell:
			room_id = "wake_chamber"
		elif cell == key_cell:
			room_id = "key_alcove"
		elif cell == exit_cell:
			room_id = "forgotten_exit"

		cell_to_room_id[cell] = room_id
		room_order.append(room_id)

	for cell in room_cells:
		var room_id: String = String(cell_to_room_id[cell])
		var room_type := "root_tunnel"
		if special_types.has(cell):
			room_type = String(special_types[cell])
		else:
			room_type = _choose_filler_room_type(cell)
		var room: Dictionary = {
			"id": room_id,
			"type": room_type,
			"cell": cell,
			"center": _cell_to_world(cell),
			"size": _size_for_room_type(room_type),
			"openings": _openings_for_cell(cell),
		}
		rooms[room_id] = room
		room_enemy_counts[room_id] = 0

	start_room_id = String(cell_to_room_id[start_cell])
	key_room_id = String(cell_to_room_id[key_cell])
	exit_room_id = String(cell_to_room_id[exit_cell])


func _assign_special_room(special_types: Dictionary, room_cells: Array[Vector2i], room_type: String, min_distance: int, max_distance: int) -> void:
	var candidates: Array[Vector2i] = []
	var distances: Dictionary = _distances_from(start_cell)
	for cell in room_cells:
		if special_types.has(cell) or cell == start_cell or cell == key_cell or cell == exit_cell:
			continue
		var distance: int = int(distances.get(cell, 0))
		if distance >= min_distance and distance <= max_distance:
			candidates.append(cell)
	if candidates.is_empty():
		candidates = _available_special_cells(special_types, room_cells)
	if candidates.is_empty():
		return
	candidates.shuffle()
	special_types[candidates[0]] = room_type


func _assign_special_leaf_room(special_types: Dictionary, room_cells: Array[Vector2i], room_type: String) -> void:
	var candidates: Array[Vector2i] = []
	for cell in room_cells:
		if special_types.has(cell) or cell == start_cell or cell == key_cell or cell == exit_cell:
			continue
		if _is_leaf(cell):
			candidates.append(cell)
	if candidates.is_empty():
		_assign_special_room(special_types, room_cells, room_type, 2, 9)
		return
	candidates.shuffle()
	special_types[candidates[0]] = room_type


func _available_special_cells(special_types: Dictionary, room_cells: Array[Vector2i]) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for cell in room_cells:
		if not special_types.has(cell) and cell != start_cell and cell != key_cell and cell != exit_cell:
			candidates.append(cell)
	return candidates


func _choose_filler_room_type(cell: Vector2i) -> String:
	var roll := randf()
	if _is_leaf(cell) and roll < 0.35:
		return "loot_niche"
	if roll < 0.38:
		return "root_tunnel"
	if roll < 0.62:
		return "rat_nest"
	if roll < 0.82:
		return "mushroom_cellar"
	return "stone_watch_room"


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x - start_cell.x) * CELL_SPACING, 0.0, float(cell.y - start_cell.y) * CELL_SPACING)


func _size_for_room_type(room_type: String) -> Vector2:
	match room_type:
		"wake", "fathers_map_room", "broken_shrine", "key_alcove":
			return Vector2(randf_range(13.0, 15.5), randf_range(9.2, 11.0))
		"shifting_root_gate":
			return Vector2(randf_range(14.0, 16.0), randf_range(9.5, 11.0))
		"stone_watch_room", "forgotten_exit":
			return Vector2(randf_range(18.0, 19.6), randf_range(12.0, 13.2))
		"root_tunnel":
			return Vector2(randf_range(8.2, 10.0), randf_range(6.8, 8.2))
		"loot_niche", "sealed_white_door":
			return Vector2(randf_range(9.2, 11.5), randf_range(7.0, 9.0))
		"rat_nest", "mushroom_cellar":
			return Vector2(randf_range(13.0, 15.5), randf_range(9.5, 11.2))
		_:
			return Vector2(randf_range(12.0, 15.0), randf_range(8.5, 10.8))


func _openings_for_cell(cell: Vector2i) -> Array[String]:
	var openings: Array[String] = []
	var neighbors: Array = graph[cell] as Array
	for neighbor_variant in neighbors:
		var neighbor: Vector2i = neighbor_variant
		var delta := neighbor - cell
		if delta == Vector2i(1, 0):
			openings.append("east")
		elif delta == Vector2i(-1, 0):
			openings.append("west")
		elif delta == Vector2i(0, 1):
			openings.append("south")
		elif delta == Vector2i(0, -1):
			openings.append("north")
	return openings


func _add_room(room_id: String) -> void:
	var room: Dictionary = rooms[room_id] as Dictionary
	var center: Vector3 = room["center"]
	var size: Vector2 = room["size"]
	var room_type: String = room["type"]
	var floor_mat: Material = _floor_material_for_type(room_type)
	_add_box(dungeon_root, room_id + "_floor", Vector3(center.x, -0.08, center.z), Vector3(size.x, 0.16, size.y), floor_mat)
	_add_room_walls(room_id, center, size, room["openings"] as Array)


func _floor_material_for_type(room_type: String) -> Material:
	match room_type:
		"mushroom_cellar":
			return _mat("floor_green")
		"shifting_root_gate":
			return _mat("floor_root")
		"sealed_white_door", "forgotten_exit":
			return _mat("floor_cold")
		"rat_nest":
			return _mat("floor_root")
		_:
			return _mat("floor")


func _add_room_walls(room_id: String, center: Vector3, size: Vector2, openings: Array) -> void:
	var wall_mat: Material = _mat("wall")
	var north := Vector3(center.x, WALL_HEIGHT * 0.5, center.z - size.y * 0.5)
	var south := Vector3(center.x, WALL_HEIGHT * 0.5, center.z + size.y * 0.5)
	var west := Vector3(center.x - size.x * 0.5, WALL_HEIGHT * 0.5, center.z)
	var east := Vector3(center.x + size.x * 0.5, WALL_HEIGHT * 0.5, center.z)

	if openings.has("north"):
		_add_wall_with_opening(room_id + "_north", north, Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), "x", wall_mat)
	else:
		_add_box(dungeon_root, room_id + "_north", north, Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), wall_mat, true)
	if openings.has("south"):
		_add_wall_with_opening(room_id + "_south", south, Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), "x", wall_mat)
	else:
		_add_box(dungeon_root, room_id + "_south", south, Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), wall_mat, true)
	if openings.has("west"):
		_add_wall_with_opening(room_id + "_west", west, Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y), "z", wall_mat)
	else:
		_add_box(dungeon_root, room_id + "_west", west, Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y), wall_mat, true)
	if openings.has("east"):
		_add_wall_with_opening(room_id + "_east", east, Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y), "z", wall_mat)
	else:
		_add_box(dungeon_root, room_id + "_east", east, Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y), wall_mat, true)


func _add_wall_with_opening(base_name: String, center: Vector3, size: Vector3, axis: String, mat: Material) -> void:
	if axis == "x":
		var segment := (size.x - DOOR_GAP) * 0.5
		if segment > 0.15:
			_add_box(dungeon_root, base_name + "_a", center + Vector3(-(DOOR_GAP + segment) * 0.5, 0.0, 0.0), Vector3(segment, size.y, size.z), mat, true)
			_add_box(dungeon_root, base_name + "_b", center + Vector3((DOOR_GAP + segment) * 0.5, 0.0, 0.0), Vector3(segment, size.y, size.z), mat, true)
	else:
		var segment := (size.z - DOOR_GAP) * 0.5
		if segment > 0.15:
			_add_box(dungeon_root, base_name + "_a", center + Vector3(0.0, 0.0, -(DOOR_GAP + segment) * 0.5), Vector3(size.x, size.y, segment), mat, true)
			_add_box(dungeon_root, base_name + "_b", center + Vector3(0.0, 0.0, (DOOR_GAP + segment) * 0.5), Vector3(size.x, size.y, segment), mat, true)


func _add_corridors() -> void:
	var connected_pairs: Dictionary = {}
	for cell in graph.keys():
		var room_id: String = String(cell_to_room_id[cell])
		var neighbors: Array = graph[cell] as Array
		for neighbor_variant in neighbors:
			var neighbor: Vector2i = neighbor_variant
			var other_id: String = String(cell_to_room_id[neighbor])
			var pair_key := _cell_key(cell) + ":" + _cell_key(neighbor)
			var reverse_pair_key := _cell_key(neighbor) + ":" + _cell_key(cell)
			if connected_pairs.has(pair_key) or connected_pairs.has(reverse_pair_key):
				continue
			connected_pairs[pair_key] = true
			_connect_rooms(room_id, other_id)


func _cell_key(cell: Vector2i) -> String:
	return "%d_%d" % [cell.x, cell.y]


func _room_pair_key(a_id: String, b_id: String) -> String:
	if a_id < b_id:
		return a_id + ":" + b_id
	return b_id + ":" + a_id


func _connect_rooms(a_id: String, b_id: String) -> void:
	var a: Dictionary = rooms[a_id] as Dictionary
	var b: Dictionary = rooms[b_id] as Dictionary
	var a_center: Vector3 = a["center"]
	var b_center: Vector3 = b["center"]
	var a_size: Vector2 = a["size"]
	var b_size: Vector2 = b["size"]
	var wall_mat: Material = _mat("wall")
	var variant := _corridor_variant_for(a_id, b_id)
	var corridor_width := _corridor_width_for_variant(variant)
	var floor_mat: Material = _corridor_floor_for_variant(variant)
	var wall_h := 1.12

	if absf(a_center.z - b_center.z) < 0.1:
		var direction := signf(b_center.x - a_center.x)
		var a_edge := a_center.x + direction * a_size.x * 0.5
		var b_edge := b_center.x - direction * b_size.x * 0.5
		var length := absf(b_edge - a_edge)
		var center := Vector3((a_edge + b_edge) * 0.5, -0.075, a_center.z)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_floor", center, Vector3(length, 0.15, corridor_width), floor_mat)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_north_wall", Vector3(center.x, wall_h * 0.5, center.z - corridor_width * 0.5), Vector3(length + WALL_THICKNESS, wall_h, WALL_THICKNESS), wall_mat, true)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_south_wall", Vector3(center.x, wall_h * 0.5, center.z + corridor_width * 0.5), Vector3(length + WALL_THICKNESS, wall_h, WALL_THICKNESS), wall_mat, true)
		_add_corridor_dressing(a_id + "_to_" + b_id, center, length, corridor_width, true, variant)
	else:
		var direction := signf(b_center.z - a_center.z)
		var a_edge := a_center.z + direction * a_size.y * 0.5
		var b_edge := b_center.z - direction * b_size.y * 0.5
		var length := absf(b_edge - a_edge)
		var center := Vector3(a_center.x, -0.075, (a_edge + b_edge) * 0.5)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_floor", center, Vector3(corridor_width, 0.15, length), floor_mat)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_west_wall", Vector3(center.x - corridor_width * 0.5, wall_h * 0.5, center.z), Vector3(WALL_THICKNESS, wall_h, length + WALL_THICKNESS), wall_mat, true)
		_add_box(dungeon_root, a_id + "_to_" + b_id + "_east_wall", Vector3(center.x + corridor_width * 0.5, wall_h * 0.5, center.z), Vector3(WALL_THICKNESS, wall_h, length + WALL_THICKNESS), wall_mat, true)
		_add_corridor_dressing(a_id + "_to_" + b_id, center, length, corridor_width, false, variant)


func _corridor_variant_for(a_id: String, b_id: String) -> String:
	var pair_key := _room_pair_key(a_id, b_id)
	if corridor_variants.has(pair_key):
		return String(corridor_variants[pair_key])
	var a: Dictionary = rooms[a_id] as Dictionary
	var b: Dictionary = rooms[b_id] as Dictionary
	var a_type: String = String(a["type"])
	var b_type: String = String(b["type"])
	var variant := "medium"
	if a_type == "root_tunnel" or b_type == "root_tunnel" or a_type == "shifting_root_gate" or b_type == "shifting_root_gate":
		variant = "long_root"
	elif a_type == "stone_watch_room" or b_type == "stone_watch_room" or a_type == "forgotten_exit" or b_type == "forgotten_exit":
		variant = "wide"
	elif randf() < 0.22:
		variant = "threshold"
	elif randf() < 0.42:
		variant = "narrow"
	corridor_variants[pair_key] = variant
	return variant


func _corridor_width_for_variant(variant: String) -> float:
	match variant:
		"wide":
			return 4.4
		"narrow", "long_root":
			return 2.45
		"threshold":
			return 3.8
		_:
			return CORRIDOR_WIDTH


func _corridor_floor_for_variant(variant: String) -> Material:
	match variant:
		"long_root":
			return _mat("floor_root")
		"wide":
			return _mat("floor_cold")
		_:
			return _mat("floor")


func _add_corridor_dressing(base_name: String, center: Vector3, length: float, width: float, horizontal: bool, variant: String) -> void:
	if length < 2.6:
		_add_box(dungeon_root, base_name + "_threshold_slab", center + Vector3(0.0, 0.03, 0.0), Vector3(1.4 if horizontal else width, 0.05, width if horizontal else 1.4), _mat("stone"))
		return

	var rib_count := clampi(int(length / 3.1), 1, 5)
	for i in range(rib_count):
		var t := (float(i) + 0.5) / float(rib_count)
		var along := -length * 0.5 + length * t
		var side := -1.0 if i % 2 == 0 else 1.0
		var position := center + (Vector3(along, 0.25, side * width * 0.42) if horizontal else Vector3(side * width * 0.42, 0.25, along))
		match variant:
			"long_root":
				_add_cylinder(dungeon_root, base_name + "_root_rib", position, 0.075, randf_range(0.7, 1.15), _mat("root"), false, Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.25, 0.25)))
			"wide":
				_add_box(dungeon_root, base_name + "_fallen_edge_slab", position, Vector3(0.65, 0.12, 0.38), _mat("stone"), false, Vector3(0.0, randf_range(-0.45, 0.45), 0.0))
			"narrow":
				_add_box(dungeon_root, base_name + "_pinch_shadow", position, Vector3(0.32, 0.12, 0.5), _mat("wall_dark"), false, Vector3(0.0, randf_range(-0.35, 0.35), 0.0))
			_:
				_add_box(dungeon_root, base_name + "_cracked_marker", position, Vector3(0.55, 0.04, 0.1), _mat("floor_crack"), false, Vector3(0.0, randf_range(-0.6, 0.6), 0.0))


func _add_room_details() -> void:
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		var room_type: String = room["type"]
		_add_room_light(room)
		_add_cracked_floor_marks(room)
		match room_type:
			"wake":
				_decorate_wake(room)
			"fathers_map_room":
				_decorate_map_room(room)
			"root_tunnel":
				_decorate_root_tunnel(room)
			"rat_nest":
				_decorate_rat_nest(room)
			"mushroom_cellar":
				_decorate_mushroom_cellar(room)
			"stone_watch_room":
				_decorate_stone_watch(room)
			"broken_shrine":
				_decorate_broken_shrine(room)
			"shifting_root_gate":
				_decorate_shifting_root_gate(room)
			"loot_niche":
				_decorate_loot_niche(room)
			"key_alcove":
				_decorate_key_alcove(room)
			"sealed_white_door":
				_decorate_sealed_door(room)
			"forgotten_exit":
				_decorate_forgotten_exit(room)
			_:
				_decorate_root_tunnel(room)


func _add_room_entry_triggers() -> void:
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		var size: Vector2 = room["size"]
		var message := _message_for_room(room)
		_add_lore_trigger(message, _room_point(room, 0.0, 0.0, 0.6), Vector3(maxf(size.x - 2.2, 2.0), 1.4, maxf(size.y - 2.2, 2.0)), 2.6, room_id)


func _message_for_room(room: Dictionary) -> String:
	var room_type: String = room["type"]
	match room_type:
		"wake":
			return "Toprak nefes almıyor. Dinliyor."
		"fathers_map_room":
			return "Kökaltı gerçek. İnme. Geri dön."
		"broken_shrine":
			return "Haritalar yukarıdakiler içindir. Aşağıda yollar canlıdır."
		"shifting_root_gate":
			return "Duvarlar yerini hatırlamıyor."
		"sealed_white_door":
			return "Bazı kapılar açılmaz. Seni bekler."
		"key_alcove":
			if _key_alcove_is_active():
				return "Kökler burada bir anahtarı saklamış."
			return "Kör şeyler bile burada yolu biliyor."
		"forgotten_exit":
			return "Toprak burada ince. Kaçış yakında."
		"rat_nest":
			return "Kör sıçanlar köklerin arasında dinliyor."
		"mushroom_cellar":
			return "Mantarların nefesi ağırlaşıyor."
		"stone_watch_room":
			return "Taşlar nöbet tutuyor."
		"loot_niche":
			return "Bir şey geride bırakılmış."
		"root_tunnel":
			return "Kör şeyler bile burada yolu biliyor."
		_:
			return "Kök Tüneli yön değiştiriyor."


func _enemy_offset_for_index(index: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var angle := TAU * float(index) / float(total)
	return Vector2(cos(angle) * 0.28, sin(angle) * 0.24)


func _spawn_enemy_in_room(room_id: String, scene: PackedScene, x_ratio: float, z_ratio: float) -> Node3D:
	if scene == null or not rooms.has(room_id):
		return null
	var room: Dictionary = rooms[room_id] as Dictionary
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return null
	dungeon_root.add_child(enemy)
	var spawn_position := _room_point(room, x_ratio, z_ratio, 0.0)
	enemy.global_position = _safe_room_spawn_position(room, spawn_position, 0.9)
	enemy.set_meta("room_id", room_id)
	enemy.add_to_group("room_enemy_%s" % room_id)
	room_enemy_counts[room_id] = int(room_enemy_counts.get(room_id, 0)) + 1
	return enemy


func _show_puzzle_message() -> void:
	var now := Time.get_ticks_msec()
	if now - puzzle_message_time_msec < 1200:
		return
	puzzle_message_time_msec = now
	if not puzzle_shift_done:
		puzzle_shift_done = true
		var anchor_room_id := current_room_id
		if anchor_room_id.is_empty() and player:
			anchor_room_id = _room_id_at_position(player.global_position)
		_trigger_labyrinth_shift(anchor_room_id, false, "Kökler kıpırdadı.")
		return
	show_message("Kökler kıpırdadı.", 1.4)
	return


func _trigger_labyrinth_shift(anchor_room_id: String, add_temporary_gate := false, message := "Kökaltı yer değiştirdi.") -> void:
	labyrinth_shift_count += 1
	add_entropy(2.0, false)
	var affected := _shift_affected_rooms(anchor_room_id)
	for room_id in affected:
		if rooms.has(room_id) and _room_state(room_id) != ROOM_STATE_CLEARED:
			_set_room_state(room_id, ROOM_STATE_SHIFTED)
	_mark_minimap_uncertain(affected)
	show_message(message, 2.0)
	_set_objective("Kökler yer değiştirdi")
	print("KOKLER shift event ", labyrinth_shift_count, " anchor=", anchor_room_id, " affected=", affected)
	if add_temporary_gate:
		_spawn_temporary_shift_gate_for_optional_leaf(anchor_room_id)


func _shift_affected_rooms(anchor_room_id: String) -> Array[String]:
	var affected: Array[String] = []
	if anchor_room_id.is_empty() or not rooms.has(anchor_room_id):
		return affected
	for neighbor_id in _neighbor_room_ids_for(anchor_room_id):
		if not affected.has(neighbor_id):
			affected.append(neighbor_id)
	var extra_leaf := _first_optional_leaf_room(anchor_room_id)
	if not extra_leaf.is_empty() and not affected.has(extra_leaf):
		affected.append(extra_leaf)
	return affected


func _first_optional_leaf_room(anchor_room_id: String) -> String:
	for room_id in room_order:
		if room_id == start_room_id or room_id == key_room_id or room_id == exit_room_id or room_id == current_room_id or room_id == anchor_room_id:
			continue
		var neighbors := _neighbor_room_ids_for(room_id)
		if neighbors.size() == 1:
			return room_id
	return ""


func _spawn_temporary_shift_gate_for_optional_leaf(anchor_room_id: String) -> void:
	var leaf_room_id := _first_optional_leaf_room(anchor_room_id)
	if leaf_room_id.is_empty():
		return
	var neighbors := _neighbor_room_ids_for(leaf_room_id)
	if neighbors.is_empty():
		return
	var parent_room_id: String = String(neighbors[0])
	var gate_position := _connection_midpoint(leaf_room_id, parent_room_id)
	var gate_size := _connection_gate_size(leaf_room_id, parent_room_id)
	var gate := _add_box(dungeon_root, "temporary_labyrinth_shift_gate", gate_position, gate_size, _mat("root"), true)
	_add_box(gate, "temporary_labyrinth_shift_amber", Vector3(0.0, gate_size.y * 0.08, -gate_size.z * 0.52), Vector3(maxf(gate_size.x * 0.74, 0.08), 0.08, 0.05), _mat("amber"))
	_mark_minimap_uncertain([leaf_room_id, parent_room_id])
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(gate):
		_set_shift_gate_open(gate, true)


func _connection_midpoint(a_id: String, b_id: String) -> Vector3:
	var a: Dictionary = rooms[a_id] as Dictionary
	var b: Dictionary = rooms[b_id] as Dictionary
	var a_center: Vector3 = a["center"]
	var b_center: Vector3 = b["center"]
	var a_size: Vector2 = a["size"]
	var b_size: Vector2 = b["size"]
	if absf(a_center.z - b_center.z) < 0.1:
		var direction := signf(b_center.x - a_center.x)
		var a_edge := a_center.x + direction * a_size.x * 0.5
		var b_edge := b_center.x - direction * b_size.x * 0.5
		return Vector3((a_edge + b_edge) * 0.5, 0.58, a_center.z)
	var direction := signf(b_center.z - a_center.z)
	var a_edge := a_center.z + direction * a_size.y * 0.5
	var b_edge := b_center.z - direction * b_size.y * 0.5
	return Vector3(a_center.x, 0.58, (a_edge + b_edge) * 0.5)


func _connection_gate_size(a_id: String, b_id: String) -> Vector3:
	var a: Dictionary = rooms[a_id] as Dictionary
	var b: Dictionary = rooms[b_id] as Dictionary
	var a_center: Vector3 = a["center"]
	var b_center: Vector3 = b["center"]
	var variant := _corridor_variant_for(a_id, b_id)
	var width := _corridor_width_for_variant(variant) + 0.45
	if absf(a_center.z - b_center.z) < 0.1:
		return Vector3(0.42, 1.15, width)
	return Vector3(width, 1.15, 0.42)


func _spawn_root_fragment(position: Vector3) -> void:
	if ROOT_FRAGMENT_SCENE == null:
		return
	var pickup := ROOT_FRAGMENT_SCENE.instantiate() as Node3D
	if pickup == null:
		return
	dungeon_root.add_child(pickup)
	pickup.set("manager", self)
	var pickup_position := _safe_pickup_position(Vector3(position.x, 0.35, position.z), 0.45)
	pickup.global_position = pickup_position


func _spawn_root_shrine(position: Vector3) -> void:
	if ROOT_SHRINE_SCENE == null:
		return
	var shrine := ROOT_SHRINE_SCENE.instantiate() as Node3D
	if shrine == null:
		return
	dungeon_root.add_child(shrine)
	shrine.set("manager", self)
	var shrine_position := _safe_pickup_position(Vector3(position.x, 0.0, position.z), 0.8)
	shrine.global_position = shrine_position


func _spawn_guaranteed_root_shrine() -> void:
	var shrine_room_id := _first_room_id_of_type("fathers_map_room")
	if shrine_room_id.is_empty():
		shrine_room_id = start_room_id
	if shrine_room_id.is_empty() or not rooms.has(shrine_room_id):
		return
	var room: Dictionary = rooms[shrine_room_id] as Dictionary
	var shrine_position := _room_point(room, 0.32, -0.28, 0.0)
	_spawn_root_shrine(shrine_position)


func _first_room_id_of_type(room_type: String) -> String:
	for room_id in room_order:
		if not rooms.has(room_id):
			continue
		var room: Dictionary = rooms[room_id] as Dictionary
		if String(room.get("type", "")) == room_type:
			return room_id
	return ""


func _spawn_weapon_pickup(position: Vector3, weapon_id: String) -> void:
	if WEAPON_PICKUP_SCENE == null:
		return
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as Node3D
	if pickup == null:
		return
	dungeon_root.add_child(pickup)
	pickup.set("weapon_id", weapon_id)
	pickup.set("manager", self)
	var pickup_position := _safe_pickup_position(Vector3(position.x, 0.45, position.z), 0.55)
	pickup.global_position = pickup_position


func _get_random_weapon_id() -> String:
	var manager := _get_player_weapon_manager()
	if manager:
		return manager.get_random_loot_weapon_id()
	var ids: Array[String] = ["mace", "spear", "ember_staff", "mushroom_sling"]
	return ids.pick_random()


func _add_pressure_plate(plate_name: String, position: Vector3, callback: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = plate_name
	area.collision_layer = 0
	area.collision_mask = 2
	dungeon_root.add_child(area)
	area.global_position = Vector3(position.x, 0.08, position.z)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.35, 0.18, 1.0)
	shape.shape = box_shape
	area.add_child(shape)

	var plate_visual: Node3D = _add_box(area, plate_name + "_Visual", Vector3(0.0, -0.08, 0.0), Vector3(1.25, 0.06, 0.9), _mat("pressure_plate"))
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player_2_5d"):
			if is_instance_valid(plate_visual):
				var tween := create_tween()
				tween.tween_property(plate_visual, "position:y", -0.12, 0.07)
				tween.tween_property(plate_visual, "position:y", -0.08, 0.12)
			callback.call()
	)
	return area


func _add_shift_gate(gate_name: String, position: Vector3, size: Vector3, initially_open := false) -> Node3D:
	var gate := _add_box(dungeon_root, gate_name, position, size, _mat("root"), true)
	_add_box(gate, gate_name + "_Amber", Vector3(0.0, size.y * 0.05, -size.z * 0.52), Vector3(size.x * 0.86, size.y * 0.08, 0.05), _mat("amber"))
	_set_shift_gate_open(gate, initially_open, true)
	return gate


func _set_shift_gate_open(gate: Node3D, open: bool, instant := false) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	var token: int = int(gate.get_meta("gate_anim_token", 0)) + 1
	gate.set_meta("gate_anim_token", token)
	if open:
		_set_collision_shapes_disabled(gate, true)
		if instant:
			gate.scale = Vector3(1.0, 0.08, 1.0)
			gate.visible = false
			return
		gate.visible = true
		var tween: Tween = create_tween()
		tween.tween_property(gate, "scale", Vector3(1.0, 0.08, 1.0), _gate_animation_duration(true))
		tween.tween_callback(func() -> void:
			if is_instance_valid(gate) and int(gate.get_meta("gate_anim_token", 0)) == token:
				gate.visible = false
				_set_collision_shapes_disabled(gate, true)
		)
	else:
		gate.visible = true
		_set_collision_shapes_disabled(gate, true)
		if instant:
			gate.scale = Vector3.ONE
			_set_collision_shapes_disabled(gate, false)
			return
		gate.scale = Vector3(1.0, 0.08, 1.0)
		var closed_scale: Vector3 = Vector3(1.0, 1.0 + minf(entropy_value * 0.025, 0.14), 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(gate, "scale", closed_scale, _gate_animation_duration(false)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void:
			if is_instance_valid(gate) and int(gate.get_meta("gate_anim_token", 0)) == token:
				_set_collision_shapes_disabled(gate, false)
		)


func _gate_animation_duration(open: bool) -> float:
	var pressure: float = minf(entropy_value * 0.014, 0.1)
	if open:
		return maxf(0.14, 0.24 - pressure * 0.45)
	return maxf(0.16, 0.32 - pressure)


func _set_collision_shapes_disabled(node: Node, disabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = disabled
		_set_collision_shapes_disabled(child, disabled)


func _add_key_pickup(position: Vector3) -> void:
	var area := Area3D.new()
	area.name = "KeyPickup25D"
	area.collision_layer = 16
	area.collision_mask = 2
	area.set_script(KEY_PICKUP_SCRIPT)
	dungeon_root.add_child(area)
	area.global_position = Vector3(position.x, 0.45, position.z)

	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 0.48
	cylinder_shape.height = 0.95
	shape.shape = cylinder_shape
	area.add_child(shape)

	var visual := Node3D.new()
	visual.name = "KeyVisual"
	area.add_child(visual)
	area.set("visual", visual)
	_add_cylinder(visual, "Ring", Vector3.ZERO, 0.2, 0.08, _mat("key"), false, Vector3(PI * 0.5, 0.0, 0.0))
	_add_box(visual, "Stem", Vector3(0.0, 0.0, 0.32), Vector3(0.08, 0.08, 0.5), _mat("key"))
	_add_box(visual, "Tooth", Vector3(0.15, 0.0, 0.52), Vector3(0.22, 0.08, 0.08), _mat("key"))
	
	
func _opposite_door_ratio(room_id: String) -> Vector2:
	if not rooms.has(room_id):
		return Vector2(0.0, 0.34)
	var room: Dictionary = rooms[room_id] as Dictionary
	var cell: Vector2i = room["cell"]
	var neighbor_ids := _neighbor_room_ids_for(room_id)
	var dir := Vector2.ZERO
	for nid in neighbor_ids:
		if not rooms.has(nid):
			continue
		var ncell: Vector2i = (rooms[nid] as Dictionary)["cell"]
		dir += Vector2(float(ncell.x - cell.x), float(ncell.y - cell.y))
	if dir == Vector2.ZERO:
		return Vector2(0.0, 0.34)
	var opposite := -dir.normalized()
	return opposite * 0.34


func _add_back_stair(position: Vector3, yaw := 0.0) -> void:
	var area := Area3D.new()
	area.name = "BackStair25D"
	area.collision_layer = 16
	area.collision_mask = 2
	area.set_script(BACK_STAIR_SCRIPT)
	dungeon_root.add_child(area)
	area.global_position = Vector3(position.x, 0.6, position.z)
	area.rotation.y = yaw

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.4, 1.7, 1.0)
	shape.shape = box_shape
	area.add_child(shape)

	for i in range(4):
		_add_box(area, "back_step", Vector3(0.0, -0.25 + float(i) * 0.22, -0.3 + float(i) * 0.22), Vector3(1.7, 0.16, 0.34), _mat("stone"))
	_add_box(area, "back_arch_left", Vector3(-0.9, 0.3, 0.0), Vector3(0.34, 1.7, 0.42), _mat("stone"))
	_add_box(area, "back_arch_right", Vector3(0.9, 0.3, 0.0), Vector3(0.34, 1.7, 0.42), _mat("stone"))
	_add_box(area, "back_glow", Vector3(0.0, 0.55, 0.18), Vector3(1.2, 0.9, 0.06), _mat("exit_glow"))


func _add_exit_gate(position: Vector3, is_portal := false) -> void:
	var area := Area3D.new()
	area.name = "ForgottenExitGate25D"
	area.collision_layer = 16
	area.collision_mask = 2
	area.set_script(EXIT_GATE_SCRIPT)
	dungeon_root.add_child(area)
	area.global_position = Vector3(position.x, 0.7, position.z)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.8, 1.9, 1.2)
	shape.shape = box_shape
	area.add_child(shape)

	if is_portal:
		# Son mikro kat: ana katmandan çıkış portalı (parlak turkuaz)
		_add_box(area, "PortalLeft", Vector3(-0.95, 0.15, 0.0), Vector3(0.34, 2.1, 0.4), _mat("stone"))
		_add_box(area, "PortalRight", Vector3(0.95, 0.15, 0.0), Vector3(0.34, 2.1, 0.4), _mat("stone"))
		_add_box(area, "PortalTop", Vector3(0.0, 1.18, 0.0), Vector3(2.1, 0.34, 0.4), _mat("stone"))
		_add_box(area, "PortalVeil", Vector3(0.0, 0.15, 0.02), Vector3(1.55, 1.95, 0.1), _mat("lumen_glow"))
		_add_box(area, "PortalCore", Vector3(0.0, 0.15, 0.06), Vector3(0.9, 1.4, 0.08), _mat("exit_glow"))
	else:
		# Normal mikro kat: bir alt kata iniş merdiveni
		for i in range(4):
			_add_box(area, "down_step", Vector3(0.0, 0.35 - float(i) * 0.24, -0.3 + float(i) * 0.26), Vector3(1.8, 0.16, 0.36), _mat("stone"))
		_add_box(area, "down_arch_left", Vector3(-0.95, 0.2, -0.35), Vector3(0.34, 1.7, 0.42), _mat("white_stone"))
		_add_box(area, "down_arch_right", Vector3(0.95, 0.2, -0.35), Vector3(0.34, 1.7, 0.42), _mat("white_stone"))
		_add_box(area, "down_lintel", Vector3(0.0, 1.0, -0.35), Vector3(2.3, 0.3, 0.46), _mat("white_stone"))
		_add_box(area, "down_glow", Vector3(0.0, 0.05, 0.2), Vector3(1.3, 0.6, 0.06), _mat("exit_glow"))


func _add_lore_trigger(message: String, position: Vector3, size: Vector3, duration := 3.5, room_id := "") -> void:
	var area := Area3D.new()
	area.name = "RoomTrigger25D"
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(LORE_TRIGGER_SCRIPT)
	dungeon_root.add_child(area)
	area.set("message", message)
	area.set("duration", duration)
	area.set_meta("room_id", room_id)
	area.global_position = Vector3(position.x, 0.6, position.z)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	area.add_child(shape)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player_2_5d") and not room_id.is_empty():
			_on_room_entered(room_id)
	)


func _decorate_wake(room: Dictionary) -> void:
	_add_box(dungeon_root, "wake_broken_slab_a", _room_point(room, -0.28, -0.22, 0.02), Vector3(2.2, 0.06, 0.55), _mat("stone"), false, Vector3(0.0, 0.25, 0.0))
	_add_box(dungeon_root, "wake_broken_slab_b", _room_point(room, 0.22, 0.25, 0.02), Vector3(1.8, 0.06, 0.5), _mat("stone"), false, Vector3(0.0, -0.2, 0.0))
	_add_rotten_beam(_room_point(room, -0.36, 0.25, 0.16), 1.5)
	_add_root_cluster(_room_point(room, 0.34, -0.28, 0.04), 4)


func _decorate_map_room(room: Dictionary) -> void:
	_create_blocking_prop(dungeon_root, "map_table", _room_point(room, 0.0, 0.0, 0.32), Vector3(2.4, 0.28, 1.25), _mat("stone"))
	_add_box(dungeon_root, "map_parchment", _room_point(room, 0.0, 0.0, 0.5), Vector3(1.8, 0.04, 0.85), _mat("parchment"))
	_add_box(dungeon_root, "map_line_a", _room_point(room, -0.06, -0.02, 0.54), Vector3(1.0, 0.03, 0.06), _mat("ink"))
	_add_box(dungeon_root, "map_line_b", _room_point(room, 0.1, 0.08, 0.55), Vector3(0.08, 0.03, 0.55), _mat("ink"))
	_add_cylinder(dungeon_root, "broken_compass", _room_point(room, 0.25, -0.03, 0.58), 0.16, 0.04, _mat("key"), false, Vector3(PI * 0.5, 0.0, 0.0))
	_add_standing_stones(room, 4)


func _decorate_root_tunnel(room: Dictionary) -> void:
	_add_root_cluster(_room_point(room, -0.34, -0.22, 0.04), 5)
	_add_root_cluster(_room_point(room, 0.34, 0.24, 0.04), 4)
	_add_rotten_beam(_room_point(room, 0.0, -0.35, 0.18), 1.8)
	_add_extinguished_torch(_room_point(room, -0.22, 0.32, 0.08))


func _decorate_rat_nest(room: Dictionary) -> void:
	for i in range(8):
		var position := _random_room_point(room, 1.8, 0.06)
		_add_cylinder(dungeon_root, "rat_nest_root", position, 0.055, randf_range(0.7, 1.15), _mat("root"), false, Vector3(PI * 0.5, randf() * TAU, randf_range(-0.35, 0.35)))
	_add_box(dungeon_root, "rat_bone_a", _room_point(room, -0.18, 0.22, 0.08), Vector3(0.12, 0.1, 0.75), _mat("bone"), false, Vector3(0.0, 0.7, 0.0))
	_add_box(dungeon_root, "rat_bone_b", _room_point(room, 0.22, -0.18, 0.08), Vector3(0.12, 0.1, 0.55), _mat("bone"), false, Vector3(0.0, -0.4, 0.0))


func _decorate_mushroom_cellar(room: Dictionary) -> void:
	for i in range(7):
		_add_mushroom_cluster(_random_room_point(room, 1.8, 0.04))
	_add_sphere(dungeon_root, "faint_blue_fungus", _room_point(room, 0.32, 0.25, 0.28), 0.22, _mat("lumen_glow"), Vector3(1.0, 0.55, 1.0))
	_create_soft_blocking_cylinder_prop(dungeon_root, "spore_stone", _room_point(room, -0.32, -0.25, 0.16), 0.22, 0.32, _mat("fungus_stone"))


func _decorate_stone_watch(room: Dictionary) -> void:
	_create_blocking_prop(dungeon_root, "watch_fallen_pillar", _room_point(room, -0.25, 0.25, 0.22), Vector3(2.8, 0.35, 0.42), _mat("stone"), Vector3(0.0, 0.45, 0.0))
	_create_blocking_prop(dungeon_root, "watch_slab_a", _room_point(room, 0.35, -0.28, 0.45), Vector3(0.7, 0.9, 0.6), _mat("stone"))
	_create_blocking_prop(dungeon_root, "watch_slab_b", _room_point(room, -0.38, -0.18, 0.35), Vector3(0.55, 0.7, 0.55), _mat("stone"))
	_add_standing_stones(room, 6)


func _decorate_broken_shrine(room: Dictionary) -> void:
	_create_blocking_cylinder_prop(dungeon_root, "shrine_center", _room_point(room, 0.0, 0.0, 0.55), 0.45, 1.1, _mat("stone"))
	_add_box(dungeon_root, "shrine_cap", _room_point(room, 0.0, 0.0, 1.15), Vector3(1.0, 0.26, 0.72), _mat("white_stone"))
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		_create_soft_blocking_cylinder_prop(dungeon_root, "shrine_orbit_stone", _room_point(room, cos(angle) * 0.34, sin(angle) * 0.28, 0.26), 0.14, 0.52, _mat("stone"))
	_add_box(dungeon_root, "shrine_root_scar", _room_point(room, 0.0, -0.12, 1.32), Vector3(0.14, 0.24, 0.08), _mat("root"))


func _decorate_shifting_root_gate(room: Dictionary) -> void:
	var room_id: String = String(room["id"])
	_add_root_cluster(_room_point(room, -0.36, -0.32, 0.04), 5)
	_add_root_cluster(_room_point(room, -0.36, 0.32, 0.04), 5)
	_add_rotten_beam(_room_point(room, 0.04, 0.0, 0.18), 2.2)
	_add_box(dungeon_root, room_id + "_memory_line_a", _room_point(room, -0.02, -0.22, 0.035), Vector3(4.1, 0.04, 0.14), _mat("floor_crack"), false, Vector3(0.0, 0.06, 0.0))
	_add_box(dungeon_root, room_id + "_memory_line_b", _room_point(room, -0.02, 0.22, 0.035), Vector3(4.1, 0.04, 0.14), _mat("floor_crack"), false, Vector3(0.0, -0.06, 0.0))

	var gate_a: Node3D = _add_shift_gate(room_id + "_lower_root_gate", _room_point(room, 0.24, -0.24, 0.55), Vector3(0.42, 1.1, 2.15), false)
	var gate_b: Node3D = _add_shift_gate(room_id + "_upper_root_gate", _room_point(room, 0.24, 0.24, 0.55), Vector3(0.42, 1.1, 2.15), true)
	var reset_gate: Node3D = _add_shift_gate(room_id + "_side_reset_gate", _room_point(room, -0.08, 0.0, 0.5), Vector3(1.8, 0.95, 0.35), true)

	_add_pressure_plate(room_id + "_plate_lower", _room_point(room, -0.24, -0.24, 0.05), func() -> void:
		_set_shift_gate_open(gate_a, true)
		_set_shift_gate_open(gate_b, false)
		_set_shift_gate_open(reset_gate, true)
		_show_puzzle_message()
	)
	_add_pressure_plate(room_id + "_plate_upper", _room_point(room, -0.24, 0.24, 0.05), func() -> void:
		_set_shift_gate_open(gate_a, false)
		_set_shift_gate_open(gate_b, true)
		_set_shift_gate_open(reset_gate, true)
		_show_puzzle_message()
	)
	_add_pressure_plate(room_id + "_plate_reset", _room_point(room, 0.0, 0.0, 0.05), func() -> void:
		_set_shift_gate_open(gate_a, true)
		_set_shift_gate_open(gate_b, true)
		_set_shift_gate_open(reset_gate, true)
		_show_puzzle_message()
	)
	_add_pressure_plate(room_id + "_plate_return", _room_point(room, 0.36, 0.0, 0.05), func() -> void:
		_set_shift_gate_open(gate_a, true)
		_set_shift_gate_open(gate_b, true)
		_set_shift_gate_open(reset_gate, true)
		_show_puzzle_message()
	)

	_create_soft_blocking_prop(dungeon_root, room_id + "_optional_bowl", _room_point(room, 0.38, 0.0, 0.18), Vector3(0.62, 0.24, 0.62), _mat("stone"))
	_add_box(dungeon_root, room_id + "_white_hint_slit", _room_point(room, 0.38, 0.0, 0.42), Vector3(0.12, 0.48, 0.08), _mat("exit_glow"))


func _decorate_loot_niche(room: Dictionary) -> void:
	_create_soft_blocking_prop(dungeon_root, "loot_crate_a", _room_point(room, -0.32, 0.22, 0.24), Vector3(0.75, 0.48, 0.65), _mat("crate"))
	_create_soft_blocking_prop(dungeon_root, "loot_crate_b", _room_point(room, 0.28, 0.2, 0.18), Vector3(0.56, 0.36, 0.48), _mat("crate"))
	_create_soft_blocking_cylinder_prop(dungeon_root, "stone_bowl", _room_point(room, 0.0, -0.2, 0.18), 0.32, 0.18, _mat("stone"))
	_add_root_cluster(_room_point(room, 0.36, -0.28, 0.04), 3)
	
func _key_alcove_is_active() -> bool:
	return current_micro_floor == key_floor

func _decorate_key_alcove(room: Dictionary) -> void:
	_add_root_cluster(_room_point(room, -0.32, -0.18, 0.04), 6)
	_add_root_cluster(_room_point(room, 0.32, -0.18, 0.04), 6)
	_add_box(dungeon_root, "key_plinth", _room_point(room, 0.0, 0.18, 0.18), Vector3(1.35, 0.36, 1.0), _mat("stone"))
	_create_blocking_prop(dungeon_root, "key_back_marker", _room_point(room, 0.0, -0.34, 0.62), Vector3(1.2, 1.25, 0.18), _mat("white_stone"))
	if not _key_alcove_is_active():
		_decorate_root_tunnel(room)
		return

func _decorate_sealed_door(room: Dictionary) -> void:
	_add_lost_neighborhood_hint(_room_point(room, -0.28, 0.18, 0.0))
	_create_blocking_prop(dungeon_root, "sealed_door_back", _room_point(room, 0.22, -0.24, 0.74), Vector3(1.55, 1.5, 0.18), _mat("white_stone"))
	_add_box(dungeon_root, "sealed_door_line", _room_point(room, 0.22, -0.25, 0.78), Vector3(0.1, 1.15, 0.08), _mat("exit_glow"))


func _decorate_forgotten_exit(room: Dictionary) -> void:
	_create_blocking_prop(dungeon_root, "exit_fallen_pillar", _room_point(room, -0.35, -0.28, 0.18), Vector3(2.4, 0.36, 0.42), _mat("stone"), Vector3(0.0, -0.3, 0.0))
	_add_cylinder(dungeon_root, "exit_root_a", _room_point(room, 0.34, 0.32, 0.55), 0.12, 1.35, _mat("root"), false, Vector3(0.55, 0.0, 0.2))
	_add_cylinder(dungeon_root, "exit_root_b", _room_point(room, -0.34, 0.32, 0.45), 0.09, 1.05, _mat("root"), false, Vector3(-0.35, 0.4, -0.2))
	_add_deeper_stair_hint(_room_point(room, -0.1, 0.34, 0.0))


func _add_room_light(room: Dictionary) -> void:
	var room_type: String = String(room["type"])
	var room_size: Vector2 = room["size"]
	var light := OmniLight3D.new()
	light.name = String(room["id"]) + "_RoomLight"
	light.shadow_enabled = false
	light.omni_range = maxf(room_size.x, room_size.y) * 0.72
	light.light_energy = 0.45
	light.light_color = Color(0.95, 0.68, 0.42)
	match room_type:
		"mushroom_cellar":
			light.light_color = Color(0.55, 0.95, 0.78)
			light.light_energy = 0.36
		"sealed_white_door", "forgotten_exit":
			light.light_color = Color(0.72, 0.95, 0.84)
			light.light_energy = 0.52
		"stone_watch_room":
			light.light_color = Color(0.78, 0.72, 0.62)
			light.light_energy = 0.40
		"shifting_root_gate":
			light.light_color = Color(0.9, 0.52, 0.25)
			light.light_energy = 0.48
		_:
			pass
	dungeon_root.add_child(light)
	light.global_position = _room_point(room, 0.0, 0.0, 2.7)


func _add_cracked_floor_marks(room: Dictionary) -> void:
	var room_type: String = String(room["type"])
	var count := 3
	match room_type:
		"rat_nest", "stone_watch_room", "forgotten_exit":
			count = 5
		"loot_niche", "key_alcove":
			count = 2
		"wake", "fathers_map_room", "broken_shrine", "shifting_root_gate":
			count = 4
		_:
			pass
	for i in range(count):
		var crack_position := _random_room_point(room, 2.2, 0.025)
		var crack_size := Vector3(randf_range(0.7, 1.65), 0.035, randf_range(0.06, 0.16))
		_add_box(dungeon_root, String(room["id"]) + "_floor_crack", crack_position, crack_size, _mat("floor_crack"), false, Vector3(0.0, randf_range(-0.9, 0.9), 0.0))


func _add_deeper_stair_hint(position: Vector3) -> void:
	for i in range(4):
		_create_soft_blocking_prop(dungeon_root, "collapsed_deeper_step", position + Vector3(0.0, 0.05 + float(i) * 0.06, float(i) * 0.28), Vector3(1.65 - float(i) * 0.18, 0.08, 0.22), _mat("wall_dark"), Vector3.ZERO, Vector3(0.52, 0.8, 0.7))
	_create_blocking_prop(dungeon_root, "lower_passage_shadow", position + Vector3(0.0, 0.22, 1.24), Vector3(1.55, 0.42, 0.18), _mat("wall_dark"))
	_add_box(dungeon_root, "lower_passage_glow", position + Vector3(0.0, 0.42, 1.15), Vector3(0.82, 0.58, 0.06), _mat("exit_glow"))


func _add_root_cluster(position: Vector3, count: int) -> void:
	for i in range(count):
		var angle := randf() * TAU
		var offset := Vector3(cos(angle) * randf_range(0.0, 0.45), 0.32, sin(angle) * randf_range(0.0, 0.45))
		_add_cylinder(dungeon_root, "root_cluster", position + offset, randf_range(0.055, 0.12), randf_range(0.75, 1.35), _mat("root"), false, Vector3(randf_range(-0.45, 0.45), angle, randf_range(-0.3, 0.3)))
	if count >= 5:
		_create_blocking_cylinder_prop(dungeon_root, "root_cluster_core", position + Vector3(0.0, 0.36, 0.0), 0.34, 0.72, _mat("root"), Vector3.ZERO)
	elif count >= 3:
		_create_soft_blocking_cylinder_prop(dungeon_root, "root_cluster_soft_core", position + Vector3(0.0, 0.32, 0.0), 0.28, 0.58, _mat("root"))


func _add_rotten_beam(position: Vector3, length: float) -> void:
	_create_soft_blocking_prop(dungeon_root, "rotten_beam", position, Vector3(length, 0.22, 0.22), _mat("wood"), Vector3(0.0, randf_range(-0.7, 0.7), 0.0), Vector3(0.58, 0.8, 0.7))


func _add_extinguished_torch(position: Vector3) -> void:
	_create_soft_blocking_cylinder_prop(dungeon_root, "dead_torch_base", position + Vector3(0.0, 0.14, 0.0), 0.08, 0.35, _mat("stone"))
	_add_box(dungeon_root, "dead_torch_coal", position + Vector3(0.0, 0.34, 0.0), Vector3(0.22, 0.08, 0.22), _mat("coal"))


func _add_standing_stones(room: Dictionary, count: int) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var position := _room_point(room, cos(angle) * 0.36, sin(angle) * 0.28, 0.28)
		_create_soft_blocking_prop(dungeon_root, "standing_stone", position, Vector3(0.28, randf_range(0.45, 0.85), 0.24), _mat("stone"), Vector3(0.0, angle, 0.0), Vector3(0.72, 0.8, 0.72))


func _add_mushroom_cluster(position: Vector3) -> void:
	var stem_height := randf_range(0.22, 0.42)
	_create_soft_blocking_cylinder_prop(dungeon_root, "mushroom_stem", position + Vector3(0.0, stem_height * 0.5, 0.0), 0.055, stem_height, _mat("mushroom_stem"))
	var cap := _add_sphere(dungeon_root, "mushroom_cap", position + Vector3(0.0, stem_height + 0.05, 0.0), randf_range(0.16, 0.25), _mat("mushroom_cap"), Vector3(1.35, 0.38, 1.1))
	cap.rotation.y = randf() * TAU


func _add_lost_neighborhood_hint(position: Vector3) -> void:
	_create_blocking_prop(dungeon_root, "lost_house_base", position + Vector3(0.0, 0.2, 0.0), Vector3(1.25, 0.4, 0.75), _mat("house"))
	_add_box(dungeon_root, "lost_house_roof", position + Vector3(0.0, 0.55, -0.04), Vector3(1.0, 0.24, 0.9), _mat("stone"), false, Vector3(0.0, 0.0, 0.15))
	_add_box(dungeon_root, "lost_house_gap", position + Vector3(0.08, 0.22, -0.4), Vector3(0.32, 0.24, 0.08), _mat("wall_dark"))


func _room_id_at_position(position: Vector3) -> String:
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		var center: Vector3 = room["center"]
		var size: Vector2 = room["size"]
		if absf(position.x - center.x) <= size.x * 0.5 and absf(position.z - center.z) <= size.y * 0.5:
			return room_id
	return ""


func _room_point(room: Dictionary, x_ratio: float, z_ratio: float, y := 0.0) -> Vector3:
	var center: Vector3 = room["center"]
	var size: Vector2 = room["size"]
	return center + Vector3(x_ratio * size.x, y, z_ratio * size.y)


func _random_room_point(room: Dictionary, padding: float, y := 0.0) -> Vector3:
	var center: Vector3 = room["center"]
	var size: Vector2 = room["size"]
	var half_x := maxf(size.x * 0.5 - padding, 1.0)
	var half_z := maxf(size.y * 0.5 - padding, 1.0)
	var x := randf_range(-half_x, half_x)
	var z := randf_range(-half_z, half_z)
	if absf(x) < 1.7 and absf(z) < 1.7:
		x += 2.0 * signf(x if absf(x) > 0.01 else randf_range(-1.0, 1.0))
	return center + Vector3(x, y, z)


func _add_debug_room_label(room_id: String) -> void:
	var room: Dictionary = rooms[room_id] as Dictionary
	var center: Vector3 = room["center"]
	var room_type: String = room["type"]
	var label := Label3D.new()
	label.name = room_id + "_DebugLabel"
	label.text = room_id + "\n" + room_type
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.modulate = Color(0.82, 0.72, 0.5, 0.85)
	dungeon_root.add_child(label)
	label.global_position = center + Vector3(0.0, 1.7, 0.0)


func _create_visual_prop(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> Node3D:
	return _add_box(parent, node_name, position, size, mat, false, rotation)


func _create_decorative_prop(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> Node3D:
	return _create_visual_prop(parent, node_name, position, size, mat, rotation)


func _create_non_blocking_prop(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> Node3D:
	return _create_decorative_prop(parent, node_name, position, size, mat, rotation)


func _create_soft_blocking_prop(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO, collision_scale: Vector3 = Vector3(0.62, 0.85, 0.62), avoid_path_lanes := true) -> Node3D:
	var collision_size := Vector3(
		maxf(size.x * collision_scale.x, 0.18),
		maxf(size.y * collision_scale.y, 0.16),
		maxf(size.z * collision_scale.z, 0.18)
	)
	var footprint := Vector2(collision_size.x, collision_size.z)
	var use_collision := parent == dungeon_root and _blocking_prop_position_is_safe(position, footprint, avoid_path_lanes)
	var prop := _add_box_with_collision_size(parent, node_name, position, size, mat, use_collision, rotation, collision_size)
	if use_collision:
		_reserve_blocking_prop_position(position, clampf(maxf(footprint.x, footprint.y) * 0.5, 0.16, 0.48))
	return prop


func _create_soft_blocking_cylinder_prop(parent: Node, node_name: String, position: Vector3, radius: float, height: float, mat: Material, rotation := Vector3.ZERO, collision_radius_scale: float = 0.58, collision_height_scale: float = 0.75, avoid_path_lanes := true) -> Node3D:
	var collision_radius := maxf(radius * collision_radius_scale, 0.12)
	var collision_height := maxf(height * collision_height_scale, 0.16)
	var footprint := Vector2(collision_radius * 2.0, collision_radius * 2.0)
	var use_collision := parent == dungeon_root and _blocking_prop_position_is_safe(position, footprint, avoid_path_lanes)
	var prop := _add_cylinder_with_collision_size(parent, node_name, position, radius, height, mat, use_collision, rotation, collision_radius, collision_height)
	if use_collision:
		_reserve_blocking_prop_position(position, clampf(collision_radius, 0.16, 0.48))
	return prop


func _create_blocking_prop(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO, avoid_path_lanes := true) -> Node3D:
	var footprint := Vector2(size.x, size.z)
	var use_collision := parent == dungeon_root and _blocking_prop_position_is_safe(position, footprint, avoid_path_lanes)
	var prop := _add_box(parent, node_name, position, size, mat, use_collision, rotation)
	if use_collision:
		_reserve_blocking_prop_position(position, clampf(maxf(footprint.x, footprint.y) * 0.5, 0.25, 0.85))
	return prop


func _create_blocking_cylinder_prop(parent: Node, node_name: String, position: Vector3, radius: float, height: float, mat: Material, rotation := Vector3.ZERO, avoid_path_lanes := true) -> Node3D:
	var footprint := Vector2(radius * 2.0, radius * 2.0)
	var use_collision := parent == dungeon_root and _blocking_prop_position_is_safe(position, footprint, avoid_path_lanes)
	var prop := _add_cylinder(parent, node_name, position, radius, height, mat, use_collision, rotation)
	if use_collision:
		_reserve_blocking_prop_position(position, clampf(radius, 0.25, 0.85))
	return prop


func _blocking_prop_position_is_safe(position: Vector3, footprint: Vector2, avoid_path_lanes: bool) -> bool:
	var room_id := _room_id_at_position(position)
	if room_id.is_empty() or not rooms.has(room_id):
		return true
	var room: Dictionary = rooms[room_id] as Dictionary
	if _is_in_door_clearance(room, position, footprint):
		return false
	if avoid_path_lanes and _is_in_tight_room_path_lane(room, position, footprint):
		return false
	var radius := maxf(footprint.x, footprint.y) * 0.5 + 0.35
	return not _is_near_reserved_blocker(room_id, position, radius)


func _is_in_door_clearance(room: Dictionary, position: Vector3, footprint: Vector2) -> bool:
	var center: Vector3 = room["center"]
	var size: Vector2 = room["size"]
	var openings: Array = room["openings"] as Array
	var local := Vector2(position.x - center.x, position.z - center.z)
	var edge_band := 2.25 + maxf(footprint.x, footprint.y) * 0.35
	var gap_clearance := DOOR_GAP * 0.5 + maxf(footprint.x, footprint.y) * 0.55
	if openings.has("north") and absf(local.x) <= gap_clearance and local.y <= -size.y * 0.5 + edge_band:
		return true
	if openings.has("south") and absf(local.x) <= gap_clearance and local.y >= size.y * 0.5 - edge_band:
		return true
	if openings.has("west") and absf(local.y) <= gap_clearance and local.x <= -size.x * 0.5 + edge_band:
		return true
	if openings.has("east") and absf(local.y) <= gap_clearance and local.x >= size.x * 0.5 - edge_band:
		return true
	return false


func _is_in_tight_room_path_lane(room: Dictionary, position: Vector3, footprint: Vector2) -> bool:
	var size: Vector2 = room["size"]
	if size.x > 12.5 and size.y > 9.0:
		return false
	var center: Vector3 = room["center"]
	var openings: Array = room["openings"] as Array
	var local := Vector2(position.x - center.x, position.z - center.z)
	var lane_clearance := 1.15 + maxf(footprint.x, footprint.y) * 0.5
	if openings.has("north") and openings.has("south") and absf(local.x) <= lane_clearance:
		return true
	if openings.has("west") and openings.has("east") and absf(local.y) <= lane_clearance:
		return true
	return false


func _reserve_blocking_prop_position(position: Vector3, radius: float) -> void:
	var room_id := _room_id_at_position(position)
	if room_id.is_empty():
		return
	if not blocking_prop_positions.has(room_id):
		blocking_prop_positions[room_id] = []
	var entries: Array = blocking_prop_positions[room_id] as Array
	entries.append({
		"position": position,
		"radius": radius,
	})
	blocking_prop_positions[room_id] = entries


func _is_near_reserved_blocker(room_id: String, position: Vector3, radius: float) -> bool:
	if not blocking_prop_positions.has(room_id):
		return false
	var entries: Array = blocking_prop_positions[room_id] as Array
	for entry_variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		if not entry.has("position") or not entry.has("radius"):
			continue
		var blocker_position: Vector3 = entry["position"]
		var blocker_radius := float(entry["radius"])
		var distance_xz := Vector2(position.x - blocker_position.x, position.z - blocker_position.z).length()
		if distance_xz < radius + blocker_radius + 0.35:
			return true
	return false


func _safe_room_spawn_position(room: Dictionary, preferred_position: Vector3, clearance: float) -> Vector3:
	var room_id := String(room["id"])
	if not _is_near_reserved_blocker(room_id, preferred_position, clearance):
		return preferred_position
	var candidates: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(0.24, -0.18),
		Vector2(-0.24, -0.18),
		Vector2(0.24, 0.18),
		Vector2(-0.24, 0.18),
		Vector2(0.0, -0.28),
		Vector2(0.0, 0.28),
	]
	for candidate_ratio in candidates:
		var candidate := _room_point(room, candidate_ratio.x, candidate_ratio.y, preferred_position.y)
		if _is_in_door_clearance(room, candidate, Vector2(clearance * 2.0, clearance * 2.0)):
			continue
		if not _is_near_reserved_blocker(room_id, candidate, clearance):
			return candidate
	return preferred_position


func _safe_pickup_position(position: Vector3, clearance: float) -> Vector3:
	var room_id := _room_id_at_position(position)
	if room_id.is_empty() or not rooms.has(room_id):
		return position
	var room: Dictionary = rooms[room_id] as Dictionary
	return _safe_room_spawn_position(room, position, clearance)


func _add_box(parent: Node, node_name: String, position: Vector3, size: Vector3, mat: Material, collision := false, rotation := Vector3.ZERO) -> Node3D:
	return _add_box_with_collision_size(parent, node_name, position, size, mat, collision, rotation, size)


func _add_box_with_collision_size(parent: Node, node_name: String, position: Vector3, visual_size: Vector3, mat: Material, collision := false, rotation := Vector3.ZERO, collision_size: Vector3 = Vector3.ZERO) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = visual_size
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = mat

	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "_Body"
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.global_position = position
		body.rotation = rotation
		body.add_child(visual)
		visual.position = Vector3.ZERO
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = collision_size if collision_size != Vector3.ZERO else visual_size
		shape.shape = box_shape
		body.add_child(shape)
		return body

	parent.add_child(visual)
	visual.position = position
	visual.rotation = rotation
	return visual


func _add_cylinder(parent: Node, node_name: String, position: Vector3, radius: float, height: float, mat: Material, collision := false, rotation := Vector3.ZERO) -> Node3D:
	return _add_cylinder_with_collision_size(parent, node_name, position, radius, height, mat, collision, rotation, radius, height)


func _add_cylinder_with_collision_size(parent: Node, node_name: String, position: Vector3, radius: float, height: float, mat: Material, collision := false, rotation := Vector3.ZERO, collision_radius: float = 0.0, collision_height: float = 0.0) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = mat

	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "_Body"
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.global_position = position
		body.rotation = rotation
		body.add_child(visual)
		visual.position = Vector3.ZERO
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = collision_radius if collision_radius > 0.0 else radius
		cylinder_shape.height = collision_height if collision_height > 0.0 else height
		shape.shape = cylinder_shape
		body.add_child(shape)
		return body

	parent.add_child(visual)
	visual.position = position
	visual.rotation = rotation
	return visual


func _add_sphere(parent: Node, node_name: String, position: Vector3, radius: float, mat: Material, mesh_scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = mat
	parent.add_child(visual)
	visual.position = position
	visual.scale = mesh_scale
	return visual


func _build_materials() -> void:
	mats = {
		"floor": _make_material(Color(0.18, 0.135, 0.09)),
		"floor_root": _make_material(Color(0.16, 0.105, 0.07)),
		"floor_cold": _make_material(Color(0.18, 0.18, 0.16)),
		"floor_green": _make_material(Color(0.13, 0.17, 0.13)),
		"floor_crack": _make_material(Color(0.065, 0.043, 0.03)),
		"wall": _make_material(Color(0.085, 0.065, 0.05)),
		"wall_dark": _make_material(Color(0.045, 0.035, 0.03)),
		"stone": _make_material(Color(0.31, 0.29, 0.25)),
		"white_stone": _make_material(Color(0.70, 0.70, 0.64)),
		"root": _make_material(Color(0.20, 0.10, 0.055)),
		"pressure_plate": _make_material(Color(0.36, 0.22, 0.11), Color(0.28, 0.14, 0.04), 0.22),
		"amber": _make_material(Color(0.86, 0.43, 0.13), Color(0.8, 0.28, 0.06), 0.6),
		"wood": _make_material(Color(0.25, 0.14, 0.08)),
		"coal": _make_material(Color(0.05, 0.045, 0.04)),
		"bone": _make_material(Color(0.63, 0.56, 0.43)),
		"parchment": _make_material(Color(0.62, 0.52, 0.36)),
		"ink": _make_material(Color(0.09, 0.06, 0.035)),
		"key": _make_material(Color(0.76, 0.54, 0.18), Color(0.35, 0.22, 0.05), 0.35),
		"crate": _make_material(Color(0.29, 0.20, 0.14)),
		"house": _make_material(Color(0.40, 0.39, 0.36)),
		"mushroom_stem": _make_material(Color(0.70, 0.60, 0.52)),
		"mushroom_cap": _make_material(Color(0.50, 0.16, 0.22)),
		"fungus_stone": _make_material(Color(0.27, 0.18, 0.22)),
		"lumen_glow": _make_material(Color(0.33, 0.82, 0.68), Color(0.22, 0.82, 0.70), 0.85),
		"exit_glow": _make_material(Color(0.75, 0.95, 0.82, 0.62), Color(0.55, 0.95, 0.75), 0.8),
	}


func _mat(id: String) -> Material:
	return mats.get(id) as Material


func _make_material(color: Color, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

			
func set_pending_swap_pickup(pickup: Node3D) -> void:
	_pending_swap_pickup = pickup
	
	
func _spawn_room_contents() -> void:
	_spawn_test_weapons_in_start_room()
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		var room_type: String = room["type"]
		match room_type:
			"root_tunnel":
				_spawn_enemy_in_room(room_id, BLIND_RAT_SCENE, -0.22, 0.12)
				if randf() < 0.35:
					_spawn_enemy_in_room(room_id, BLIND_RAT_SCENE, 0.25, -0.18)
			"rat_nest":
				var rat_count := randi_range(2, 4)
				for i in range(rat_count):
					var offset := _enemy_offset_for_index(i, rat_count)
					_spawn_enemy_in_room(room_id, BLIND_RAT_SCENE, offset.x, offset.y)
				if randf() < 0.45:
					_spawn_root_fragment(_room_point(room, 0.28, 0.24, 0.35))
			"mushroom_cellar":
				_spawn_enemy_in_room(room_id, MUSHROOM_MAN_SCENE, -0.18, 0.12)
				if randf() < 0.55:
					_spawn_enemy_in_room(room_id, MUSHROOM_MAN_SCENE, 0.24, -0.18)
			"stone_watch_room":
				_spawn_enemy_in_room(room_id, STONE_GUARD_SCENE, 0.08, 0.06)
				if randf() < 0.45:
					_spawn_enemy_in_room(room_id, BLIND_RAT_SCENE, -0.28, -0.22)
				if randf() < 0.32:
					_spawn_weapon_pickup(_room_point(room, -0.28, 0.22, 0.45), _get_random_weapon_id())
			"loot_niche":
				_spawn_root_fragment(_room_point(room, -0.24, 0.2, 0.35))
				if randf() < 0.45:
					_spawn_weapon_pickup(_room_point(room, 0.18, -0.12, 0.45), _get_random_weapon_id())
			"broken_shrine":
				if randf() < 0.5:
					_spawn_enemy_in_room(room_id, BLIND_RAT_SCENE, 0.28, 0.18)
			"shifting_root_gate":
				_spawn_root_fragment(_room_point(room, 0.34, 0.26, 0.35))
				if randf() < 0.35:
					_spawn_weapon_pickup(_room_point(room, 0.34, -0.26, 0.45), _get_random_weapon_id())
			_:
				pass


func _spawn_test_weapons_in_start_room() -> void:
	if not spawn_debug_start_weapons:
		return
	# Sadece ilk ana katmanın ilk mikro katında test silahları
	if current_main_layer != 1 or current_micro_floor != 1:
		return
	for room_id in room_order:
		var room: Dictionary = rooms[room_id] as Dictionary
		if room.get("type") == "wake":
			var center: Vector3 = _room_point(room, 0.0, 0.0, 0.0)
			_spawn_weapon_pickup(center + Vector3(-1.2, 0, 0), "mace")
			_spawn_weapon_pickup(center + Vector3(1.2, 0, 0), "spear")
			_spawn_weapon_pickup(center + Vector3(0, 0, -1.2), "ember_staff")
			_spawn_weapon_pickup(center + Vector3(0, 0, 1.2), "mushroom_sling")
			break

# ─── KATMAN SİSTEMİ ───

func _setup_new_main_layer() -> void:
	total_micro_floors = randi_range(5, 6)
	key_floor = randi_range(1, total_micro_floors - 1)
	current_micro_floor = 1
	# Her mikro kat için unique seed üret
	micro_floor_seeds.clear()
	micro_floor_state.clear()
	for i in range(1, total_micro_floors + 1):
		micro_floor_seeds[i] = randi()
		micro_floor_state[i] = {"collected": [], "dead_enemies": []}
	print("=== ANA KATMAN ", current_main_layer, " başladı. ", total_micro_floors, " mikro kat. Anahtar: kat ", key_floor)


func _spawn_boss(exit_room: Dictionary) -> void:
	var boss_scene: PackedScene = MUSHROOM_MAN_SCENE
	if current_main_layer >= 3:
		boss_scene = STONE_GUARD_SCENE

	var boss := _spawn_enemy_in_room(exit_room_id, boss_scene, -0.22, 0.0)
	if boss == null:
		_boss_required = false
		return

	if "max_hp" in boss:
		boss.max_hp = int(boss.max_hp) * 4
		boss.hp = boss.max_hp
		var hb = boss.get("_health_bar")
		if hb:
			hb.set_health(boss.hp, boss.max_hp)
			hb.width = 2.0
	if "damage" in boss:
		boss.damage = int(boss.damage) + 1
	if "move_speed" in boss:
		boss.move_speed = float(boss.move_speed) * 0.85
	if "damage" in boss:
		boss.damage = int(boss.damage) + 1

	var model_node := boss.get_node_or_null("Model")
	if model_node:
		model_node.scale *= 1.8

	boss.add_to_group("boss_2_5d")
	boss.set_meta("is_boss", true)
	if boss.has_method("refresh_base_scale"):
		boss.call("refresh_base_scale")
	boss.tree_exited.connect(_on_boss_defeated)

	show_message("Bir şey burada bekliyor. Büyük. Yaşlı.", 2.6)


func _on_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	show_message("Yaşlı şey sustu. Yol açıldı.", 2.4)


func _advance_micro_floor() -> void:
	current_micro_floor += 1
	print("=== MİKRO KAT ", current_micro_floor, "/", total_micro_floors, " başlıyor")
	
	# Run lock'u kaldır (dungeon yeniden kurulacak)
	run_locked = false
	has_key = false
	_update_key_ui()
	
	# Dungeon'u yeniden kur
	_clear_dungeon()
	_build_dungeon()
	
	
func go_back_micro_floor() -> void:
	if current_micro_floor <= 1:
		return
	current_micro_floor -= 1
	print("=== MİKRO KAT ", current_micro_floor, "/", total_micro_floors, " (geri çıkıldı)")

	run_locked = false
	has_key = false
	_update_key_ui()

	_spawn_at_exit_room = true

	_clear_dungeon()
	_build_dungeon()


# TEST: Doğrudan son (boss) mikro katına ışınlan. Anahtarı da verir.
func debug_jump_to_boss() -> void:
	current_micro_floor = total_micro_floors
	print("=== TEST: Boss katına ışınlandı (kat ", current_micro_floor, ")")
	run_locked = false
	has_key = true
	_spawn_at_exit_room = true   # boss'u görmek için exit odasında doğ
	_update_key_ui()
	_clear_dungeon()
	_build_dungeon()


func _clear_dungeon() -> void:
	# dungeon_root'u temizle, yeniden kurulsun
	if dungeon_root and is_instance_valid(dungeon_root):
		dungeon_root.queue_free()
