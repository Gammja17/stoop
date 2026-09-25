extends Node
## 한 번의 "삶(혈통)" 데이터와 저장/불러오기.

signal notify(text: String, kind: String)
signal stats_changed

const SAVE_PATH := "user://stoop_save.json"
const SAVE_VERSION := 1

const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_DAYS := [3, 4, 3, 2]

var data: Dictionary = {}
var in_game := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func new_game(falcon_name: String, sex: String, difficulty: String) -> void:
	data = {
		"version": SAVE_VERSION,
		"difficulty": difficulty,
		"generation": 1,
		"lineage": [],
		"falcon": _make_falcon(falcon_name, sex, {}),
		"year": 1,
		"season": 0,
		"day": 1,
		"time": 6.5,
		"weather": "clear",
		"life": _fresh_life(),
		"stats": _fresh_stats(),
		"prologue": -1,
	}
	in_game = true


func _make_falcon(falcon_name: String, sex: String, bonus: Dictionary) -> Dictionary:
	return {
		"name": falcon_name,
		"sex": sex,
		"age": 1,
		"lifespan": randi_range(5, 8),
		"health": 100.0,
		"energy": 75.0,
		"bonus_speed": bonus.get("speed", 0.0),
		"bonus_agility": bonus.get("agility", 0.0),
		"bonus_stamina": bonus.get("stamina", 0.0),
	}


func _fresh_life() -> Dictionary:
	return {
		"territory": false,
		"rival_hits": 0,
		"mate": {"has": false, "bond": 0.0, "name": "", "shown_eyrie": false},
		"eggs": 0,
		"incubation_food": 0,
		"nest_food": 0.0,
		"chicks": [],
		"fledglings": [],
		"offspring": [],
		"flags": {},
	}


func _fresh_stats() -> Dictionary:
	return {
		"prey_total": 0,
		"prey": {},
		"top_speed": 0.0,
		"perfect": 0,
		"crashes": 0,
		"days": 0,
		"fledged": 0,
		"year_prey": 0,
	}


# ---------- 편의 접근자 ----------

func falcon() -> Dictionary:
	return data.get("falcon", {})


func life() -> Dictionary:
	return data.get("life", {})


func stats() -> Dictionary:
	return data.get("stats", {})


func season_id() -> String:
	return SEASONS[int(data.get("season", 0))]


func season_days() -> int:
	return SEASON_DAYS[int(data.get("season", 0))]


func flag(key: String) -> bool:
	return bool(life().get("flags", {}).get(key, false))


func set_flag(key: String, v: bool = true) -> void:
	life()["flags"][key] = v


func is_male() -> bool:
	return falcon().get("sex", "m") == "m"


func record_prey(kind: String) -> void:
	var s := stats()
	s["prey_total"] = int(s.get("prey_total", 0)) + 1
	s["year_prey"] = int(s.get("year_prey", 0)) + 1
	var p: Dictionary = s["prey"]
	p[kind] = int(p.get(kind, 0)) + 1
	stats_changed.emit()


func record_speed(kmh: float) -> void:
	var s := stats()
	if kmh > float(s.get("top_speed", 0.0)):
		s["top_speed"] = kmh


func say(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


# ---------- 세대 ----------

## 현재 개체가 죽었을 때 혈통 기록에 남긴다.
func archive_current(cause: String) -> void:
	var f := falcon()
	data["lineage"].append({
		"name": f.get("name", "?"),
		"sex": f.get("sex", "m"),
		"gen": data.get("generation", 1),
		"age": f.get("age", 1),
		"prey": stats().get("prey_total", 0),
		"fledged": stats().get("fledged", 0),
		"cause": cause,
	})


func living_offspring() -> Array:
	var out := []
	for o in life().get("offspring", []):
		if o.get("alive", true):
			out.append(o)
	return out


## 자식 중 하나로 다음 세대를 이어간다.
func continue_as(offspring: Dictionary) -> void:
	var skill := float(offspring.get("skill", 0))
	var bonus := {
		"speed": 0.02 * skill + randf_range(0.0, 0.03),
		"agility": 0.03 * skill + randf_range(0.0, 0.03),
		"stamina": 4.0 * skill + randf_range(0.0, 4.0),
	}
	data["generation"] = int(data.get("generation", 1)) + 1
	data["falcon"] = _make_falcon(offspring.get("name", "매"), offspring.get("sex", "m"), bonus)
	var old_offspring: Array = life().get("offspring", [])
	var siblings := []
	for o in old_offspring:
		if o != offspring and o.get("alive", true):
			siblings.append(o)
	data["life"] = _fresh_life()
	data["life"]["siblings"] = siblings
	data["year"] = int(data.get("year", 1)) + 1
	data["season"] = 0
	data["day"] = 1
	data["time"] = 6.5
	var total_prey := int(stats().get("prey_total", 0))
	data["stats"] = _fresh_stats()
	data["stats"]["lineage_prey"] = total_prey


# ---------- 저장 ----------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if data.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	data = parsed
	# JSON은 정수를 float로 읽으므로 핵심 정수 필드를 되돌린다.
	for k in ["generation", "year", "season", "day", "prologue"]:
		data[k] = int(data.get(k, 0))
	in_game = true
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
