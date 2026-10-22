class_name TrainingPlan
extends RefCounted
## 一名弟子本旬的安排：按比例修炼若干数值项，或休息。
## 通常由日程生成（from_schedule）；train 是"整旬只练一项"的简写，测试与模拟常用。

var alloc: Dictionary = {}      ## 数值项 -> 本旬分到的时间比例（只含可修炼项）
var time_used: float = 0.0      ## 用于修炼的时间比例（0~1），决定体力消耗
var rest: bool = false
var method_mult: float = 1.0    ## 修炼方式系数（日程强度）
var stamina_mult: float = 1.0   ## 体力消耗倍率（日程强度）
var master_mult: float = 1.0    ## 师父加成
var facility_mult: float = 1.0  ## 设施加成


## 整旬只练一项。不可修炼的项目（心智、根骨）视为休息。
static func train(stat: StringName, method: float = 1.0, master: float = 1.0, facility: float = 1.0) -> TrainingPlan:
	if not Balance.TRAINABLE.has(stat):
		return resting()
	var p := TrainingPlan.new()
	p.alloc = {stat: 1.0}
	p.time_used = 1.0
	p.method_mult = method
	p.master_mult = master
	p.facility_mult = facility
	return p


## 按日程修炼。focus_mult：科目 -> 倍率（教习加成，见 Training.coach_mults）。空日程视为休息。
static func from_schedule(s: Schedule, focus_mult: Dictionary = {}) -> TrainingPlan:
	if s == null or s.used_slots() == 0:
		return resting()
	var p := TrainingPlan.new()
	p.alloc = s.allocation(focus_mult)
	p.time_used = s.time_used()
	p.method_mult = Training.INTENSITY_XP[s.intensity]
	p.stamina_mult = Training.INTENSITY_STAMINA[s.intensity]
	return p


static func resting() -> TrainingPlan:
	var p := TrainingPlan.new()
	p.rest = true
	return p
