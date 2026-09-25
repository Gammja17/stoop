extends SceneTree
# Prints AABB size and animation names for imported models. Dev tool only.

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		box = b
		first = false
	for c in n.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			if first:
				box = cb
				first = false
			else:
				box = box.merge(cb)
	return box

func _init() -> void:
	var dirs := ["res://assets/models/birds", "res://assets/models/nature", "res://assets/models/pirate", "res://assets/models/boats"]
	for d in dirs:
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".glb"):
				continue
			var ps: PackedScene = load(d + "/" + f)
			var inst := ps.instantiate()
			var box := _aabb(inst, Transform3D.IDENTITY)
			var anims := ""
			var ap := inst.find_child("AnimationPlayer", true, false)
			if ap:
				anims = str((ap as AnimationPlayer).get_animation_list())
			print("%s  size=%s  pos=%s %s" % [f, box.size.snapped(Vector3.ONE * 0.01), box.position.snapped(Vector3.ONE * 0.01), anims])
			inst.free()
	quit()
