class_name Balance
extends RefCounted
## 全局数值常量（初版，参见 docs/design.md 第 4 节）。调数值只改这里。

# --- 时间 ---
const XUN_PER_YEAR := 12
const XUN_PER_SEASON := 3

# --- 属性 ---
const STAT_MIN := 1
const STAT_MAX := 100

## 资质：出生时确定，决定成长速度与上限
const APTITUDES: Array[StringName] = [&"gengu", &"wuxing", &"shenfa", &"danshi", &"xinxing"]
## 可成长属性：内力、外功、轻功、医术、谋略、口才
const STATS: Array[StringName] = [&"neili", &"waigong", &"qinggong", &"yishu", &"moulue", &"kouca"]
## 每项属性的上限受哪项资质影响
const STAT_APTITUDE := {
	&"neili": &"gengu",
	&"waigong": &"gengu",
	&"qinggong": &"shenfa",
	&"yishu": &"wuxing",
	&"moulue": &"wuxing",
	&"kouca": &"danshi",
}

const TRAITS: Array[StringName] = [
	&"孤傲", &"重义", &"贪财", &"好胜", &"胆小", &"沉稳", &"好学", &"圆滑",
]

# --- 新弟子生成 ---
const APTITUDE_MEAN := 35.0
const APTITUDE_DEV := 12.0
const POTENTIAL_MEAN := 60.0
const POTENTIAL_DEV := 15.0
const POTENTIAL_MIN := 20
const INITIAL_STAT_RATIO := 0.7  ## 初始属性约为对应资质的 70%
const INITIAL_STAT_DEV := 5.0
const RECRUIT_AGE_MIN := 12
const RECRUIT_AGE_MAX := 18

# --- 修炼 ---
const BASE_XP := 10.0
const XP_THRESHOLD_BASE := 20.0
const XP_THRESHOLD_PER_STAT := 1.0   ## 升级所需经验 = BASE + PER_STAT × 当前属性
const CAP_APTITUDE_FLOOR := 0.7      ## 属性上限 = 潜力 × (FLOOR + (1-FLOOR) × 对应资质/100)
const ERRATIC_MIN := 0.6
const ERRATIC_MAX := 1.4
const NEILI_AGE_FLOOR := 0.8         ## 内力在衰退期的成长倍率下限
const DECLINE_AGE := 40.0

# --- 体力 ---
const STAMINA_MAX := 100
const TRAIN_STAMINA_COST := 20
const REST_STAMINA_GAIN := 35
const LOW_STAMINA := 30
const LOW_STAMINA_EFFICIENCY := 0.5
