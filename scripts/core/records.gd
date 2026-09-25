extends Node
## 업적(기록). 저장 파일과 별개로 모든 삶에 걸쳐 남는다.

signal unlocked(id: String)

const PATH := "user://records.cfg"

# [id, 이름(ko), 이름(en), 설명(ko), 설명(en)]
const LIST := [
	["first_hunt", "첫 사냥", "First Kill", "처음으로 먹잇감을 잡는다", "Catch your first prey"],
	["air_catch", "공중 곡예", "Mid-air Catch", "떨어지는 먹잇감을 공중에서 낚아챈다", "Snatch falling prey in mid-air"],
	["speed_300", "300", "300", "급강하로 300 km/h를 넘긴다", "Exceed 300 km/h in a stoop"],
	["speed_350", "살아 있는 총알", "Living Bullet", "350 km/h를 넘긴다", "Exceed 350 km/h"],
	["perfect_1", "완벽한 일격", "Perfect Stoop", "250 km/h 이상으로 명중시킨다", "Strike at 250 km/h or more"],
	["perfect_10", "하늘의 사냥꾼", "Sky Hunter", "완벽한 일격 10회", "10 perfect stoops"],
	["duck", "큰 사냥감", "Big Game", "오리를 쓰러뜨린다", "Down a duck"],
	["all_prey", "가리지 않는 식성", "Wide Menu", "비둘기·찌르레기·도요새·오리를 모두 사냥한다", "Hunt pigeon, starling, sandpiper and duck"],
	["gull", "도둑 쫓기", "Thief Buster", "갈매기를 들이받아 쫓아낸다", "Ram a gull away"],
	["territory", "절벽의 주인", "Master of the Cliff", "침입자 매를 쫓아낸다", "Drive off an intruder"],
	["paired", "평생의 짝", "Pair Bond", "짝을 맺는다", "Find a mate"],
	["owl", "밤의 파수꾼", "Night Watch", "수리부엉이를 쫓아낸다", "Drive off an eagle-owl"],
	["fledged", "날개를 편 아이들", "Fledged", "새끼를 독립시킨다", "Raise young to independence"],
	["fledged_10", "대가족", "Big Family", "새끼 10마리를 독립시킨다 (모든 세대 합계)", "Raise 10 young across generations"],
	["gen3", "3대", "Three Generations", "3대째 혈통을 잇는다", "Reach the third generation"],
	["old_age", "천수", "Full Life", "늙어서 생을 마친다", "Die of old age"],
]

var _done := {}
var fledged_total := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for id in cf.get_section_keys("done") if cf.has_section("done") else []:
			_done[id] = true
		fledged_total = int(cf.get_value("stats", "fledged_total", 0))


func _save() -> void:
	var cf := ConfigFile.new()
	for id in _done:
		cf.set_value("done", id, true)
	cf.set_value("stats", "fledged_total", fledged_total)
	cf.save(PATH)


func has(id: String) -> bool:
	return _done.has(id)


func unlock(id: String) -> void:
	if _done.has(id):
		return
	_done[id] = true
	_save()
	unlocked.emit(id)
	GameState.say(Loc.t("record_unlocked") % title(id), "gold")
	Sfx.play("chime_big", -4.0, 1.2)


func add_fledged(n: int) -> void:
	fledged_total += n
	_save()
	if n > 0:
		unlock("fledged")
	if fledged_total >= 10:
		unlock("fledged_10")


func _entry(id: String) -> Array:
	for e in LIST:
		if e[0] == id:
			return e
	return [id, id, id, "", ""]


func title(id: String) -> String:
	var e := _entry(id)
	return e[1] if Loc.lang == "ko" else e[2]


func desc(id: String) -> String:
	var e := _entry(id)
	return e[3] if Loc.lang == "ko" else e[4]


func count() -> int:
	return _done.size()
