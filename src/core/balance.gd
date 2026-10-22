class_name Balance
extends RefCounted
## 全局数值常量（初版，参见 docs/design.md 第 4 节）。调数值只改这里。

# --- 时间 ---
const XUN_PER_YEAR := 12
const XUN_PER_SEASON := 3

# --- 数值范围（技能、属性通用） ---
const STAT_MIN := 1
const STAT_MAX := 100

## 弟子数值分三类，各 8 项，全部存在 Disciple.stats 里（见 docs/design.md §3.1）。
## 武学：剑法、刀法、枪棍、拳脚、指爪、暗器、医术、毒术。靠修炼与实战提升。
const MARTIAL: Array[StringName] = [
	&"jian", &"dao", &"qianggun", &"quanjiao", &"zhizhua", &"anqi", &"yishu", &"dushu",
]
## 基本功：内功、轻功、软功、硬功、根骨、耐力、身法、反应。除根骨外靠修炼提升。
const BASICS: Array[StringName] = [
	&"neigong", &"qinggong", &"ruangong", &"yinggong", &"gengu", &"naili", &"shenfa", &"fanying",
]
## 心智：悟性、定力、智谋、胆识、勤勉、魅力、统率、乐天。不能修炼，只随年龄与阅历增长。
const MIND: Array[StringName] = [
	&"wuxing", &"dingli", &"zhimou", &"danshi", &"qinmian", &"meili", &"tongshuai", &"letian",
]
## 可修炼的项目：全部武学 + 除根骨外的基本功
const TRAINABLE: Array[StringName] = [
	&"jian", &"dao", &"qianggun", &"quanjiao", &"zhizhua", &"anqi", &"yishu", &"dushu",
	&"neigong", &"qinggong", &"ruangong", &"yinggong", &"naili", &"shenfa", &"fanying",
]
## 随年龄自然增长、有先天上限的项目：根骨 + 全部心智
const MATURING: Array[StringName] = [
	&"gengu",
	&"wuxing", &"dingli", &"zhimou", &"danshi", &"qinmian", &"meili", &"tongshuai", &"letian",
]
## 每个可修炼项目的对应项（影响成长速度与上限）。悟性对所有修炼都有影响。
const RELATED := {
	&"jian": &"shenfa",
	&"dao": &"yinggong",
	&"qianggun": &"yinggong",
	&"quanjiao": &"yinggong",
	&"zhizhua": &"ruangong",
	&"anqi": &"fanying",
	&"yishu": &"zhimou",
	&"dushu": &"zhimou",
	&"neigong": &"dingli",
	&"qinggong": &"gengu",
	&"ruangong": &"gengu",
	&"yinggong": &"gengu",
	&"naili": &"gengu",
	&"shenfa": &"gengu",
	&"fanying": &"gengu",
}

const TRAITS: Array[StringName] = [
	&"孤傲", &"重义", &"贪财", &"好胜", &"胆小", &"沉稳", &"好学", &"圆滑",
]

# --- 状态：最大值（占位公式，战斗做出来后再调） ---
const HP_BASE := 60
const HP_PER_GENGU := 0.5
const HP_PER_YINGGONG := 0.3   ## 生命上限 = BASE + 根骨 × 0.5 + 硬功 × 0.3
const NEILI_BASE := 20
const NEILI_PER_SKILL := 2.0   ## 内力上限 = BASE + PER_SKILL × 内功等级

# --- 门派资源（银两 / 威望 / 底蕴，见 docs/resources.md） ---
## 可接任务等级所需的"历史最高威望"，下标 0 对应 1 级。占位数值，待任务系统做出来后再调。
const TASK_TIER_PRESTIGE: Array[int] = [0, 50, 150, 400, 1000]

# --- 新弟子生成 ---
const BASICS_MEAN := 35.0            ## 可修炼基本功的初始均值
const BASICS_DEV := 12.0
const INNATE_MEAN := 50.0            ## 根骨与心智的先天上限均值
const INNATE_DEV := 15.0
const INNATE_START_RATIO := 0.6      ## 入门时根骨/心智 ≈ 先天上限的 60%，此后随年龄长到上限
const POTENTIAL_MEAN := 60.0
const POTENTIAL_DEV := 15.0
const POTENTIAL_MIN := 20
const STARTER_SKILLS := 2            ## 每名新弟子有几项"入门所学"
const INITIAL_MAJOR_RATIO := 0.7     ## 入门所学 ≈ 对应项的 70%
const INITIAL_MINOR_RATIO := 0.2     ## 其他武学 ≈ 对应项的 20%
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
## 勤勉影响修炼体力消耗：消耗 = TRAIN_STAMINA_COST × (BASE − SPAN × 勤勉/100)，勤勉 50 → 20，100 → 15
const QINMIAN_COST_BASE := 1.25
const QINMIAN_COST_SPAN := 0.5

# --- 心智与根骨的自然增长（每满一岁结算一次） ---
## [年龄上界, 比例]：每年补上 (先天上限 − 当前值) × 比例，向上取整
const MIND_MATURE_TABLE := [[18.0, 0.2], [30.0, 0.12], [50.0, 0.06], [999.0, 0.02]]
const GENGU_MATURE_TABLE := [[18.0, 0.3], [999.0, 0.0]]   ## 根骨只在少年期长
