class_name Training
extends RefCounted
## 训练科目与强度（见 docs/design.md §3.1「训练」）。
## 科目：每个科目训练一组固定的武学/基本功，经验按权重分到各项。心智不能修炼，不进科目。
## 日程（Schedule）：把每旬 SLOTS 份时间分给各科目，并选一个强度。

const SLOTS := 20   ## 每旬可分配的时间份数

enum Intensity { LIGHT, NORMAL, HEAVY }
## 强度对修炼经验与体力消耗的倍率，下标对应 Intensity
const INTENSITY_XP: Array[float] = [0.75, 1.0, 1.25]
const INTENSITY_STAMINA: Array[float] = [0.6, 1.0, 1.5]

## 科目顺序即界面顺序
const FOCI: Array[StringName] = [
	&"jianshu", &"daoqiang", &"quanshu", &"anqishu", &"dazuo", &"qingshen", &"waijia", &"yidu",
]
## 科目 -> {数值项: 权重}，每个科目的权重之和为 1
const FOCUS_WEIGHTS := {
	&"jianshu": {&"jian": 0.6, &"shenfa": 0.25, &"fanying": 0.15},
	&"daoqiang": {&"dao": 0.35, &"qianggun": 0.35, &"yinggong": 0.3},
	&"quanshu": {&"quanjiao": 0.5, &"zhizhua": 0.25, &"yinggong": 0.25},
	&"anqishu": {&"anqi": 0.6, &"fanying": 0.4},
	&"dazuo": {&"neigong": 0.7, &"ruangong": 0.3},
	&"qingshen": {&"qinggong": 0.5, &"shenfa": 0.3, &"fanying": 0.2},
	&"waijia": {&"yinggong": 0.4, &"naili": 0.4, &"ruangong": 0.2},
	&"yidu": {&"yishu": 0.5, &"dushu": 0.5},
}

## 开局自带的日程（玩家可改、可删、可新建）
const PRESETS: Array[Dictionary] = [
	{"name": "剑客", "intensity": Intensity.NORMAL, "slots": {&"jianshu": 10, &"qingshen": 6, &"dazuo": 4}},
	{"name": "刀枪", "intensity": Intensity.NORMAL, "slots": {&"daoqiang": 10, &"waijia": 6, &"dazuo": 4}},
	{"name": "拳师", "intensity": Intensity.NORMAL, "slots": {&"quanshu": 10, &"waijia": 6, &"dazuo": 4}},
	{"name": "暗器", "intensity": Intensity.NORMAL, "slots": {&"anqishu": 10, &"qingshen": 6, &"dazuo": 4}},
	{"name": "内家", "intensity": Intensity.NORMAL, "slots": {&"dazuo": 12, &"qingshen": 8}},
	{"name": "医者", "intensity": Intensity.LIGHT, "slots": {&"yidu": 12, &"dazuo": 8}},
	{"name": "打基础", "intensity": Intensity.NORMAL, "slots": {&"waijia": 6, &"qingshen": 6, &"dazuo": 6, &"quanshu": 2}},
]


## 开局日程，id 从 0 开始
static func preset_schedules() -> Array[Schedule]:
	var out: Array[Schedule] = []
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var s := Schedule.new(i, p["name"])
		s.intensity = p["intensity"]
		for f in p["slots"]:
			s.set_slots(f, p["slots"][f])
		out.append(s)
	return out


## 科目的指导加成（教习）。教习等长老/阶位系统做出来后接入，目前恒为 1。
## 返回 {科目: 倍率}，交给 TrainingPlan.from_schedule。
static func coach_mults(_sect: Sect) -> Dictionary:
	return {}
