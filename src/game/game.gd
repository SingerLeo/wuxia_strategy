extends Node
## 全局游戏状态（autoload 名称：Game）。UI 只读取这里的数据，并通过这里的方法修改。

signal state_changed
signal log_added(text: String)
signal game_over

const INITIAL_DISCIPLES := 12
const AUTO_TRAIN_MIN_STAMINA := 40   ## 批量修炼时，体力低于此值的弟子改为休息
const IDLE_HEALTHY_STAMINA := 70     ## 休息中且体力不低于此值，视为"闲着"

var sect: Sect
## 门派已灭亡，本局结束；结束后不再推进回合，直到 new_game
var over: bool = false
## 弟子 id -> 本旬修炼的技能；不在表内或为 &"" 表示休息
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
	sect.silver = 1000
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


## 批量安排：体力足够的弟子修炼各自当前最高的技能，其余休息
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
			log_added.emit("%s 的%s提升了 %d 级，现为 %d。" % [d.display_name, UiText.SKILL[stat], levels, d.skills[stat]])
	log_added.emit("—— %s ——" % UiText.date_text(sect))
	if sect.xun % Balance.XUN_PER_SEASON == 0:
		_refresh_candidates()
		log_added.emit("新的一季，山门外来了 %d 名求师者。" % candidates.size())
	_check_destroyed()
	saver.save(_build_state())  # 每旬自动存档
	state_changed.emit()


# --- 存档 / 读档（H 类） ---

## 手动存档（Esc 菜单），写日志；每旬的自动存档走 saver.save 不打扰日志
func save_game() -> bool:
	var ok := saver.save(_build_state())
	log_added.emit("已存档。" if ok else "存档失败。")
	state_changed.emit()
	return ok


## 读取存档。无档、损坏或版本不符返回 false，当前局面不受影响。
func load_game() -> bool:
	var state := saver.load_state()
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


func has_save() -> bool:
	return saver.has_save()


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
