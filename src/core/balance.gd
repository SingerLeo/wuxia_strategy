class_name Balance
extends RefCounted
## 全局数值常量（初版，参见 docs/design.md 第 4 节）。调数值只改这里。

# --- 时间 ---
const XUN_PER_YEAR := 12
const XUN_PER_SEASON := 3

# --- 数值范围（技能、属性通用） ---
const STAT_MIN := 1
const STAT_MAX := 100

## 属性类：悟性、根骨、身法、智谋、魅力、领导力、定力、亲和。
## 出生时确定，决定学习效果、技能成长速度与上限，以及门派职位表现。
const ATTRIBUTES: Array[StringName] = [
	&"wuxing", &"gengu", &"shenfa", &"zhimou", &"meili", &"lingdao", &"dingli", &"qinhe",
]
## 技能类：直接决定武功威力，可通过修炼武学、实战提升。
const SKILLS: Array[StringName] = [
	&"jian", &"dao", &"gun", &"quan", &"neigong", &"qinggong", &"yishu", &"dugong",
]
## 每项技能主要受哪项属性影响（成长速度与上限）。悟性对所有技能都有影响。
const SKILL_ATTRIBUTE := {
	&"jian": &"shenfa",
	&"dao": &"gengu",
	&"gun": &"gengu",
	&"quan": &"gengu",
	&"neigong": &"gengu",
	&"qinggong": &"shenfa",
	&"yishu": &"zhimou",
	&"dugong": &"zhimou",
}

const TRAITS: Array[StringName] = [
	&"孤傲", &"重义", &"贪财", &"好胜", &"胆小", &"沉稳", &"好学", &"圆滑",
]

# --- 状态：最大值（占位公式，战斗做出来后再调） ---
const HP_BASE := 60
const HP_PER_GENGU := 0.8
const NEILI_BASE := 20
const NEILI_PER_SKILL := 2.0   ## 内力上限 = BASE + PER_SKILL × 内功等级

# --- 新弟子生成 ---
const ATTRIBUTE_MEAN := 35.0
const ATTRIBUTE_DEV := 12.0
const POTENTIAL_MEAN := 60.0
const POTENTIAL_DEV := 15.0
const POTENTIAL_MIN := 20
const STARTER_SKILLS := 2            ## 每名新弟子有几项"入门所学"
const INITIAL_MAJOR_RATIO := 0.7     ## 入门所学 ≈ 对应属性的 70%
const INITIAL_MINOR_RATIO := 0.2     ## 其他技能 ≈ 对应属性的 20%
const INITIAL_SKILL_DEV := 4.0
const RECRUIT_AGE_MIN := 12
const RECRUIT_AGE_MAX := 18

# --- 修炼 ---
# 数值锚点：潜力/悟性/对应属性全 100 的早慧型天才（12 岁起练），在体力循环
# （约 64% 出勤）下 10 年（120 旬）把一项技能从 1 练到 100，见
# tests/unit/test_growth.gd 的天才基准测试。调 BASE_XP / 门槛时请重跑该测试。
const BASE_XP := 20.0
const XP_THRESHOLD_BASE := 10.0
const XP_THRESHOLD_PER_STAT := 0.55   ## 升级所需经验 = BASE + PER_STAT × 当前技能等级（1→100 共需 3712.5）
const CAP_ATTRIBUTE_FLOOR := 0.7     ## 技能上限 = 潜力 × (FLOOR + (1-FLOOR) × 对应属性/100)
const RELATED_COEF_BASE := 0.7       ## 对应属性对成长速度的系数 = BASE + SPAN × 属性/100
const RELATED_COEF_SPAN := 0.6       ## （属性 50 时为 1.0）
const ERRATIC_MIN := 0.6
const ERRATIC_MAX := 1.4
const NEIGONG_AGE_FLOOR := 0.8       ## 内功在衰退期的成长倍率下限
const DECLINE_AGE := 40.0

# --- 体力（修炼疲劳） ---
const STAMINA_MAX := 100
const TRAIN_STAMINA_COST := 20
const REST_STAMINA_GAIN := 35
const LOW_STAMINA := 30
const LOW_STAMINA_EFFICIENCY := 0.5
