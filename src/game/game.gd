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
const REST := -1                     ## 日程 id：休息
## 训练日程（开局为 Training.PRESETS，玩家可改、可删、可新建）
var schedules: Array[Schedule] = []
## 弟子 id -> 日程 id；不在表内或为 REST 表示休息
var plans: Dictionary = {}
var _next_schedule_id: int = 0
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
	schedules = Training.preset_schedules()
	_next_schedule_id = schedules.size()
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


## 弟子本旬的日程 id；REST 表示休息
func schedule_of(id: int) -> int:
	var sid: int = plans.get(id, REST)
	return sid if find_schedule(sid) != null else REST


## 给弟子指派日程；sid 为 REST 表示休息
func assign(id: int, sid: int) -> void:
	plans[id] = sid
	state_changed.emit()


## 批量安排：全部休息
func rest_all() -> void:
	for d in sect.disciples:
		plans[d.id] = REST
	state_changed.emit()


## 批量安排：体力足够的弟子按专长指派日程（给专长分配时间最多的那个），其余休息
func train_all_by_specialty() -> void:
	for d in sect.disciples:
		plans[d.id] = specialty_schedule(d) if d.stamina >= AUTO_TRAIN_MIN_STAMINA else REST
	state_changed.emit()


## 最适合弟子专长的日程：给其最高武学分配时间比例最大的日程；没有日程则休息
func specialty_schedule(d: Disciple) -> int:
	var top := UiText.top_skill(d)
	var best := REST
	var best_share := -1.0
	for s in schedules:
		var share: float = s.allocation().get(top, 0.0)
		if share > best_share:
			best_share = share
			best = s.id
	return best


# --- 训练日程 ---

func find_schedule(sid: int) -> Schedule:
	for s in schedules:
		if s.id == sid:
			return s
	return null


## 新建一个空日程
func add_schedule(schedule_name: String = "") -> Schedule:
	var s := Schedule.new(_next_schedule_id, schedule_name if schedule_name != "" else "新日程%d" % (_next_schedule_id + 1))
	_next_schedule_id += 1
	schedules.append(s)
	state_changed.emit()
	return s


## 删除日程；指派了它的弟子改为休息
func remove_schedule(sid: int) -> void:
	var s := find_schedule(sid)
	if s == null:
		return
	schedules.erase(s)
	for id in plans:
		if plans[id] == sid:
			plans[id] = REST
	state_changed.emit()


func rename_schedule(sid: int, schedule_name: String) -> void:
	var s := find_schedule(sid)
	if s != null and schedule_name.strip_edges() != "":
		s.schedule_name = schedule_name.strip_edges()
		state_changed.emit()


## 设置日程里某科目的份数（总数不超过 Training.SLOTS），返回实际份数
func set_schedule_slots(sid: int, focus: StringName, n: int) -> int:
	var s := find_schedule(sid)
	if s == null:
		return 0
	var v := s.set_slots(focus, n)
	state_changed.emit()
	return v


func set_schedule_intensity(sid: int, intensity: int) -> void:
	var s := find_schedule(sid)
	if s != null:
		s.intensity = clampi(intensity, 0, Training.Intensity.size() - 1)
		state_changed.emit()


## 指派了某日程的弟子人数
func schedule_member_count(sid: int) -> int:
	var n := 0
	for d in sect.disciples:
		if schedule_of(d.id) == sid:
			n += 1
	return n


## 本旬提醒：提示玩家可能遗漏的安排
func reminders() -> Array[String]:
	var out: Array[String] = []
	var idle := 0
	var tired := 0
	for d in sect.disciples:
		if d.stamina < Balance.LOW_STAMINA:
			tired += 1
		if schedule_of(d.id) == REST and d.stamina >= IDLE_HEALTHY_STAMINA:
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
	var coach := Training.coach_mults(sect)
	for d in sect.disciples:
		training[d.id] = TrainingPlan.from_schedule(find_schedule(schedule_of(d.id)), coach)
	var reports := sect.advance_xun(training)
	for r in reports:
		var gains: Dictionary = r["report"]["gains"]
		if not gains.is_empty():
			var d := find_disciple(r["id"])
			var parts: Array[String] = []
			for stat in gains:
				parts.append("%s +%d（%d）" % [UiText.STAT[stat], gains[stat], d.stats[stat]])
			log_added.emit("%s 修炼有成：%s。" % [d.display_name, "、".join(parts)])
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
	schedules.clear()
	for sd in state["schedules"]:
		schedules.append(Schedule.from_dict(sd))
	_next_schedule_id = int(state["next_schedule_id"])
	plans.clear()
	for key in state["plans"]:
		plans[int(key)] = int(state["plans"][key])
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
		plans_str[str(id)] = plans[id]
	return {
		"sect": sect.to_dict(),
		"schedules": schedules.map(func(s: Schedule) -> Dictionary: return s.to_dict()),
		"next_schedule_id": _next_schedule_id,
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
