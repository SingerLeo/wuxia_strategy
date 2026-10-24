class_name Economy
extends RefCounted
## 银两的收支与建筑效果的计算。纯函数，只读门派数据，不改状态（结算在 Sect.advance_xun）。


# --- 收入 / 支出（每旬） ---

static func estate_income(s: Sect) -> int:
	var total := 0
	for id in s.estates:
		if Catalog.ESTATES.has(id):
			total += int(s.estates[id]) * int(Catalog.ESTATES[id]["income"])
	return total


static func disciple_upkeep(s: Sect) -> int:
	var base := s.disciples.size() * Catalog.DISCIPLE_UPKEEP
	return roundi(base * (1.0 - kitchen_cut(s)))


## 伙房带来的养育费减免比例（0~0.9）
static func kitchen_cut(s: Sect) -> float:
	return minf(0.9, Catalog.KITCHEN_UPKEEP_CUT_PER_LEVEL * s.building_level(&"kitchen") * SectMap.factor(s, &"kitchen"))


static func building_upkeep(s: Sect) -> int:
	var total := 0
	for id in s.buildings:
		var level: int = s.buildings[id]
		if level > 0 and Catalog.BUILDINGS.has(id):
			total += int(Catalog.BUILDINGS[id]["upkeep"][level - 1])
	return total


static func net_per_xun(s: Sect) -> int:
	return estate_income(s) - disciple_upkeep(s) - building_upkeep(s)


## 按当前收支，银两还能撑几旬；收支为正则返回 -1（不会耗尽）
static func runway(s: Sect) -> int:
	var net := net_per_xun(s)
	if net >= 0:
		return -1
	return s.silver / (-net)


# --- 建筑 ---

static func building_max_level(id: StringName) -> int:
	return (Catalog.BUILDINGS[id]["costs"] as Array).size()


## 从 level 级升到下一级的花费；已满级返回 -1
static func next_building_cost(id: StringName, level: int) -> int:
	var costs: Array = Catalog.BUILDINGS[id]["costs"]
	return -1 if level >= costs.size() else int(costs[level])


# --- 建筑带来的效果 ---

## 建筑当前效果的一句话说明（已含位置倍率）；未建返回 ""
static func effect_text(s: Sect, id: StringName) -> String:
	var level := s.building_level(id)
	if level <= 0:
		return ""
	var f := SectMap.factor(s, id)
	match id:
		&"dojo": return "弟子修炼经验 +%d%%" % roundi(Catalog.DOJO_XP_PER_LEVEL * level * f * 100.0)
		&"clinic": return "休息多恢复 %d 点体力" % rest_bonus(s)
		&"library": return "底蕴产出 +%d%%" % roundi(Catalog.LIBRARY_LEGACY_PER_LEVEL * level * f * 100.0)
		&"kitchen": return "养育费 -%d%%" % roundi(kitchen_cut(s) * 100.0)
	return ""


# 每座建筑的效果 = 每级效果 × 等级 × 位置倍率（SectMap.factor，邻接规则）

static func training_mult(s: Sect) -> float:
	return 1.0 + Catalog.DOJO_XP_PER_LEVEL * s.building_level(&"dojo") * SectMap.factor(s, &"dojo")


static func rest_bonus(s: Sect) -> int:
	return roundi(Catalog.CLINIC_REST_PER_LEVEL * s.building_level(&"clinic") * SectMap.factor(s, &"clinic"))


static func legacy_mult(s: Sect) -> float:
	return 1.0 + Catalog.LIBRARY_LEGACY_PER_LEVEL * s.building_level(&"library") * SectMap.factor(s, &"library")
