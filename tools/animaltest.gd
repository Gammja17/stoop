extends Node
## 개발용: 섬과 본섬의 새 동물을 찍고 행동을 확인한다. godot --path . -- --animaltest

var main
var dir := "res://.shots/"


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + name + ".png"))
	print("[ani] shot ", name, "  fps=", Engine.get_frames_per_second())


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func fly_at(from: Vector3, look_at: Vector3, spd := 16.0) -> void:
	var f: Falcon = main.falcon
	f.spawn_flying(from, (look_at - from).normalized(), spd)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	main.camera.begin_blend(0.0)


## 매에게 먹이(비둘기)를 쥐여 준다
func give_prey() -> Prey:
	var f: Falcon = main.falcon
	var fl = main.prey_mgr.spawn_group("pigeon", f.global_position, f.global_position, 50.0, 1, "test")
	var p: Prey = fl.members[0]
	p.take(f)
	f.grab(p)
	return p


func perch_ground(p: Vector3, facing: Vector3) -> void:
	var f: Falcon = main.falcon
	p.y = WorldShape.ground(p.x, p.z) + 0.2
	f.spawn_perched({"pos": p, "kind": "ground", "facing": facing})
	main.camera.mode = ChaseCamera.Mode.ORBIT
	main.camera.orbit_behind(facing)
	main.camera.orbit_dist = 5.0


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(3.0)
	main.day_night.set_time(10.0)
	var pm = main.prey_mgr
	var f: Falcon = main.falcon
	var sb := WorldShape.island_by_id("seabird")
	var se := WorldShape.island_by_id("seals")
	var ba := WorldShape.island_by_id("bats")
	# 바다쇠오리 (섬 근처에 가야 생긴다)
	fly_at(sb.center + Vector3(-500, 120, 0), sb.center, 16.0)
	for i in 8:
		await wait(0.5)
		f.spawn_flying(sb.center + Vector3(-500, 120, 0), Vector3.RIGHT, 16.0)
	var mur: Prey = null
	for p in pm.prey:
		if is_instance_valid(p) and p.kind == "murrelet":
			mur = p
			break
	print("[ani] murrelet found=", mur != null)
	if mur:
		var mp := mur.global_position
		fly_at(mp + Vector3(-30, 14, -30), mp, 12.0)
		await wait(0.8)
		await shot("A01_murrelets")
		# 가까이 내리꽂으면 잠수하는가
		f.spawn_flying(mur.global_position + Vector3(0, 30, -25), Vector3(0, -0.8, 0.6).normalized(), 30.0)
		mur.alarm()
		await wait(1.2)
		print("[ani] murrelet after chase state=", mur.state if is_instance_valid(mur) else -1, " y=", mur.global_position.y if is_instance_valid(mur) else 0.0)
	# 번식지 갈매기 떼가 덤비는가
	var col: Vector3 = sb.info.colony
	fly_at(col + Vector3(90, 5, -40), col, 12.0)
	for i in 8:
		await wait(0.5)
		f.speed = 12.0
	var mobbing := 0
	for g in pm.colony_gulls:
		if g.mode == Mobber.M.MOB:
			mobbing += 1
	print("[ani] colony gulls mobbing=", mobbing, "/", pm.colony_gulls.size(), " stamina=", f.stamina)
	await shot("A02_colony_mob")
	# 물범과 흰꼬리수리
	var kn: Vector3 = se.info.knoll
	fly_at(kn + Vector3(-120, 25, 160), kn, 14.0)
	await wait(0.6)
	await shot("A03_seals")
	var stolen := [false]
	give_prey()
	fly_at(kn + Vector3(-60, 30, 120), kn + Vector3(-200, 30, 300), 14.0)
	for i in 30:
		await wait(0.5)
		f.speed = 14.0
		if pm.eagle.mode == SeaEagle.E.CHASE and i == 6:
			await shot("A04_eagle_chase")
		if f.carrying == null:
			stolen[0] = true
			break
	print("[ani] eagle mode=", pm.eagle.mode, " stole=", stolen[0])
	# 돌고래
	var sl: SeaLife = pm.sea_life
	var d0: Node3D = sl.dolphins[0].node
	fly_at(d0.global_position + Vector3(-40, 12, -40), d0.global_position, 12.0)
	await wait(1.5)
	await shot("A05_dolphins")
	# 고래
	sl.whale_t = 0.0
	fly_at(Vector3(1000, 60, -300), Vector3(1600, 30, -300), 12.0)
	await wait(4.0)
	print("[ani] whale state=", sl.whale_state, " pos=", sl.whale_pos)
	if sl.whale_state >= 0.0:
		fly_at(sl.whale_pos + Vector3(-70, 25, -70), sl.whale_pos, 8.0)
		await wait(0.5)
		await shot("A06_whale")
	# 여우: 땅에서 먹는 매에게 다가온다
	var fox: Fox = pm.foxes[0]
	print("[ani] fox pos=", fox.global_position, " ground=", WorldShape.ground(fox.global_position.x, fox.global_position.z), " home=", fox.home)
	var fp := fox.global_position + Vector3(20, 0, 10)
	perch_ground(fp, (fox.global_position - fp).normalized())
	give_prey()
	await wait(1.0)
	await shot("A07_fox")
	for i in 40:
		await wait(0.5)
		if i % 4 == 0:
			print("[ani]   fox mode=%d dist=%.1f falcon=%d carrying=%s" % [fox.mode, fox._flat_dist(f.global_position), f.state, f.carrying != null])
		if f.state == Falcon.State.FLYING:
			break
	print("[ani] fox mode=", fox.mode, " falcon state=", f.state, " fox has prey=", fox.prey != null)
	# 까마귀 떼: 앉아 있으면 몰려온다
	var cr: Mobber = pm.crows[0]
	perch_ground(cr.home + Vector3(10, 0, 10), Vector3.RIGHT)
	for i in 10:
		await wait(0.5)
	var cm := 0
	for c in pm.crows:
		if c.mode == Mobber.M.MOB:
			cm += 1
	print("[ani] crows mobbing=", cm)
	await shot("A08_crows")
	# 박쥐: 해 질 녘
	main.day_night.set_time(19.2)
	pm.emerge_bats()
	var cave: Vector3 = ba.info.cave
	fly_at(cave + Vector3(-160, 25, 60), cave, 10.0)
	await wait(14.0)
	var bats := 0
	for p in pm.prey:
		if is_instance_valid(p) and p.kind == "bat" and p.visible:
			bats += 1
	print("[ani] bats out=", bats)
	fly_at(cave + Vector3(-110, 30, 40), cave + Vector3(-40, 15, 0), 8.0)
	await wait(0.6)
	await shot("A09_bats")
	get_tree().quit()
