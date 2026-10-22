class_name Schedule
extends RefCounted
## 训练日程：每旬 Training.SLOTS 份时间分给各科目，外加一个强度。
## 没分出去的时间算作休整：经验少拿，体力也少耗。

var id: int = 0
var schedule_name: String = ""
var slots: Dictionary = {}   ## 科目 -> 份数（>0 才存）
var intensity: int = Training.Intensity.NORMAL


func _init(p_id: int = 0, p_name: String = "") -> void:
	id = p_id
	schedule_name = p_name


func slots_of(focus: StringName) -> int:
	return int(slots.get(focus, 0))


func used_slots() -> int:
	var total := 0
	for f in slots:
		total += slots[f]
	return total


## 设置某科目的份数。总数不能超过 Training.SLOTS，超出部分会被截掉。返回实际设置的份数。
func set_slots(focus: StringName, n: int) -> int:
	if not Training.FOCUS_WEIGHTS.has(focus):
		return 0
	var room := Training.SLOTS - (used_slots() - slots_of(focus))
	var v := clampi(n, 0, room)
	if v > 0:
		slots[focus] = v
	else:
		slots.erase(focus)
	return v


## 本旬用于修炼的时间比例（0~1）
func time_used() -> float:
	return float(used_slots()) / Training.SLOTS


## 每个数值项分到的时间比例：Σ(科目份数 / SLOTS × 权重 × 科目倍率)。
## focus_mult：科目 -> 倍率（教习加成），缺省为 1。
func allocation(focus_mult: Dictionary = {}) -> Dictionary:
	var out := {}
	for f in slots:
		var share := float(slots[f]) / Training.SLOTS * float(focus_mult.get(f, 1.0))
		var weights: Dictionary = Training.FOCUS_WEIGHTS[f]
		for stat in weights:
			out[stat] = float(out.get(stat, 0.0)) + share * weights[stat]
	return out


func to_dict() -> Dictionary:
	var s := {}
	for f in slots:
		s[String(f)] = slots[f]
	return {"id": id, "name": schedule_name, "intensity": intensity, "slots": s}


static func from_dict(data: Dictionary) -> Schedule:
	var s := Schedule.new(int(data["id"]), data["name"])
	s.intensity = int(data["intensity"])
	for f in data["slots"]:
		s.set_slots(StringName(f), int(data["slots"][f]))
	return s
