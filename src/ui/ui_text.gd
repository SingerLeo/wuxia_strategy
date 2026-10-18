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
const CURVE: Array[String] = ["早慧", "晚成", "稳健", "起伏"]
const SEASON: Array[String] = ["春", "夏", "秋", "冬"]


static func date_text(sect: Sect) -> String:
	return "第%d年 %s · 第%d旬" % [
		sect.current_year() + 1,
		SEASON[sect.current_season()],
		sect.xun % Balance.XUN_PER_SEASON + 1,
	]


## 当前等级最高的技能（用于名册里的"专长"列与批量修炼）
static func top_skill(d: Disciple) -> StringName:
	var best: StringName = Balance.SKILLS[0]
	for s in Balance.SKILLS:
		if d.skills[s] > d.skills[best]:
			best = s
	return best
