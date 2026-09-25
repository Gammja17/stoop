extends Control

var menus

const ROWS := [
	["ctrl_mouse", "ctrl_mouse_d"],
	["ctrl_flap", "ctrl_flap_d"],
	["ctrl_tuck", "ctrl_tuck_d"],
	["ctrl_brake", "ctrl_brake_d"],
	["ctrl_roll", "ctrl_roll_d"],
	["ctrl_eye", "ctrl_eye_d"],
	["ctrl_land", "ctrl_land_d"],
	["ctrl_eat", "ctrl_eat_d"],
	["ctrl_drop", "ctrl_drop_d"],
	["ctrl_call", "ctrl_call_d"],
	["ctrl_map", "ctrl_map_d"],
	["ctrl_view", "ctrl_view_d"],
	["ctrl_growth", "ctrl_growth_d"],
	["ctrl_photo", "ctrl_photo_d"],
	["ctrl_pause", "ctrl_pause_d"],
	["ctrl_misc", "ctrl_misc_d"],
]


func _ready() -> void:
	$Center/Panel/VBox/Back.pressed.connect(func(): menus.back())


func open() -> void:
	visible = true
	var v := $Center/Panel/VBox
	v.get_node("Title").text = Loc.t("t_controls")
	v.get_node("Back").text = Loc.t("back")
	v.get_node("Tip").text = Loc.t("ctrl_tip")
	var g: GridContainer = v.get_node("Grid")
	for c in g.get_children():
		c.queue_free()
	for r in ROWS:
		var k := Label.new()
		k.text = Loc.t(r[0])
		k.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		g.add_child(k)
		var d := Label.new()
		d.text = Loc.t(r[1])
		g.add_child(d)
	v.get_node("Back").grab_focus()
