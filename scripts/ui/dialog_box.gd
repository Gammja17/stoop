extends Control
## 프롤로그 대화창: 말하는 이, 한 자씩 나오는 대사, 현재 목표, 넘기기 안내.

signal advanced

const CHARS_PER_SEC := 38.0

@onready var name_l: Label = $Panel/VBox/Name
@onready var text_l: Label = $Panel/VBox/Text
@onready var goal_l: Label = $Panel/VBox/Bottom/Goal
@onready var next_l: Label = $Panel/VBox/Bottom/Next
@onready var progress: ProgressBar = $Panel/VBox/Progress

var waiting := false
var _shown := 0.0
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## 대사를 띄운다. wait=true면 클릭/스페이스/E로 넘길 때까지 advanced를 기다릴 수 있다.
func say(speaker: String, text: String, wait: bool = false) -> void:
	visible = true
	name_l.text = speaker
	name_l.visible = speaker != ""
	text_l.text = text
	text_l.visible_characters = 0
	_shown = 0.0
	waiting = wait
	next_l.text = Loc.t("pro_next") if wait else ""
	Sfx.play("pluck", -14.0, 1.4)


func set_goal(text: String) -> void:
	goal_l.text = ("◆ " + text) if text != "" else ""


func set_progress(v: float, show: bool = true) -> void:
	progress.visible = show
	progress.value = v


func close() -> void:
	visible = false
	waiting = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var total := text_l.get_total_character_count()
	if text_l.visible_characters < total:
		_shown += delta * CHARS_PER_SEC
		text_l.visible_characters = int(_shown)
	elif waiting:
		next_l.modulate.a = 0.5 + 0.5 * absf(sin(_t * 4.0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not waiting:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("interact") or event.is_action_pressed("tuck") or event.is_action_pressed("ui_accept")
	if not press:
		return
	get_viewport().set_input_as_handled()
	# 글자가 다 나오기 전이면 먼저 전부 보여준다
	if text_l.visible_characters < text_l.get_total_character_count():
		text_l.visible_characters = -1
		_shown = 9999.0
		return
	waiting = false
	next_l.text = ""
	Sfx.play("ui_click", -10.0)
	advanced.emit()
