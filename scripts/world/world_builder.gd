class_name WorldBuilder
extends Node3D
## 지형 메시, 바다, 해식 기둥, 둥지 선반, 마을, 나무·바위, 상승기류, 구름을 만든다.

const TEX := "res://assets/textures/terrain/"
const NATURE := "res://assets/models/nature/"
const PIRATE := "res://assets/models/pirate/"
const BOATS := "res://assets/models/boats/"

const CHUNK := 25   # 청크당 셀 수

var terrain_mat: ShaderMaterial
var rock_mat: ShaderMaterial
var water: MeshInstance3D
var water_mat: ShaderMaterial
var deciduous: Array = []          # [{mm: MultiMeshInstance3D, green: Mesh, fall: Mesh}]
var boats: Array[Node3D] = []
var clouds: Array = []             # {pos, r}
var thermal_cols: Array[MeshInstance3D] = []
var thermal_boost := 1.0
var eyrie_root: Node3D
var _rng := RandomNumberGenerator.new()
var _forest_noise := FastNoiseLite.new()


func build() -> void:
	_rng.seed = 98765
	_forest_noise.seed = 555
	_forest_noise.frequency = 0.004
	WorldShape.setup()
	_make_materials()
	_build_terrain()
	await get_tree().process_frame
	_build_water()
	_build_stacks()
	_build_eyrie()
	await get_tree().process_frame
	_build_village()
	await get_tree().process_frame
	_build_vegetation()
	await get_tree().process_frame
	_build_thermals()
	_build_clouds()


func _tex(n: String) -> Texture2D:
	return load(TEX + n)


func _make_materials() -> void:
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	terrain_mat.set_shader_parameter("tex_grass", _tex("aerial_grass_rock_diff_1k.jpg"))
	terrain_mat.set_shader_parameter("nrm_grass", _tex("aerial_grass_rock_nor_gl_1k.jpg"))
	terrain_mat.set_shader_parameter("tex_rock", _tex("rock_face_03_diff_1k.jpg"))
	terrain_mat.set_shader_parameter("nrm_rock", _tex("rock_face_03_nor_gl_1k.jpg"))
	terrain_mat.set_shader_parameter("tex_sand", _tex("coast_sand_01_diff_1k.jpg"))
	terrain_mat.set_shader_parameter("tex_mud", _tex("brown_mud_02_diff_1k.jpg"))
	terrain_mat.set_shader_parameter("tex_snow", _tex("snow_field_aerial_col_1k.jpg"))
	rock_mat = ShaderMaterial.new()
	rock_mat.shader = load("res://shaders/rock.gdshader")
	rock_mat.set_shader_parameter("tex_rock", _tex("rock_face_03_diff_1k.jpg"))
	rock_mat.set_shader_parameter("tex_top", _tex("aerial_grass_rock_diff_1k.jpg"))
	rock_mat.set_shader_parameter("tex_snow", _tex("snow_field_aerial_col_1k.jpg"))


# ---------- 지형 ----------

func _build_terrain() -> void:
	var G := WorldShape.GRID
	var H := WorldShape.RENDER_HALF
	var C := WorldShape.CELL
	var n_chunks := (G - 1) / CHUNK
	var grid := WorldShape.grid
	var village := WorldShape.village
	for cj in n_chunks:
		for ci in n_chunks:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var tans := PackedFloat32Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var i0 := ci * CHUNK
			var j0 := cj * CHUNK
			var w := CHUNK + 1
			for j in range(j0, j0 + w):
				var z := -H + j * C
				var bf := WorldShape.bay_factor(z)
				for i in range(i0, i0 + w):
					var x := -H + i * C
					var h := grid[j * G + i]
					verts.append(Vector3(x, h, z))
					var hl := WorldShape.gh(i - 1, j)
					var hr := WorldShape.gh(i + 1, j)
					var hd := WorldShape.gh(i, j - 1)
					var hu := WorldShape.gh(i, j + 1)
					var n := Vector3(hl - hr, 2.0 * C, hd - hu).normalized()
					norms.append(n)
					var t := (Vector3.RIGHT - n * n.x).normalized()
					tans.append_array([t.x, t.y, t.z, -1.0])
					uvs.append(Vector2(x, z) * 0.1)
					var mud := bf * (1.0 - smoothstep(0.6, 3.5, h))
					var sand := (1.0 - bf) * (1.0 - smoothstep(1.2, 5.5, h)) * (1.0 if h > -8.0 else 0.6)
					var dv := Vector2(x - village.x, z - village.z).length()
					var dirt := (1.0 - smoothstep(60.0, 150.0, dv)) * 0.8
					cols.append(Color(mud, sand, dirt))
			for j in CHUNK:
				for i in CHUNK:
					var a := j * w + i
					var b := a + 1
					var c := a + w
					var d := c + 1
					idx.append_array([a, b, d, a, d, c])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_TANGENT] = tans
			arr[Mesh.ARRAY_TEX_UV] = uvs
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(0, terrain_mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.name = "Terrain_%d_%d" % [ci, cj]
			add_child(mi)


# ---------- 바다 ----------

func _build_water() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var pm := PlaneMesh.new()
	pm.size = Vector2(14000, 14000)
	water = MeshInstance3D.new()
	water.mesh = pm
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.name = "Sea"
	add_child(water)


func follow_camera(cam_pos: Vector3) -> void:
	if water:
		water.global_position = Vector3(snappedf(cam_pos.x, 100.0), 0.0, snappedf(cam_pos.z, 100.0))


# ---------- 모델 도우미 ----------

static func glb_parts(path: String) -> Array:
	var ps: PackedScene = load(path)
	var inst := ps.instantiate()
	var out := []
	_collect(inst, Transform3D.IDENTITY, out)
	inst.free()
	return out


static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append([(n as MeshInstance3D).mesh, t])
	for c in n.get_children():
		_collect(c, t, out)


func _place(path: String, pos: Vector3, rot_y: float, sc: Vector3, parent: Node3D = null) -> Node3D:
	var ps: PackedScene = load(path)
	var inst: Node3D = ps.instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = sc
	(parent if parent else self).add_child(inst)
	return inst


func _override_all(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_override_all(c, mat)


# ---------- 해식 기둥 ----------

func _build_stacks() -> void:
	var shapes := ["rock_tallB.glb", "rock_tallC.glb", "rock_tallB.glb", "rock_tallG.glb"]
	var sizes := {"rock_tallA.glb": Vector3(0.98, 1.0, 0.68), "rock_tallB.glb": Vector3(0.76, 0.88, 0.77), "rock_tallC.glb": Vector3(0.46, 0.78, 0.44), "rock_tallG.glb": Vector3(0.42, 0.78, 0.49)}
	var k := 0
	for s in WorldShape.stacks:
		var f: String = shapes[k % shapes.size()]
		k += 1
		var sz: Vector3 = sizes[f]
		var r: float = s.r
		var h: float = s.h
		var sc := Vector3(2.0 * r / sz.x, (h + 1.0) / sz.y, 2.0 * r / sz.z)
		var node := _place(NATURE + f, s.pos, _rng.randf() * TAU, sc)
		_override_all(node, rock_mat)
		# 밑동의 무너진 바위와 꼭대기 바위로 실루엣을 깨뜨린다
		var base: Vector3 = s.pos
		for i in _rng.randi_range(3, 5):
			var a := _rng.randf() * TAU
			var bp := base + Vector3(cos(a) * r * 0.95, -base.y - 1.5, sin(a) * r * 0.95)
			var bs := r * _rng.randf_range(0.45, 0.8)
			var bf: String = ["rock_largeA.glb", "rock_largeB.glb", "rock_largeD.glb"][i % 3]
			_override_all(_place(NATURE + bf, bp, _rng.randf() * TAU, Vector3(bs, bs * 0.9, bs)), rock_mat)
		var cap := _rng.randf_range(0.5, 0.8) * r
		var tp := base + Vector3(_rng.randf_range(-0.2, 0.2) * r, h - 0.35 * cap, _rng.randf_range(-0.2, 0.2) * r)
		_override_all(_place(NATURE + "rock_largeB.glb", tp, _rng.randf() * TAU, Vector3(cap * 1.4, cap * 0.8, cap * 1.3)), rock_mat)


# ---------- 둥지 선반 ----------

func _build_eyrie() -> void:
	eyrie_root = Node3D.new()
	eyrie_root.name = "Eyrie"
	add_child(eyrie_root)
	var e := WorldShape.eyrie
	var face := WorldShape.eyrie_facing
	eyrie_root.position = e
	eyrie_root.basis = Basis.looking_at(-face, Vector3.UP)
	# 선반: 납작한 바위를 절벽에 박아 넣는다
	var ledge := _place(NATURE + "rock_largeC.glb", Vector3(0, -1.6, 1.5), 0.0, Vector3(9.0, 5.0, 8.0), eyrie_root)
	_override_all(ledge, rock_mat)
	var cap := _place(NATURE + "rock_largeA.glb", Vector3(-2.5, -1.2, 3.5), 0.6, Vector3(6.0, 6.0, 5.0), eyrie_root)
	_override_all(cap, rock_mat)
	# 둥지 가장자리 돌
	for i in 7:
		var a := TAU * i / 7.0
		var p := Vector3(cos(a) * 1.1, -0.45, sin(a) * 1.1 + 0.4)
		var st := _place(NATURE + "rock_largeA.glb", p, _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.35, 0.55), eyrie_root)
		_override_all(st, rock_mat)


# ---------- 마을 ----------

func _build_village() -> void:
	var v := WorldShape.village
	var root := Node3D.new()
	root.name = "Village"
	add_child(root)
	var placed := []
	var tries := 0
	while placed.size() < 12 and tries < 300:
		tries += 1
		var p := v + Vector3(_rng.randf_range(-110, 90), 0, _rng.randf_range(-120, 120))
		p.y = WorldShape.ground(p.x, p.z)
		if p.y < 1.5 or WorldShape.normal(p.x, p.z).y < 0.93:
			continue
		var ok := true
		for q in placed:
			if (q as Vector3).distance_to(p) < 22.0:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var f := "structure-roof.glb" if _rng.randf() < 0.55 else "structure.glb"
		_place(PIRATE + f, p - Vector3(0, 0.3, 0), _rng.randf() * TAU, Vector3.ONE * 3.2, root)
		if _rng.randf() < 0.6:
			var off := Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
			var bp := p + off
			bp.y = WorldShape.ground(bp.x, bp.z)
			_place(PIRATE + ("barrel.glb" if _rng.randf() < 0.5 else "crate.glb"), bp, _rng.randf() * TAU, Vector3.ONE * 1.1, root)
	# 부두: 해안선에서 바다 쪽으로
	var dz := v.z + 10.0
	var cx := WorldShape.coast_x(dz)
	for i in 9:
		var dp := Vector3(cx - 8.0 + i * 6.8, 0.0, dz)
		_place(PIRATE + "structure-platform-dock.glb", dp + Vector3(0, -0.6, 0), 0.0, Vector3(2.7, 2.0, 2.7), root)
	# 배
	var boat_files := ["boat-fishing-small.glb", "boat-row-small.glb", "boat-sail-a.glb", "boat-fishing-small.glb", "boat-sail-b.glb", "boat-row-large.glb"]
	for i in boat_files.size():
		var bpos := Vector3(cx + 20.0 + _rng.randf_range(0, 110), 0.0, dz + _rng.randf_range(-70, 70))
		if WorldShape.ground(bpos.x, bpos.z) > -1.5:
			continue
		var folder: String = BOATS if boat_files[i].begins_with("boat-f") or boat_files[i].begins_with("boat-s") else PIRATE
		var b := _place(folder + boat_files[i], bpos, _rng.randf() * TAU, Vector3.ONE * 2.2, root)
		boats.append(b)
	# 등대
	var lh := WorldShape.lighthouse
	_place(PIRATE + "tower-complete-large.glb", lh, 0.0, Vector3(2.0, 2.2, 2.0), root)
	# 갯벌의 난파선
	var wreck := WorldShape.bay + Vector3(-60, 0, 40)
	wreck.y = WorldShape.ground(wreck.x, wreck.z) - 1.5
	_place(PIRATE + "ship-wreck.glb", wreck, 0.7, Vector3.ONE * 2.4, root)
	# 부표
	for i in 6:
		var bp := Vector3(cx + 160.0 + i * 70.0, 0.0, dz - 220.0 + _rng.randf_range(-40, 40))
		var bu := _place(BOATS + "buoy.glb", bp + Vector3(0, -0.2, 0), 0.0, Vector3.ONE * 2.0, root)
		boats.append(bu)


func bob_boats(t: float) -> void:
	for i in boats.size():
		var b := boats[i]
		b.position.y = sin(t * 1.1 + i * 1.7) * 0.25 - 0.1
		b.rotation.z = sin(t * 0.9 + i) * 0.04
		b.rotation.x = sin(t * 0.7 + i * 2.0) * 0.03


# ---------- 식생 ----------

const NATURAL := {
	"leafsDark": Color(0.17, 0.33, 0.21),
	"leafsGreen": Color(0.3, 0.47, 0.2),
	"grass": Color(0.32, 0.46, 0.22),
	"woodBark": Color(0.38, 0.27, 0.18),
	"woodBarkDark": Color(0.3, 0.21, 0.15),
	"woodBirch": Color(0.78, 0.75, 0.68),
	"leafsFall": Color(0.82, 0.47, 0.16),
}


## Kenney 파스텔 색을 사실적인 톤으로 바꾼다(공유 머티리얼이라 한 번만 바꾸면 된다).
static func naturalize(mesh: Mesh) -> void:
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i) as StandardMaterial3D
		if mat and NATURAL.has(mat.resource_name) and not mat.has_meta("natural"):
			mat.albedo_color = NATURAL[mat.resource_name]
			mat.roughness = 0.9
			mat.set_meta("natural", true)


func _mm(parts: Array, xforms: Array, cast: bool = true) -> MultiMeshInstance3D:
	var mesh: Mesh = parts[0][0]
	naturalize(mesh)
	var base: Transform3D = parts[0][1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * base)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 2200.0
	add_child(mmi)
	return mmi


func _build_vegetation() -> void:
	var pines := ["tree_pineTallA.glb", "tree_pineTallB.glb", "tree_pineRoundA.glb", "tree_pineRoundC.glb", "tree_pineDefaultA.glb"]
	var decid := [["tree_default.glb", "tree_default_fall.glb"], ["tree_oak.glb", "tree_oak_fall.glb"], ["tree_detailed.glb", "tree_detailed_fall.glb"]]
	var bushes := ["plant_bush.glb", "plant_bushLarge.glb", "plant_bushDetailed.glb", "grass_large.glb"]
	var rocks := ["rock_largeA.glb", "rock_largeB.glb", "rock_largeD.glb", "rock_tallE.glb", "stone_largeC.glb"]
	var pine_x := {}
	var dec_x := {}
	var bush_x := {}
	var rock_x := {}
	for p in pines:
		pine_x[p] = []
	for d in decid:
		dec_x[d[0]] = []
	for b in bushes:
		bush_x[b] = []
	for r in rocks:
		rock_x[r] = []
	var step := 13.0
	var lim := WorldShape.HALF + 350.0
	var v := WorldShape.village
	var z := -lim
	while z < lim:
		var x := -lim
		while x < lim:
			var px := x + _rng.randf_range(-5, 5)
			var pz := z + _rng.randf_range(-5, 5)
			x += step
			var h := WorldShape.ground(px, pz)
			if h < 3.0:
				continue
			var n := WorldShape.normal(px, pz)
			var near_village := Vector2(px - v.x, pz - v.z).length() < 150.0
			var dens := _forest_noise.get_noise_2d(px, pz)
			var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(px, h - 0.3, pz))
			if n.y < 0.78:
				if n.y > 0.45 and _rng.randf() < 0.06:
					var rs := _rng.randf_range(3.0, 7.0)
					rock_x[rocks[_rng.randi() % rocks.size()]].append(xf.scaled_local(Vector3.ONE * rs))
				continue
			if near_village:
				if _rng.randf() < 0.04:
					var d = decid[_rng.randi() % decid.size()]
					dec_x[d[0]].append(xf.scaled_local(Vector3.ONE * _rng.randf_range(6.0, 8.0)))
				continue
			if dens > 0.08:
				var west := clampf((-px - 200.0) / 700.0, 0.0, 1.0) + h / 250.0
				if _rng.randf() < west:
					var pf: String = pines[_rng.randi() % pines.size()]
					pine_x[pf].append(xf.scaled_local(Vector3.ONE * _rng.randf_range(7.0, 11.0)))
				else:
					var d2 = decid[_rng.randi() % decid.size()]
					dec_x[d2[0]].append(xf.scaled_local(Vector3.ONE * _rng.randf_range(6.5, 9.5)))
			elif dens > -0.12:
				if _rng.randf() < 0.25:
					var bf: String = bushes[_rng.randi() % bushes.size()]
					bush_x[bf].append(xf.scaled_local(Vector3.ONE * _rng.randf_range(3.0, 6.0)))
			elif _rng.randf() < 0.012:
				rock_x[rocks[_rng.randi() % rocks.size()]].append(xf.scaled_local(Vector3.ONE * _rng.randf_range(2.5, 5.0)))
		z += step
	for p in pines:
		if pine_x[p].size() > 0:
			_mm(glb_parts(NATURE + p), pine_x[p])
	for d in decid:
		if dec_x[d[0]].size() > 0:
			var green := glb_parts(NATURE + d[0])
			var fall := glb_parts(NATURE + d[1])
			naturalize(fall[0][0])
			var mmi := _mm(green, dec_x[d[0]])
			deciduous.append({"mm": mmi, "green": green[0][0], "fall": fall[0][0]})
	for b in bushes:
		if bush_x[b].size() > 0:
			_mm(glb_parts(NATURE + b), bush_x[b], false)
	for r in rocks:
		if rock_x[r].size() > 0:
			var mmi := _mm(glb_parts(NATURE + r), rock_x[r])
			mmi.material_override = rock_mat


func set_season(season: int) -> void:
	var autumn := season == 2 or season == 3
	for d in deciduous:
		(d.mm as MultiMeshInstance3D).multimesh.mesh = d.fall if autumn else d.green
	terrain_mat.set_shader_parameter("autumn", 1.0 if season == 2 else (0.6 if season == 3 else 0.0))
	terrain_mat.set_shader_parameter("summer", 1.0 if season == 1 else 0.0)


func set_snow(amount: float) -> void:
	terrain_mat.set_shader_parameter("snow_amount", amount)
	rock_mat.set_shader_parameter("snow_amount", amount)


func set_wet(amount: float) -> void:
	terrain_mat.set_shader_parameter("wet", amount)


# ---------- 상승기류 ----------

func _build_thermals() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/thermal.gdshader")
	for t in WorldShape.thermals:
		var cm := CylinderMesh.new()
		cm.top_radius = t.r * 1.15
		cm.bottom_radius = t.r * 0.8
		cm.height = 520.0
		cm.radial_segments = 20
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = (t.pos as Vector3) + Vector3(0, 260.0, 0)
		add_child(mi)
		thermal_cols.append(mi)


func set_thermal_strength(k: float) -> void:
	for mi in thermal_cols:
		(mi.material_override as ShaderMaterial).set_shader_parameter("strength", k * thermal_boost)


## 튜토리얼에서 상승기류 기둥을 잘 보이게 한다
func set_thermal_boost(k: float) -> void:
	thermal_boost = k


# ---------- 구름 ----------

func _build_clouds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 1.0
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.58, 0.62)
	mat.emission_energy_multiplier = 0.35
	var sm := SphereMesh.new()
	sm.radial_segments = 10
	sm.rings = 6
	sm.material = mat
	for i in 26:
		var c := Vector3(_rng.randf_range(-1300, 1300), _rng.randf_range(300, 520), _rng.randf_range(-1300, 1300))
		var root := Node3D.new()
		root.position = c
		add_child(root)
		var r := _rng.randf_range(30.0, 60.0)
		for k in _rng.randi_range(4, 7):
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			var rr := r * _rng.randf_range(0.5, 1.0)
			mi.scale = Vector3(rr, rr * 0.6, rr)
			mi.position = Vector3(_rng.randf_range(-r, r), _rng.randf_range(-r * 0.15, r * 0.2), _rng.randf_range(-r * 0.7, r * 0.7))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		clouds.append({"pos": c, "r": r * 1.3, "node": root})


## 카메라가 구름 속이면 0..1
func cloud_density_at(p: Vector3) -> float:
	var best := 0.0
	for c in clouds:
		var d := (p - (c.pos as Vector3)) * Vector3(1.0, 1.7, 1.0)
		var k := 1.0 - d.length() / (c.r as float)
		best = maxf(best, k)
	return clampf(best * 2.0, 0.0, 1.0)
