extends SceneTree
func _init() -> void:
	for f in ["tree_pineTallA", "tree_default", "tree_oak", "tree_detailed", "tree_pineRoundA", "plant_bush", "tree_default_fall"]:
		var parts := WorldBuilder.glb_parts("res://assets/models/nature/%s.glb" % f)
		for p in parts:
			var m: Mesh = p[0]
			for i in m.get_surface_count():
				var mat = m.surface_get_material(i)
				print(f, " surf", i, " ", mat.resource_name if mat else "-", " ", mat.albedo_color if mat is StandardMaterial3D else "")
	quit()
