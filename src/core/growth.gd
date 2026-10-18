class_name Growth
extends RefCounted
## 弟子成长规则：每旬结算一次修炼、体力与年龄；技能经验的通用入口 gain_xp。

## 各成长曲线的年龄段倍率表：[年龄上界, 倍率]，取第一个满足 年龄 < 上界 的行
const AGE_TABLES := {
	Disciple.GrowthCurve.PRECOCIOUS: [[18.0, 1.5], [28.0, 1.0], [40.0, 0.6], [999.0, 0.3]],
	Disciple.GrowthCurve.LATE: [[18.0, 0.7], [25.0, 0.9], [45.0, 1.4], [999.0, 0.6]],
	Disciple.GrowthCurve.STEADY: [[18.0, 1.0], [45.0, 1.0], [999.0, 0.5]],
}


## 升到下一级所需经验
static func xp_threshold(current_level: int) -> float:
	return Balance.XP_THRESHOLD_BASE + Balance.XP_THRESHOLD_PER_STAT * current_level


## 某项技能的上限：由潜力与对应属性共同决定
static func skill_cap(d: Disciple, skill: StringName) -> int:
	var attr: int = d.attributes[Balance.SKILL_ATTRIBUTE[skill]]
	var ratio: float = Balance.CAP_ATTRIBUTE_FLOOR + (1.0 - Balance.CAP_ATTRIBUTE_FLOOR) * attr / 100.0
	return clampi(roundi(d.potential * ratio), Balance.STAT_MIN, Balance.STAT_MAX)


## 悟性对修炼经验的系数：悟性 50 → 1.0，100 → 1.5
static func wuxing_coef(d: Disciple) -> float:
	return 0.5 + float(d.attributes[&"wuxing"]) / 100.0


## 技能对应属性（如内功看根骨）对成长速度的系数：属性 50 → 1.0
static func related_coef(d: Disciple, skill: StringName) -> float:
	var attr: int = d.attributes[Balance.SKILL_ATTRIBUTE[skill]]
	return Balance.RELATED_COEF_BASE + Balance.RELATED_COEF_SPAN * attr / 100.0


## 最大生命、最大内力（占位公式）
static func max_hp(d: Disciple) -> int:
	return Balance.HP_BASE + roundi(d.attributes[&"gengu"] * Balance.HP_PER_GENGU)


static func max_neili(d: Disciple) -> int:
	return Balance.NEILI_BASE + roundi(d.skills[&"neigong"] * Balance.NEILI_PER_SKILL)


## 武学学习门槛的折扣系数（0~1）。requirements: 属性 id -> 所需数值，
## 例如独孤九剑 {&"wuxing": 90}。
## 占位规则：按"最不达标的一项"线性折扣；具体折扣曲线以后再定。
static func requirement_factor(d: Disciple, requirements: Dictionary) -> float:
	var factor := 1.0
	for attr in requirements:
		var need: int = requirements[attr]
		if need > 0:
			factor = minf(factor, clampf(float(d.attributes[attr]) / need, 0.0, 1.0))
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


## 给某项技能增加经验并结算升级，返回升了几级。到达上限则不再增长。
## 修炼、实战、读秘籍等所有来源都应通过这里加经验。
static func gain_xp(d: Disciple, skill: StringName, amount: float) -> int:
	var cap := skill_cap(d, skill)
	if d.skills[skill] >= cap:
		return 0
	d.xp[skill] += amount
	return _apply_levels(d, skill, cap)


## 结算一旬：修炼或休息、体力变化、年龄 +1。返回本旬报告。
static func settle_xun(d: Disciple, plan: TrainingPlan, rng: RandomNumberGenerator) -> Dictionary:
	var report := {"trained": false, "xp": 0.0, "levels": 0}
	var training := plan != null and not plan.rest and Balance.SKILLS.has(plan.focus)
	if training:
		report["trained"] = true
		var eff := 1.0 if d.stamina >= Balance.LOW_STAMINA else Balance.LOW_STAMINA_EFFICIENCY
		if d.skills[plan.focus] < skill_cap(d, plan.focus):
			var gained: float = Balance.BASE_XP * plan.method_mult * wuxing_coef(d) \
				* related_coef(d, plan.focus) * plan.master_mult * plan.facility_mult \
				* age_multiplier(d.curve, d.age_years(), plan.focus, rng) * eff
			report["xp"] = gained
			report["levels"] = gain_xp(d, plan.focus, gained)
		d.stamina = maxi(0, d.stamina - Balance.TRAIN_STAMINA_COST)
	else:
		d.stamina = mini(Balance.STAMINA_MAX, d.stamina + Balance.REST_STAMINA_GAIN)
	d.age_xun += 1
	return report


static func _apply_levels(d: Disciple, skill: StringName, cap: int) -> int:
	var levels := 0
	while d.skills[skill] < cap:
		var need := xp_threshold(d.skills[skill])
		if d.xp[skill] < need:
			break
		d.xp[skill] -= need
		d.skills[skill] += 1
		levels += 1
	if d.skills[skill] >= cap:
		d.xp[skill] = 0.0
	return levels
