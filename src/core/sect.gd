class_name Sect
extends RefCounted
## 门派：弟子名册与回合（旬）推进。

var sect_name: String
var xun: int = 0
var silver: int = 0
var prestige: int = 0  ## 声望：影响招生质量与外交
var honor: int = 0     ## 荣耀值：支线任务等长期成就，见 docs/scope.md
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
