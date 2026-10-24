class_name Sect
extends RefCounted
## 门派：弟子名册、资源、产业与建筑，以及回合（旬）推进与结算。

var sect_name: String
var xun: int = 0
## 三大资源，见 docs/resources.md
var silver: int = 0         ## 银两：购置产业、升级建筑；养育弟子与建筑维护要持续支出
var prestige: int = 0       ## 威望：外交、招收弟子；可涨可跌，用 change_prestige 修改
var prestige_peak: int = 0  ## 历史最高威望：只增不减，决定可接任务等级
var legacy: int = 0         ## 底蕴：解锁技能树（发展 / 策略 / 武功）
var honor: int = 0          ## 荣耀值：支线任务等长期成就的成绩，不是可花费资源。界面暂不显示，见 docs/scope.md
var estates: Dictionary = {}    ## StringName -> 已购数量，见 Catalog.ESTATES
var buildings: Dictionary = {}  ## StringName -> 等级，见 Catalog.BUILDINGS
## 建筑在山门地图上的位置：id -> {"x", "y", "rot"}，见 SectMap。未出现表示未摆放（效果照常，只是没有位置加成）。
var layout: Dictionary = {}
var disciples: Array[Disciple] = []
var rng: RandomNumberGenerator
## 最近一旬的结算：{income, upkeep_disciples, upkeep_buildings, shortfall, legacy_gain}
var last_settlement: Dictionary = {}


func _init(p_name: String, p_rng: RandomNumberGenerator) -> void:
	sect_name = p_name
	rng = p_rng


func add_disciple(d: Disciple) -> void:
	disciples.append(d)


func estate_count(id: StringName) -> int:
	return int(estates.get(id, 0))


func building_level(id: StringName) -> int:
	return int(buildings.get(id, 0))


## 门派是否灭亡。目前只有一条规则：没有任何弟子。
## 以后增删条件（掌门身亡、山门失守等）只改这里，见 docs/scope.md §4。
func is_destroyed() -> bool:
	return disciples.is_empty()


## 增减威望（不会低于 0），并同步历史最高威望。
## 获得威望（delta > 0）会按比例转化为底蕴；失去威望不扣底蕴。
func change_prestige(delta: int) -> void:
	prestige = maxi(0, prestige + delta)
	prestige_peak = maxi(prestige_peak, prestige)
	if delta > 0:
		legacy += roundi(delta * Catalog.LEGACY_PER_PRESTIGE * Economy.legacy_mult(self))


## 可接任务等级（从 1 开始）：由历史最高威望决定，所以威望下跌不会让已解锁的等级消失
func task_tier() -> int:
	var tier := 1
	for i in Balance.TASK_TIER_PRESTIGE.size():
		if prestige_peak >= Balance.TASK_TIER_PRESTIGE[i]:
			tier = i + 1
	return tier


func current_year() -> int:
	return xun / Balance.XUN_PER_YEAR


## 0..3：春夏秋冬
func current_season() -> int:
	return (xun % Balance.XUN_PER_YEAR) / Balance.XUN_PER_SEASON


## 推进一旬：弟子成长，再结算银两与底蕴。
## plans: 弟子 id -> TrainingPlan，未安排的弟子默认休息。
## 返回每名弟子的结算报告：[{id, report}, ...]；银两与底蕴的结算见 last_settlement。
func advance_xun(plans: Dictionary = {}) -> Array[Dictionary]:
	var training_mult := Economy.training_mult(self)
	var rest_bonus := Economy.rest_bonus(self)
	var reports: Array[Dictionary] = []
	var xp_total := 0.0
	for d in disciples:
		var plan: TrainingPlan = plans.get(d.id, null)
		var report := Growth.settle_xun(d, plan, rng, training_mult, rest_bonus)
		xp_total += report["xp"]
		reports.append({"id": d.id, "report": report})
	xun += 1
	last_settlement = _settle_economy(xp_total)
	return reports


## 收入 − 支出；银两不会为负，付不起的部分记为 shortfall（后果以后再定）。
## 底蕴 = 弟子本旬获得的技能经验 × 系数 × 藏经阁加成。
func _settle_economy(xp_total: float) -> Dictionary:
	var income := Economy.estate_income(self)
	var upkeep_d := Economy.disciple_upkeep(self)
	var upkeep_b := Economy.building_upkeep(self)
	var balance := silver + income - upkeep_d - upkeep_b
	silver = maxi(0, balance)
	var legacy_gain := roundi(xp_total * Catalog.LEGACY_PER_XP * Economy.legacy_mult(self))
	legacy += legacy_gain
	return {
		"income": income,
		"upkeep_disciples": upkeep_d,
		"upkeep_buildings": upkeep_b,
		"shortfall": maxi(0, -balance),
		"legacy_gain": legacy_gain,
	}


## 序列化。rng 的 seed/state 是 64 位整数，超出 JSON 双精度范围，按字符串存。
func to_dict() -> Dictionary:
	return {
		"name": sect_name,
		"xun": xun,
		"silver": silver,
		"prestige": prestige,
		"prestige_peak": prestige_peak,
		"legacy": legacy,
		"honor": honor,
		"estates": _stringify_keys(estates),
		"buildings": _stringify_keys(buildings),
		"layout": _stringify_keys(layout),
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
		"disciples": disciples.map(func(d: Disciple) -> Dictionary: return d.to_dict()),
	}


static func from_dict(data: Dictionary) -> Sect:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(data["rng_seed"]).to_int()
	rng.state = String(data["rng_state"]).to_int()
	var s := Sect.new(data["name"], rng)
	s.xun = int(data["xun"])
	s.silver = int(data["silver"])
	s.prestige = int(data["prestige"])
	# 新增字段给默认值，旧存档不必升版本号
	s.prestige_peak = maxi(int(data.get("prestige_peak", s.prestige)), s.prestige)
	s.legacy = int(data.get("legacy", 0))
	s.honor = int(data["honor"])
	for key in data.get("estates", {}):
		s.estates[StringName(key)] = int(data["estates"][key])
	for key in data.get("buildings", {}):
		s.buildings[StringName(key)] = int(data["buildings"][key])
	for key in data.get("layout", {}):
		var p: Dictionary = data["layout"][key]
		s.layout[StringName(key)] = {"x": int(p["x"]), "y": int(p["y"]), "rot": int(p["rot"])}
	for dd in data["disciples"]:
		s.disciples.append(Disciple.from_dict(dd))
	return s


static func _stringify_keys(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[String(k)] = dict[k]
	return out
