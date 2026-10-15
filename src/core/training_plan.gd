class_name TrainingPlan
extends RefCounted
## 一名弟子本旬的安排：修炼某项属性，或休息。

var focus: StringName = &""
var rest: bool = false
var method_mult: float = 1.0    ## 修炼方式系数
var master_mult: float = 1.0    ## 师父加成
var facility_mult: float = 1.0  ## 设施加成


static func train(stat: StringName, method: float = 1.0, master: float = 1.0, facility: float = 1.0) -> TrainingPlan:
	var p := TrainingPlan.new()
	p.focus = stat
	p.method_mult = method
	p.master_mult = master
	p.facility_mult = facility
	return p


static func resting() -> TrainingPlan:
	var p := TrainingPlan.new()
	p.rest = true
	return p
