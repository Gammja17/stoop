extends Node
## 개발용: 타이틀 화면과 새 모델 색을 찍는다. godot --path . -- --titletest
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/T01_title.png"))
	get_tree().quit()
