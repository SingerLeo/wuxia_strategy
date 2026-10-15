class_name UiText
extends RefCounted
## 界面文字：属性名、曲线名、日期格式。以后做多语言时从这里迁移到翻译表。

const STAT := {
	&"neili": "内力", &"waigong": "外功", &"qinggong": "轻功",
	&"yishu": "医术", &"moulue": "谋略", &"kouca": "口才",
}
const APT := {
	&"gengu": "根骨", &"wuxing": "悟性", &"shenfa": "身法",
	&"danshi": "胆识", &"xinxing": "心性",
}
const CURVE: Array[String] = ["早慧", "晚成", "稳健", "起伏"]
const SEASON: Array[String] = ["春", "夏", "秋", "冬"]


static func date_text(sect: Sect) -> String:
	return "第%d年 %s · 第%d旬" % [
		sect.current_year() + 1,
		SEASON[sect.current_season()],
		sect.xun % Balance.XUN_PER_SEASON + 1,
	]


## 当前数值最高的属性名（用于名册里的"专长"列）
static func top_stat(d: Disciple) -> StringName:
	var best: StringName = Balance.STATS[0]
	for s in Balance.STATS:
		if d.stats[s] > d.stats[best]:
			best = s
	return best
