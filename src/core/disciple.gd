class_name Disciple
extends RefCounted
## 弟子。三块数据：
##   技能 skills     —— 直接决定武功威力，可成长
##   属性 attributes —— 先天为主，决定学习效果与职位表现
##   状态 生命/内力/体力/心情/忠诚/威望 —— 随时间与事件变化
## 成长规则见 Growth。

## 成长曲线：早慧 / 晚成 / 稳健 / 起伏
enum GrowthCurve { PRECOCIOUS, LATE, STEADY, ERRATIC }

var id: int = 0
var display_name: String = ""

var skills: Dictionary = {}      ## StringName -> int（剑法、刀法、棍法、拳掌、内功、轻功、医术、毒功）
var attributes: Dictionary = {}  ## StringName -> int（悟性、根骨、身法、智谋、魅力、领导力、定力、亲和）
var xp: Dictionary = {}          ## StringName -> float，各技能已累积、尚未升级的经验

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
	for a in Balance.ATTRIBUTES:
		attributes[a] = 50
	for s in Balance.SKILLS:
		skills[s] = Balance.STAT_MIN
		xp[s] = 0.0


func age_years() -> float:
	return float(age_xun) / Balance.XUN_PER_YEAR
