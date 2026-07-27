extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main_2_5d.tscn"
const FIXED_SEED := 20260727
const PHYSICS_FRAMES := 180


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("main scene could not be loaded")
		return

	var scene := packed_scene.instantiate()
	if scene == null:
		_fail("main scene could not be instantiated")
		return

	scene.set("generation_seed", FIXED_SEED)
	scene.set("debug_print_generation", false)
	scene.set("start_fullscreen", false)
	root.add_child(scene)
	current_scene = scene
	scene.set("run_locked", true)

	for _frame in range(PHYSICS_FRAMES):
		await physics_frame

	var mushrooms := get_nodes_in_group("mushroom_man_2_5d")
	var guards := get_nodes_in_group("stone_guard_2_5d")
	if mushrooms.is_empty():
		_fail("fixed seed created no Mushroom Man")
		return

	var mushroom_agents := _count_agents(mushrooms)
	if mushroom_agents < 0:
		return
	var guard_agents := _count_agents(guards)
	if guard_agents < 0:
		return
	if mushroom_agents != mushrooms.size():
		_fail(
			"mushroom agent mismatch mushrooms=%d agents=%d"
			% [mushrooms.size(), mushroom_agents]
		)
		return
	if guard_agents != guards.size():
		_fail(
			"guard agent mismatch guards=%d agents=%d"
			% [guards.size(), guard_agents]
		)
		return

	print(
		"NAV_SMOKE mushrooms=%d mushroom_agents=%d guards=%d guard_agents=%d PASS"
		% [mushrooms.size(), mushroom_agents, guards.size(), guard_agents]
	)
	quit(0)


func _count_agents(enemies: Array[Node]) -> int:
	var total := 0
	for enemy in enemies:
		var enemy_agent_count := 0
		for child in enemy.get_children():
			if child is NavigationAgent3D:
				enemy_agent_count += 1
		if enemy_agent_count != 1:
			_fail(
				"%s has %d NavigationAgent3D children"
				% [enemy.name, enemy_agent_count]
			)
			return -1
		total += enemy_agent_count
	return total


func _fail(reason: String) -> void:
	push_error("NAV_SMOKE FAIL: %s" % reason)
	quit(1)
