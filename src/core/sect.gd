class_name Sect
extends RefCounted
## 门派：弟子名册与回合（旬）推进。

var sect_name: String
var xun: int = 0
## 三大资源，见 docs/resources.md
var silver: int = 0         ## 银两：购置产业、升级建筑、弟子供奉
var prestige: int = 0       ## 威望：外交、招收弟子；可涨可跌，用 change_prestige 修改
var prestige_peak: int = 0  ## 历史最高威望：只增不减，决定可接任务等级
var legacy: int = 0         ## 底蕴：解锁技能树（发展 / 策略 / 武功）
var honor: int = 0          ## 荣耀值：支线任务等长期成就，只是成绩，不是可花费资源，见 docs/scope.md
var disciples: Array[Disciple] = []
var rng: RandomNumberGenerator


func _init(p_name: String, p_rng: RandomNumberGenerator) -> void:
	sect_name = p_name
	rng = p_rng


func add_disciple(d: Disciple) -> void:
	disciples.append(d)


## 门派是否灭亡。目前只有一条规则：没有任何弟子。
## 以后增删条件（掌门身亡、山门失守等）只改这里，见 docs/scope.md §4。
func is_destroyed() -> bool:
	return disciples.is_empty()


## 增减威望（不会低于 0），并同步历史最高威望
func change_prestige(delta: int) -> void:
	prestige = maxi(0, prestige + delta)
	prestige_peak = maxi(prestige_peak, prestige)


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


## 推进一旬。plans: 弟子 id -> TrainingPlan，未安排的弟子默认休息。
## 返回每名弟子的结算报告：[{id, report}, ...]
func advance_xun(plans: Dictionary = {}) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for d in disciples:
		var plan: TrainingPlan = plans.get(d.id, null)
		reports.append({"id": d.id, "report": Growth.settle_xun(d, plan, rng)})
	xun += 1
	return reports


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
	for dd in data["disciples"]:
		s.disciples.append(Disciple.from_dict(dd))
	return s
