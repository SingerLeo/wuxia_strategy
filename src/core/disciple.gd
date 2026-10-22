class_name Disciple
extends RefCounted
## 弟子。数值 stats 分三类（各 8 项，清单见 Balance）：
##   武学 MARTIAL  —— 招式功夫，靠修炼与实战提升
##   基本功 BASICS —— 内外功底子，靠修炼提升（根骨例外：先天，只在少年期自然长）
##   心智 MIND     —— 不能修炼，只随年龄与阅历增长
## 另有状态：生命/内力/体力/心情/忠诚/威望，随时间与事件变化。
## 成长规则见 Growth。

## 成长曲线：早慧 / 晚成 / 稳健 / 起伏
enum GrowthCurve { PRECOCIOUS, LATE, STEADY, ERRATIC }

var id: int = 0
var display_name: String = ""

var stats: Dictionary = {}   ## StringName -> int（1~100），武学 + 基本功 + 心智共 24 项
var innate: Dictionary = {}  ## StringName -> int，根骨与心智的先天上限（隐藏）；年龄增长只长到这里，阅历可抬高它
var xp: Dictionary = {}      ## StringName -> float，可修炼项目已累积、尚未升级的经验

var potential: int = 50
var curve: GrowthCurve = GrowthCurve.STEADY
var age_xun: int = 0
var traits: Array[StringName] = []

# --- 状态 ---
var hp: int = 100
var neili: int = 0
var stamina: int = Balance.STAMINA_MAX  ## 修炼疲劳，休息恢复
var mood: int = 70                      ## 心情
var loyalty: int = 60                   ## 忠诚度
var prestige: int = 0                   ## 个人威望


func _init() -> void:
	for k in Balance.MARTIAL:
		stats[k] = Balance.STAT_MIN
	for k in Balance.BASICS + Balance.MIND:
		stats[k] = 50
	for k in Balance.MATURING:
		innate[k] = 50
	for k in Balance.TRAINABLE:
		xp[k] = 0.0


func age_years() -> float:
	return float(age_xun) / Balance.XUN_PER_YEAR


## 序列化：StringName 键转成 String 以进 JSON。读取用 from_dict。
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"potential": potential,
		"curve": int(curve),
		"age_xun": age_xun,
		"stats": _stringify_keys(stats),
		"innate": _stringify_keys(innate),
		"xp": _stringify_keys(xp),
		"traits": traits.map(func(t: StringName) -> String: return String(t)),
		"hp": hp,
		"neili": neili,
		"stamina": stamina,
		"mood": mood,
		"loyalty": loyalty,
		"prestige": prestige,
	}


static func from_dict(data: Dictionary) -> Disciple:
	var d := Disciple.new()
	d.id = int(data["id"])
	d.display_name = data["name"]
	d.potential = int(data["potential"])
	d.curve = int(data["curve"]) as GrowthCurve
	d.age_xun = int(data["age_xun"])
	for k in data["stats"]:
		d.stats[StringName(k)] = int(data["stats"][k])
	for k in data["innate"]:
		d.innate[StringName(k)] = int(data["innate"][k])
	for k in data["xp"]:
		d.xp[StringName(k)] = float(data["xp"][k])
	d.traits.clear()
	for t in data["traits"]:
		d.traits.append(StringName(t))
	d.hp = int(data["hp"])
	d.neili = int(data["neili"])
	d.stamina = int(data["stamina"])
	d.mood = int(data["mood"])
	d.loyalty = int(data["loyalty"])
	d.prestige = int(data["prestige"])
	return d


static func _stringify_keys(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[String(k)] = dict[k]
	return out
