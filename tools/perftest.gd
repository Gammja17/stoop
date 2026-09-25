extends Node
## 개발용: 무엇이 프레임을 먹는지 하나씩 꺼 보며 잰다. godot --path . -- --perftest

var main


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func measure(label: String) -> void:
	await wait(1.0)
	var frames := 0
	var proc := 0.0
	var draws := 0.0
	var objs := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var sec := (Time.get_ticks_usec() - t0) / 1000000.0
	print("[perf] %-22s fps=%5.1f  process=%.2f ms  draws=%d  objects=%d" % [label, frames / sec, proc / frames * 1000.0, int(draws / frames), int(objs / frames)])


func _hide(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(3.0)
	main.day_night.set_time(11.0)
	var f: Falcon = main.falcon
	# 둥지 앞에서 동쪽 바다를 바라보며 활공 (고정 자세)
	f.spawn_flying(WorldShape.eyrie + Vector3(40, 60, 0), Vector3(1, -0.05, 0.2).normalized(), 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	f.input_enabled = false
	var hold := func():
		f.spawn_flying(WorldShape.eyrie + Vector3(40, 60, 0), Vector3(1, -0.05, 0.2).normalized(), 18.0)
	var pm = main.prey_mgr
	hold.call()
	await measure("all")
	hold.call()
	_hide([pm.sea_life])
	await measure("- sea life")
	hold.call()
	_hide(pm.mobbers)
	await measure("- mobbers")
	hold.call()
	_hide(pm.foxes + [pm.eagle])
	await measure("- fox/eagle")
	hold.call()
	var isl_prey := []
	for p in pm.prey:
		if is_instance_valid(p) and WorldShape.island_near(p.global_position, 400.0) != null:
			isl_prey.append(p)
	print("[perf] island prey=", isl_prey.size(), " total prey=", pm.prey.size())
	_hide(isl_prey)
	await measure("- island prey")
	hold.call()
	var extra_clouds := []
	for i in range(26, main.world.clouds.size()):
		extra_clouds.append(main.world.clouds[i].node)
	_hide(extra_clouds)
	await measure("- extra clouds")
	hold.call()
	var isl_mesh := []
	for c in main.world.get_children():
		if c.name.begins_with("Island_"):
			isl_mesh.append(c)
	_hide(isl_mesh)
	await measure("- island meshes")
	get_tree().quit()
