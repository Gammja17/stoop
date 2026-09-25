extends Control

var menus
var _t := 0.0


func open() -> void:
	$Center/Status.text = Loc.t("loading")


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	$Center/Status.modulate.a = 0.5 + 0.5 * absf(sin(_t * 2.0))
