class_name Dimensions
extends RefCounted
## 六维雷达：由技能与属性合成，用于弟子详情的雷达图。
## 以后要改维度，只改 DEFS：
##   max_of：取列出项目中的最大值
##   mix：加权求和（权重之和为 1），键可以是技能也可以是属性

const DEFS: Array[Dictionary] = [
	{"id": &"gongfa", "name": "功法", "max_of": [&"jian", &"dao", &"gun", &"quan", &"yishu", &"dugong"]},
	{"id": &"neigong", "name": "内功", "mix": {&"neigong": 0.5, &"dingli": 0.5}},
	{"id": &"qinggong", "name": "轻功", "mix": {&"qinggong": 0.5, &"shenfa": 0.5}},
	{"id": &"tipo", "name": "体魄", "mix": {&"gengu": 1.0}},
	{"id": &"conghui", "name": "聪慧", "mix": {&"zhimou": 1.0}},
	{"id": &"tongyu", "name": "统御", "mix": {&"lingdao": 0.5, &"qinhe": 0.5}},
]


## 技能或属性的当前值（1~100）
static func value_of(d: Disciple, key: StringName) -> int:
	if d.skills.has(key):
		return d.skills[key]
	return d.attributes[key]


## 返回每一维的 {id, name, value}，value 范围 1~100（浮点）
static func compute(d: Disciple) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def in DEFS:
		var v := 0.0
		if def.has("max_of"):
			for key in def["max_of"]:
				v = maxf(v, value_of(d, key))
		else:
			var mix: Dictionary = def["mix"]
			for key in mix:
				v += value_of(d, key) * float(mix[key])
		out.append({"id": def["id"], "name": def["name"], "value": v})
	return out
