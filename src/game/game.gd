extends Node
## 全局游戏状态（autoload 名称：Game）。UI 只读取这里的数据，并通过这里的方法修改。

signal state_changed
signal log_added(text: String)
signal game_over

const INITIAL_DISCIPLES := 12
const AUTO_TRAIN_MIN_STAMINA := 40   ## 批量修炼时，体力低于此值的弟子改为休息
const IDLE_HEALTHY_STAMINA := 70     ## 休息中且体力不低于此值，视为"闲着"
const LOW_RUNWAY_XUN := 12           ## 银两只够撑这么多旬以内时提醒

var sect: Sect
## 门派已灭亡，本局结束；结束后不再推进回合，直到 new_game
var over: bool = false
## 弟子 id -> 本旬修炼的项目（武学或基本功）；不在表内或为 &"" 表示休息
var plans: Dictionary = {}
## 本季山门候选人（未招收）；每季刷新
var candidates: Array[Disciple] = []
var saver := SaveSystem.new()
var _next_id: int = 0


func _ready() -> void:
	if sect == null:
		new_game()


func new_game(seed_value: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	sect = Sect.new("青云门", rng)
	sect.silver = Catalog.START_SILVER
	for id in Catalog.START_ESTATES:
		sect.estates[id] = Catalog.START_ESTATES[id]
	plans.clear()
	over = false
	for i in INITIAL_DISCIPLES:
		sect.add_disciple(DiscipleFactory.create(rng, i, NameGen.person(rng)))
	_next_id = INITIAL_DISCIPLES
	_refresh_candidates()
	state_changed.emit()


func find_disciple(id: int) -> Disciple:
	for d in sect.disciples:
		if d.id == id:
			return d
	return null


func plan_of(id: int) -> StringName:
	return plans.get(id, &"")


## stat 为 &"" 表示休息
func set_plan(id: int, stat: StringName) -> void:
	plans[id] = stat
	state_changed.emit()


## 批量安排：全部休息
func rest_all() -> void:
	for d in sect.disciples:
		plans[d.id] = &""
	state_changed.emit()


## 批量安排：体力足够的弟子修炼各自当前最高的武学，其余休息
func train_all_by_specialty() -> void:
	for d in sect.disciples:
		plans[d.id] = UiText.top_skill(d) if d.stamina >= AUTO_TRAIN_MIN_STAMINA else &""
	state_changed.emit()


## 本旬提醒：提示玩家可能遗漏的安排
func reminders() -> Array[String]:
	var out: Array[String] = []
	var idle := 0
	var tired := 0
	for d in sect.disciples:
		if d.stamina < Balance.LOW_STAMINA:
			tired += 1
		if plan_of(d.id) == &"" and d.stamina >= IDLE_HEALTHY_STAMINA:
			idle += 1
	if idle > 0:
		out.append("%d 名体力充沛的弟子本旬尚未安排修炼。" % idle)
	if tired > 0:
		out.append("%d 名弟子体力不足，修炼效率减半，建议休息。" % tired)
	var runway := Economy.runway(sect)
	if runway >= 0 and runway <= LOW_RUNWAY_XUN:
		out.append("每旬入不敷出（%+d），银两只够撑 %d 旬。" % [Economy.net_per_xun(sect), runway])
	return out


func end_xun() -> void:
	if over:
		return
	var training := {}
	for id in plans:
		var stat: StringName = plans[id]
		training[id] = TrainingPlan.train(stat) if stat != &"" else TrainingPlan.resting()
	var reports := sect.advance_xun(training)
	for r in reports:
		var levels: int = r["report"]["levels"]
		if levels > 0:
			var d := find_disciple(r["id"])
			var stat: StringName = plans[d.id]
			log_added.emit("%s 的%s提升了 %d 级，现为 %d。" % [d.display_name, UiText.STAT[stat], levels, d.stats[stat]])
	log_added.emit("—— %s ——" % UiText.date_text(sect))
	_log_settlement()
	if sect.xun % Balance.XUN_PER_SEASON == 0:
		_refresh_candidates()
		log_added.emit("新的一季，山门外来了 %d 名求师者。" % candidates.size())
	_check_destroyed()
	saver.save(SaveSystem.AUTOSAVE, _build_state())  # 每旬自动存档
	state_changed.emit()


func _log_settlement() -> void:
	var st := sect.last_settlement
	var upkeep: int = st["upkeep_disciples"] + st["upkeep_buildings"]
	var line := "本旬收入 %d，支出 %d（养育 %d、维护 %d）" % [st["income"], upkeep, st["upkeep_disciples"], st["upkeep_buildings"]]
	if st["legacy_gain"] > 0:
		line += "，底蕴 +%d" % st["legacy_gain"]
	log_added.emit(line + "。")
	if st["shortfall"] > 0:
		log_added.emit("银两不足，缺口 %d 两未能付清！" % st["shortfall"])


# --- 产业与建筑 ---

## 购置产业：扣银两，增加一处。已达上限或银两不足返回 false。
func buy_estate(id: StringName) -> bool:
	if not Catalog.ESTATES.has(id):
		return false
	var info: Dictionary = Catalog.ESTATES[id]
	if sect.estate_count(id) >= int(info["max"]) or sect.silver < int(info["price"]):
		return false
	sect.silver -= int(info["price"])
	sect.estates[id] = sect.estate_count(id) + 1
	log_added.emit("花费 %d 两购置%s，每旬 +%d 两。" % [info["price"], info["name"], info["income"]])
	state_changed.emit()
	return true


## 升级建筑一级（未建则建到 1 级）。已满级或银两不足返回 false。
func upgrade_building(id: StringName) -> bool:
	if not Catalog.BUILDINGS.has(id):
		return false
	var level := sect.building_level(id)
	var cost := Economy.next_building_cost(id, level)
	if cost < 0 or sect.silver < cost:
		return false
	sect.silver -= cost
	sect.buildings[id] = level + 1
	log_added.emit("花费 %d 两，%s升到 %d 级。" % [cost, Catalog.BUILDINGS[id]["name"], level + 1])
	state_changed.emit()
	return true


# --- 存档 / 读档（H 类，多槽位） ---

## 存入指定槽位（0..SLOT_COUNT-1），写日志；每旬的自动存档走 AUTOSAVE 槽不打扰日志
func save_to_slot(index: int) -> bool:
	var ok := saver.save(index, _build_state())
	log_added.emit("已存入存档 %d。" % [index + 1] if ok else "存档失败。")
	state_changed.emit()
	return ok


## 读取槽位（手动槽或 SaveSystem.AUTOSAVE）。无档、损坏或版本不符返回 false，当前局面不受影响。
func load_from_slot(index: int) -> bool:
	var state := saver.load_state(index)
	if state.is_empty():
		return false
	sect = Sect.from_dict(state["sect"])
	plans.clear()
	for key in state["plans"]:
		plans[int(key)] = StringName(state["plans"][key])
	candidates.clear()
	for cd in state["candidates"]:
		candidates.append(Disciple.from_dict(cd))
	_next_id = int(state["next_id"])
	over = bool(state["over"])
	log_added.emit("已读取存档。")
	state_changed.emit()
	return true


func has_save(index: int = 0) -> bool:
	return saver.has_save(index)


## 所有槽位的摘要（自动存档在第一位），供存档界面展示
func slot_infos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(saver.info(SaveSystem.AUTOSAVE))
	for i in SaveSystem.SLOT_COUNT:
		out.append(saver.info(i))
	return out


func _build_state() -> Dictionary:
	var plans_str := {}
	for id in plans:
		plans_str[str(id)] = String(plans[id])
	return {
		"sect": sect.to_dict(),
		"plans": plans_str,
		"candidates": candidates.map(func(c: Disciple) -> Dictionary: return c.to_dict()),
		"next_id": _next_id,
		"over": over,
	}


## 招收候选人：扣银两、入门册。银两不足返回 false。
func recruit(id: int) -> bool:
	var c := _find_candidate(id)
	if c == null:
		return false
	var price := Recruitment.asking_price(c)
	if sect.silver < price:
		return false
	sect.silver -= price
	candidates.erase(c)
	sect.add_disciple(c)
	log_added.emit("花费 %d 两收 %s 入门。" % [price, c.display_name])
	state_changed.emit()
	return true


## 婉拒候选人：从本季候选中移除
func decline(id: int) -> void:
	var c := _find_candidate(id)
	if c == null:
		return
	candidates.erase(c)
	log_added.emit("婉拒了 %s。" % c.display_name)
	state_changed.emit()


func _find_candidate(id: int) -> Disciple:
	for c in candidates:
		if c.id == id:
			return c
	return null


func _refresh_candidates() -> void:
	candidates = Recruitment.generate(sect.rng, sect.prestige, _next_id)
	_next_id += candidates.size()


## 调试用：遣散全部弟子，用来查看灭亡界面（界面里按 F9）
func debug_disband_all() -> void:
	if over:
		return
	sect.disciples.clear()
	plans.clear()
	_check_destroyed()
	state_changed.emit()


func _check_destroyed() -> void:
	if not over and sect.is_destroyed():
		over = true
		log_added.emit("门派覆灭，再无弟子。")
		game_over.emit()
