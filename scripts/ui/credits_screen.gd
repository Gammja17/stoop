extends Control

var menus

const CREDITS := """STOOP

— 3D 모델 / 3D Models —
Kenney — Nature Kit, Pirate Kit, Watercraft Pack (CC0) · kenney.nl
Quaternius — Pigeon (CC0) · quaternius.com, via poly.pizza

— 텍스처 / Textures —
Poly Haven — aerial_grass_rock, rock_face_03, coast_sand_01, brown_mud_02, snow_field_aerial (CC0) · polyhaven.com

— 효과음 / Sound Effects —
Kenney — Impact Sounds, Interface Sounds (CC0)
새 울음, 바람, 타격음 일부는 코드로 합성 / Bird calls, wind and some impacts are synthesized in code

— 음악 / Music (OpenGameArt, CC0) —
"Contemplation" · "Aurora"
Sea ambience: "Sea and river wave sounds" (CC0)

— 글꼴 / Fonts (SIL Open Font License) —
Black Han Sans · Nanum Gothic

— 엔진 / Engine —
Godot Engine (MIT)
"""


func _ready() -> void:
	$Center/Panel/VBox/Back.pressed.connect(func(): menus.back())


func open() -> void:
	visible = true
	$Center/Panel/VBox/Title.text = Loc.t("t_credits")
	$Center/Panel/VBox/Back.text = Loc.t("back")
	$Center/Panel/VBox/Scroll/Text.text = CREDITS
	$Center/Panel/VBox/Back.grab_focus()
