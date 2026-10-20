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
	return s.disciples.size() * Catalog.DISCIPLE_UPKEEP


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

static func training_mult(s: Sect) -> float:
	return 1.0 + Catalog.DOJO_XP_PER_LEVEL * s.building_level(&"dojo")


static func rest_bonus(s: Sect) -> int:
	return Catalog.CLINIC_REST_PER_LEVEL * s.building_level(&"clinic")


static func legacy_mult(s: Sect) -> float:
	return 1.0 + Catalog.LIBRARY_LEGACY_PER_LEVEL * s.building_level(&"library")
