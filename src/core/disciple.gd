class_name Disciple
extends RefCounted
## 弟子：资质、属性、状态与性格。纯数据，成长规则见 Growth。

## 成长曲线：早慧 / 晚成 / 稳健 / 起伏
enum GrowthCurve { PRECOCIOUS, LATE, STEADY, ERRATIC }

var id: int = 0
var display_name: String = ""
var aptitudes: Dictionary = {}  ## StringName -> int（根骨、悟性、身法、胆识、心性）
var stats: Dictionary = {}      ## StringName -> int（内力、外功、轻功、医术、谋略、口才）
var xp: Dictionary = {}         ## StringName -> float，各属性已累积、尚未升级的经验
var potential: int = 50
var curve: GrowthCurve = GrowthCurve.STEADY
var age_xun: int = 0
var stamina: int = Balance.STAMINA_MAX
var morale: int = 70
var loyalty: int = 60
var injury: int = 0
var traits: Array[StringName] = []


func _init() -> void:
	for a in Balance.APTITUDES:
		aptitudes[a] = 50
	for s in Balance.STATS:
		stats[s] = Balance.STAT_MIN
		xp[s] = 0.0


func age_years() -> float:
	return float(age_xun) / Balance.XUN_PER_YEAR
