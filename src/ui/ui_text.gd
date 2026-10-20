class_name UiText
extends RefCounted
## 界面文字：技能名、属性名、曲线名、日期格式。以后做多语言时从这里迁移到翻译表。

const SKILL := {
	&"jian": "剑法", &"dao": "刀法", &"gun": "棍法", &"quan": "拳掌",
	&"neigong": "内功", &"qinggong": "轻功", &"yishu": "医术", &"dugong": "毒功",
}
const ATTR := {
	&"wuxing": "悟性", &"gengu": "根骨", &"shenfa": "身法", &"zhimou": "智谋",
	&"meili": "魅力", &"lingdao": "领导力", &"dingli": "定力", &"qinhe": "亲和",
}
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


## 当前等级最高的技能（用于名册里的"专长"列与批量修炼）
static func top_skill(d: Disciple) -> StringName:
	var best: StringName = Balance.SKILLS[0]
	for s in Balance.SKILLS:
		if d.skills[s] > d.skills[best]:
			best = s
	return best
