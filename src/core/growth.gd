class_name Growth
extends RefCounted
## 弟子成长规则：每旬结算一次修炼、体力与年龄；满一岁时根骨与心智自然增长。
## 修炼经验的通用入口 gain_xp；心智阅历的通用入口 gain_experience。

## 各成长曲线的年龄段倍率表：[年龄上界, 倍率]，取第一个满足 年龄 < 上界 的行
const AGE_TABLES := {
	Disciple.GrowthCurve.PRECOCIOUS: [[18.0, 1.5], [28.0, 1.0], [40.0, 0.6], [999.0, 0.3]],
	Disciple.GrowthCurve.LATE: [[18.0, 0.7], [25.0, 0.9], [45.0, 1.4], [999.0, 0.6]],
	Disciple.GrowthCurve.STEADY: [[18.0, 1.0], [45.0, 1.0], [999.0, 0.5]],
}


## 升到下一级所需经验
static func xp_threshold(current_level: int) -> float:
	return Balance.XP_THRESHOLD_BASE + Balance.XP_THRESHOLD_PER_STAT * current_level


## 某个可修炼项目的上限：由潜力与对应项共同决定。
## 对应项本身也会成长（如练硬功会抬高刀法上限），所以上限不是固定值。
static func skill_cap(d: Disciple, skill: StringName) -> int:
	var rel: int = d.stats[Balance.RELATED[skill]]
	var ratio: float = Balance.CAP_ATTRIBUTE_FLOOR + (1.0 - Balance.CAP_ATTRIBUTE_FLOOR) * rel / 100.0
	return clampi(roundi(d.potential * ratio), Balance.STAT_MIN, Balance.STAT_MAX)


## 悟性对修炼经验的系数：悟性 50 → 1.0，100 → 1.5
static func wuxing_coef(d: Disciple) -> float:
	return 0.5 + float(d.stats[&"wuxing"]) / 100.0


## 对应项（如刀法看硬功）对成长速度的系数：对应项 50 → 1.0
static func related_coef(d: Disciple, skill: StringName) -> float:
	var rel: int = d.stats[Balance.RELATED[skill]]
	return Balance.RELATED_COEF_BASE + Balance.RELATED_COEF_SPAN * rel / 100.0


## 修炼一旬消耗的体力：勤勉越高越省力
static func train_stamina_cost(d: Disciple) -> int:
	var k: float = Balance.QINMIAN_COST_BASE - Balance.QINMIAN_COST_SPAN * d.stats[&"qinmian"] / 100.0
	return roundi(Balance.TRAIN_STAMINA_COST * k)


## 最大生命、最大内力（占位公式）
static func max_hp(d: Disciple) -> int:
	return Balance.HP_BASE + roundi(d.stats[&"gengu"] * Balance.HP_PER_GENGU + d.stats[&"yinggong"] * Balance.HP_PER_YINGGONG)


static func max_neili(d: Disciple) -> int:
	return Balance.NEILI_BASE + roundi(d.stats[&"neigong"] * Balance.NEILI_PER_SKILL)


## 武学学习门槛的折扣系数（0~1）。requirements: 任意数值项 id -> 所需数值，
## 例如独孤九剑 {&"wuxing": 90}。
## 占位规则：按"最不达标的一项"线性折扣；具体折扣曲线以后再定。
static func requirement_factor(d: Disciple, requirements: Dictionary) -> float:
	var factor := 1.0
	for attr in requirements:
		var need: int = requirements[attr]
		if need > 0:
			factor = minf(factor, clampf(float(d.stats[attr]) / need, 0.0, 1.0))
	return factor


## 年龄与成长曲线带来的经验倍率。起伏型会消耗一次随机数。
static func age_multiplier(curve: Disciple.GrowthCurve, age_years: float, skill: StringName, rng: RandomNumberGenerator) -> float:
	var key := Disciple.GrowthCurve.STEADY if curve == Disciple.GrowthCurve.ERRATIC else curve
	var table: Array = AGE_TABLES[key]
	var mult: float = table[table.size() - 1][1]
	for row in table:
		if age_years < row[0]:
			mult = row[1]
			break
	if skill == &"neigong" and age_years >= Balance.DECLINE_AGE:
		mult = maxf(mult, Balance.NEIGONG_AGE_FLOOR)
	if curve == Disciple.GrowthCurve.ERRATIC:
		mult *= rng.randf_range(Balance.ERRATIC_MIN, Balance.ERRATIC_MAX)
	return mult


## 给某个可修炼项目增加经验并结算升级，返回升了几级。到达上限则不再增长。
## 修炼、实战、读秘籍等所有来源都应通过这里加经验。
static func gain_xp(d: Disciple, skill: StringName, amount: float) -> int:
	var cap := skill_cap(d, skill)
	if d.stats[skill] >= cap:
		return 0
	d.xp[skill] += amount
	return _apply_levels(d, skill, cap)


## 结算一旬：修炼或休息、体力变化、年龄 +1。返回本旬报告。
## training_mult：建筑（练武场）带来的修炼经验倍率；rest_bonus：药庐带来的额外体力恢复。
static func settle_xun(d: Disciple, plan: TrainingPlan, rng: RandomNumberGenerator,
		training_mult: float = 1.0, rest_bonus: int = 0) -> Dictionary:
	var report := {"trained": false, "xp": 0.0, "levels": 0}
	var training := plan != null and not plan.rest and Balance.TRAINABLE.has(plan.focus)
	if training:
		report["trained"] = true
		var eff := 1.0 if d.stamina >= Balance.LOW_STAMINA else Balance.LOW_STAMINA_EFFICIENCY
		if d.stats[plan.focus] < skill_cap(d, plan.focus):
			var gained: float = Balance.BASE_XP * plan.method_mult * wuxing_coef(d) \
				* related_coef(d, plan.focus) * plan.master_mult * plan.facility_mult * training_mult \
				* age_multiplier(d.curve, d.age_years(), plan.focus, rng) * eff
			report["xp"] = gained
			report["levels"] = gain_xp(d, plan.focus, gained)
		d.stamina = maxi(0, d.stamina - train_stamina_cost(d))
	else:
		d.stamina = mini(Balance.STAMINA_MAX, d.stamina + Balance.REST_STAMINA_GAIN + rest_bonus)
	d.age_xun += 1
	if d.age_xun % Balance.XUN_PER_YEAR == 0:
		mature(d)
	return report


## 满一岁时的自然增长：根骨与心智向先天上限靠拢，年纪越小长得越多。
static func mature(d: Disciple) -> void:
	var age := d.age_years()
	for key in Balance.MATURING:
		var gap: int = d.innate[key] - d.stats[key]
		if gap <= 0:
			continue
		var table: Array = Balance.GENGU_MATURE_TABLE if key == &"gengu" else Balance.MIND_MATURE_TABLE
		var ratio: float = _lookup(table, age)
		if ratio > 0.0:
			d.stats[key] += mini(gap, ceili(gap * ratio))


## 阅历：任务、火并、江湖事件等让某项心智增长 amount 点，同时抬高先天上限，
## 所以阅历的收获不会被以后的年龄增长"吃掉"。返回实际增长量。
static func gain_experience(d: Disciple, key: StringName, amount: int) -> int:
	if not Balance.MIND.has(key) or amount <= 0:
		return 0
	var before: int = d.stats[key]
	d.stats[key] = mini(Balance.STAT_MAX, before + amount)
	d.innate[key] = mini(Balance.STAT_MAX, d.innate[key] + amount)
	return d.stats[key] - before


## 分段表 [[上界, 值], ...]：取第一个满足 x < 上界 的值
static func _lookup(table: Array, x: float) -> float:
	for row in table:
		if x < row[0]:
			return row[1]
	return table[table.size() - 1][1]


static func _apply_levels(d: Disciple, skill: StringName, cap: int) -> int:
	var levels := 0
	while d.stats[skill] < cap:
		var need := xp_threshold(d.stats[skill])
		if d.xp[skill] < need:
			break
		d.xp[skill] -= need
		d.stats[skill] += 1
		levels += 1
	if d.stats[skill] >= cap:
		d.xp[skill] = 0.0
	return levels
