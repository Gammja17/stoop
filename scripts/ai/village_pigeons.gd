class_name VillagePigeons
extends Node3D
## 마을 광장에서 걸어 다니는 비둘기(Quaternius 모델). 매가 다가오면 날아올라 사냥감 떼가 된다.

const MODEL := "res://assets/models/birds/pigeon.glb"
const COUNT := 9

var birds: Array = []   # {node, anim, dir, t}
var scared := false
var _respawn_t := 0.0
var center := Vector3.ZERO


func setup(c: Vector3) -> void:
	center = c
	_spawn()


func _spawn() -> void:
	scared = false
	var ps: PackedScene = load(MODEL)
	for i in COUNT:
		var n: Node3D = ps.instantiate()
		var p := center + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		p.y = WorldShape.ground(p.x, p.z)
		n.position = p
		n.scale = Vector3.ONE * 0.17
		add_child(n)
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		var d := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		birds.append({"node": n, "anim": ap, "dir": d, "t": randf_range(0.5, 3.0), "walk": false})
		_set_anim(birds[-1], "CharacterArmature|Idle")


func _set_anim(b: Dictionary, name: String) -> void:
	var ap: AnimationPlayer = b.anim
	if ap and ap.has_animation(name):
		var a := ap.get_animation(name)
		a.loop_mode = Animation.LOOP_LINEAR
		ap.play(name, 0.2)


func _process(delta: float) -> void:
	var m = get_tree().get_first_node_in_group("main")
	if m == null:
		return
	if scared:
		_respawn_t -= delta
		if _respawn_t <= 0.0 and m.falcon.global_position.distance_to(center) > 300.0:
			_spawn()
		return
	for b in birds:
		b.t -= delta
		if b.t <= 0.0:
			b.t = randf_range(1.0, 3.5)
			var r := randf()
			if r < 0.45:
				b.walk = true
				b.dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				_set_anim(b, "CharacterArmature|Walk")
			elif r < 0.75:
				b.walk = false
				_set_anim(b, "CharacterArmature|Bite_Front")
			else:
				b.walk = false
				_set_anim(b, "CharacterArmature|Idle")
		var n: Node3D = b.node
		if b.walk:
			var np: Vector3 = n.position + b.dir * 0.6 * delta
			if np.distance_to(center) > 14.0:
				b.dir = (center - n.position).normalized()
			np.y = WorldShape.ground(np.x, np.z)
			n.position = np
			n.basis = Basis.looking_at(-b.dir, Vector3.UP).scaled(Vector3.ONE * 0.17)
	var f: Falcon = m.falcon
	if f and f.global_position.distance_to(center) < 70.0 and f.state != Falcon.State.FROZEN:
		scare(m)


func scare(m) -> void:
	scared = true
	_respawn_t = 120.0
	var positions := []
	for b in birds:
		positions.append((b.node as Node3D).global_position)
		(b.node as Node3D).queue_free()
	birds.clear()
	Sfx.play_at("flap", center, 4.0, 1.2, 300.0)
	m.prey_mgr.spawn_from_ground(positions, center)
