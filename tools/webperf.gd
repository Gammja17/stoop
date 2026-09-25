extends Node
## 개발용: 웹 렉 원인 찾기. 하나씩 꺼 가며 프레임·CPU 시간을 잰다.
## godot --path . --rendering-method gl_compatibility -- --webperf

var main


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func measure(label: String) -> void:
	_hold()
	await wait(1.0)
	var frames := 0
	var proc := 0.0
	var draws := 0.0
	var prims := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 2500000:
		await get_tree().process_frame
		_hold()
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var sec := (Time.get_ticks_usec() - t0) / 1000000.0
	print("[web] %-18s fps=%6.1f  cpu=%5.2f ms  draws=%4d  tris=%dk" % [label, frames / sec, proc / frames * 1000.0, int(draws / frames), int(prims / frames / 1000.0)])


func _hold() -> void:
	var f: Falcon = main.falcon
	f.spawn_flying(WorldShape.eyrie + Vector3(-40, 120, 60), Vector3(-0.6, -0.25, 0.75).normalized(), 18.0)


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
	main.events._next = 99999.0
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	main.falcon.input_enabled = false
	var pm = main.prey_mgr
	print("[web] prey=%d flocks=%d" % [pm.prey.size(), pm.flocks.size()])
	await measure("all")
	Sfx.set_wind_active(false)
	await measure("- wind synth")
	_hide(pm.prey + pm.flocks)
	await measure("- prey")
	_hide([pm.village_pigeons])
	await measure("- village pigeons")
	_hide(pm.mobbers)
	await measure("- mobbers")
	_hide(pm.gulls)
	await measure("- gulls")
	_hide([pm.sea_life])
	await measure("- sea life")
	_hide(pm.foxes + [pm.eagle])
	await measure("- fox/eagle")
	var mms := []
	for c in main.world.get_children():
		if c is MultiMeshInstance3D and c.name != "City" and c.name != "Clouds":
			mms.append(c)
	_hide(mms)
	await measure("- vegetation")
	_hide([main.world.get_node("Clouds")])
	await measure("- clouds")
	main.get_node("ScreenLayer").visible = false
	await measure("- screen fx")
	main.get_node("Sun").shadow_enabled = false
	await measure("- shadows(sun)")
	main.world.water.visible = false
	await measure("- water")
	main.hud.visible = false
	await measure("- hud")
	get_tree().quit()
