class_name UiText
extends RefCounted
## 界面文字：数值项名、曲线名、日期格式。以后做多语言时从这里迁移到翻译表。

## 全部 24 个数值项的显示名（分类见 Balance.MARTIAL / BASICS / MIND）
const STAT := {
	&"jian": "剑法", &"dao": "刀法", &"qianggun": "枪棍", &"quanjiao": "拳脚",
	&"zhizhua": "指爪", &"anqi": "暗器", &"yishu": "医术", &"dushu": "毒术",
	&"neigong": "内功", &"qinggong": "轻功", &"ruangong": "软功", &"yinggong": "硬功",
	&"gengu": "根骨", &"naili": "耐力", &"shenfa": "身法", &"fanying": "反应",
	&"wuxing": "悟性", &"dingli": "定力", &"zhimou": "智谋", &"danshi": "胆识",
	&"qinmian": "勤勉", &"meili": "魅力", &"tongshuai": "统率", &"letian": "乐天",
}
const CAT_MARTIAL := "武学"
const CAT_BASICS := "基本功"
const CAT_MIND := "心智"
## 三大资源的显示名。第三种（解锁技能树的点数）暂名"底蕴"，想改只改这里。
const RES_SILVER := "银两"
const RES_PRESTIGE := "威望"
const RES_LEGACY := "底蕴"
const CURVE: Array[String] = ["早慧", "晚成", "稳健", "起伏"]
const SEASON: Array[String] = ["春", "夏", "秋", "冬"]


## 数值（1~100）在界面上显示为 1~20 的分数：x/5 向上取整，最低 1
static func score(value: float) -> int:
	return clampi(ceili(value / 5.0), 1, 20)


static func date_text(sect: Sect) -> String:
	return date_text_of_xun(sect.xun)


static func date_text_of_xun(xun: int) -> String:
	return "第%d年 %s · 第%d旬" % [
		xun / Balance.XUN_PER_YEAR + 1,
		SEASON[(xun % Balance.XUN_PER_YEAR) / Balance.XUN_PER_SEASON],
		xun % Balance.XUN_PER_SEASON + 1,
	]


## 当前等级最高的武学（用于名册里的"专长"列与批量修炼）
static func top_skill(d: Disciple) -> StringName:
	var best: StringName = Balance.MARTIAL[0]
	for s in Balance.MARTIAL:
		if d.stats[s] > d.stats[best]:
			best = s
	return best
