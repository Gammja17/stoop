extends Node
func _ready() -> void:
	var main = get_parent()
	await get_tree().create_timer(4.0).timeout
	var total := 0
	for c in main.world.get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			var tris := 0
			for s in mm.mesh.get_surface_count():
				var arr := mm.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null else (arr[Mesh.ARRAY_VERTEX].size() / 3)
			total += tris * mm.instance_count
			print("[veg] %-24s inst=%5d tris=%4d total=%dk lods=%d" % [str(mm.mesh.resource_name if mm.mesh.resource_name != "" else c.name), mm.instance_count, tris, tris * mm.instance_count / 1000, 0])
	print("[veg] TOTAL %dk" % (total / 1000))
	get_tree().quit()
