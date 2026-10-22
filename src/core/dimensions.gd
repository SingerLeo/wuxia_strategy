class_name Dimensions
extends RefCounted
## 六维雷达：由武学、基本功、心智合成，用于弟子详情的雷达图。
## 以后要改维度，只改 DEFS：
##   max_of：取列出项目中的最大值
##   mix：加权求和（权重之和为 1），键可以是任意数值项

const DEFS: Array[Dictionary] = [
	{"id": &"wugong", "name": "武功", "max_of": [&"jian", &"dao", &"qianggun", &"quanjiao", &"zhizhua", &"anqi"]},
	{"id": &"neigong", "name": "内功", "mix": {&"neigong": 0.6, &"dingli": 0.4}},
	{"id": &"qingling", "name": "轻灵", "mix": {&"qinggong": 0.4, &"shenfa": 0.4, &"fanying": 0.2}},
	{"id": &"tipo", "name": "体魄", "mix": {&"gengu": 0.3, &"yinggong": 0.3, &"ruangong": 0.2, &"naili": 0.2}},
	{"id": &"caizhi", "name": "才智", "mix": {&"wuxing": 0.4, &"zhimou": 0.4, &"qinmian": 0.2}},
	{"id": &"renwang", "name": "人望", "mix": {&"tongshuai": 0.4, &"meili": 0.3, &"letian": 0.3}},
]


## 某个数值项的当前值（1~100）
static func value_of(d: Disciple, key: StringName) -> int:
	return d.stats[key]


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
