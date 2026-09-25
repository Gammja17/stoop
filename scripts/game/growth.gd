class_name Growth
extends RefCounted
## 성장: 경험 → 레벨 → 성장 포인트로 능력 강화. 혈통(세이브)을 따라 이어진다.
## 깃털 색은 레벨·퀘스트로 해금되고 모든 삶에 걸쳐 남는다(Records).

const SKILLS := ["dive", "wing", "stamina", "eye"]
const MAX_RANK := 5
const PLUMAGES := ["default", "silver", "rufous", "dark", "white"]
const PLUMAGE_LEVEL := {"default": 1, "silver": 3, "rufous": 5, "dark": 8}   # white는 해동청 퀘스트


static func xp_needed(level: int) -> int:
	return 100 + 60 * (level - 1)


static func g() -> Dictionary:
	if not GameState.data.has("growth"):
		GameState.data["growth"] = {"level": 1, "xp": 0, "points": 0, "skills": {"dive": 0, "wing": 0, "stamina": 0, "eye": 0}, "plumage": "default"}
	return GameState.data["growth"]


static func level() -> int:
	return int(g().get("level", 1))


static func rank(id: String) -> int:
	return int((g().skills as Dictionary).get(id, 0))


## 경험을 더하고 오른 레벨 수를 돌려준다
static func add_xp(n: int) -> int:
	var d := g()
	d["xp"] = int(d.xp) + n
	var ups := 0
	while int(d.xp) >= xp_needed(int(d.level)):
		d["xp"] = int(d.xp) - xp_needed(int(d.level))
		d["level"] = int(d.level) + 1
		d["points"] = int(d.points) + 1
		ups += 1
		for pl in PLUMAGE_LEVEL:
			if int(d.level) >= int(PLUMAGE_LEVEL[pl]):
				Records.unlock_plumage(pl)
	return ups


static func can_spend(id: String) -> bool:
	return int(g().points) > 0 and rank(id) < MAX_RANK


static func spend(id: String) -> bool:
	if not can_spend(id):
		return false
	var d := g()
	d["points"] = int(d.points) - 1
	(d.skills as Dictionary)[id] = rank(id) + 1
	return true


## 매 모델 이름과 추가 크기 (암컷은 1.14배)
static func falcon_spec() -> Array:
	var female: bool = GameState.falcon().get("sex", "m") == "f"
	var pl: String = g().get("plumage", "default")
	if pl == "default" or not Records.has_plumage(pl):
		return ["falcon_f" if female else "falcon", 1.0]
	return ["pl_" + pl, 1.14 if female else 1.0]
