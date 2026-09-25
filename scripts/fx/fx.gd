class_name Fx
extends RefCounted
## 일회성 파티클/이펙트 생성기. 깃털 폭발, 충격파 고리, 물보라, 흙먼지.

static var _feather_draw: QuadMesh
static var _ring_mesh: TorusMesh
static var _splash_draw: QuadMesh
static var _dust_draw: QuadMesh
static var _shell_draw: QuadMesh


static func _auto_free(node: Node, after: float) -> void:
	node.get_tree().create_timer(after, true, false, false).timeout.connect(node.queue_free)


static func feathers(parent: Node, pos: Vector3, dir: Vector3, a: Color, b: Color, amount: int, power: float) -> void:
	if _feather_draw == null:
		_feather_draw = QuadMesh.new()
		_feather_draw.size = Vector2(0.06, 0.15)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		_feather_draw.material = m
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 3.0 * power
	pm.initial_velocity_max = 13.0 * power
	pm.gravity = Vector3(0, -1.6, 0)
	pm.damping_min = 3.0
	pm.damping_max = 7.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -420.0
	pm.angular_velocity_max = 420.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 2.0
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _feather_draw
	p.amount = amount
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.96
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -30, -20), Vector3(40, 50, 40))
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 6.0)


## 알껍데기 조각: 작고 딱딱해서 금방 떨어진다
static func shell(parent: Node, pos: Vector3, col: Color, amount: int, power: float) -> void:
	if _shell_draw == null:
		_shell_draw = QuadMesh.new()
		_shell_draw.size = Vector2(0.018, 0.012)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		_shell_draw.material = m
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.4 * power
	pm.initial_velocity_max = 1.6 * power
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -600.0
	pm.angular_velocity_max = 600.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.color = col
	p.process_material = pm
	p.draw_pass_1 = _shell_draw
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 1.5)


static func ring(parent: Node, pos: Vector3, normal: Vector3, size: float, col: Color) -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.9
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var x := n.cross(Vector3.UP)
	if x.length() < 0.1:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(n).normalized()
	mi.global_basis = Basis(x, n, z).scaled(Vector3.ONE * 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_method(func(s: float): mi.global_basis = Basis(x, n, z).scaled(Vector3(s, 0.25 * s, s)), 0.3, size, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	_auto_free(mi, 1.0)


static func splash(parent: Node, pos: Vector3, size: float) -> void:
	if _splash_draw == null:
		_splash_draw = QuadMesh.new()
		_splash_draw.size = Vector2(0.3, 0.3)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_splash_draw.material = m
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.6 * size
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 28.0
	pm.initial_velocity_min = 5.0 * size
	pm.initial_velocity_max = 13.0 * size
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 0.8 * size
	pm.scale_max = 2.2 * size
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.98, 1.0, 0.9))
	g.set_color(1, Color(0.8, 0.9, 0.95, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _splash_draw
	p.amount = int(40 * size) + 10
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 3.0)
	ring(parent, pos + Vector3.UP * 0.05, Vector3.UP, 2.5 * size, Color(0.8, 0.9, 1.0, 0.7))


static func dust(parent: Node, pos: Vector3) -> void:
	if _dust_draw == null:
		_dust_draw = QuadMesh.new()
		_dust_draw.size = Vector2(0.6, 0.6)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_draw.material = m
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 1.0
	pm.scale_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.47, 0.38, 0.7))
	g.set_color(1, Color(0.55, 0.47, 0.38, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _dust_draw
	p.amount = 30
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 3.0)
