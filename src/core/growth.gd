class_name Growth
extends RefCounted
## 弟子成长规则：每旬结算一次修炼、体力与年龄。

## 各成长曲线的年龄段倍率表：[年龄上界, 倍率]，取第一个满足 年龄 < 上界 的行
const AGE_TABLES := {
	Disciple.GrowthCurve.PRECOCIOUS: [[18.0, 1.5], [28.0, 1.0], [40.0, 0.6], [999.0, 0.3]],
	Disciple.GrowthCurve.LATE: [[18.0, 0.7], [25.0, 0.9], [45.0, 1.4], [999.0, 0.6]],
	Disciple.GrowthCurve.STEADY: [[18.0, 1.0], [45.0, 1.0], [999.0, 0.5]],
}


## 升到下一级所需经验
static func xp_threshold(current_stat: int) -> float:
	return Balance.XP_THRESHOLD_BASE + Balance.XP_THRESHOLD_PER_STAT * current_stat


## 某项属性的上限：由潜力与对应资质共同决定
static func stat_cap(d: Disciple, stat: StringName) -> int:
	var apt: int = d.aptitudes[Balance.STAT_APTITUDE[stat]]
	var ratio: float = Balance.CAP_APTITUDE_FLOOR + (1.0 - Balance.CAP_APTITUDE_FLOOR) * apt / 100.0
	return clampi(roundi(d.potential * ratio), Balance.STAT_MIN, Balance.STAT_MAX)


## 悟性对修炼经验的系数：悟性 50 → 1.0，100 → 1.5
static func wuxing_coef(d: Disciple) -> float:
	return 0.5 + float(d.aptitudes[&"wuxing"]) / 100.0


## 年龄与成长曲线带来的经验倍率。起伏型会消耗一次随机数。
static func age_multiplier(curve: Disciple.GrowthCurve, age_years: float, stat: StringName, rng: RandomNumberGenerator) -> float:
	var key := Disciple.GrowthCurve.STEADY if curve == Disciple.GrowthCurve.ERRATIC else curve
	var table: Array = AGE_TABLES[key]
	var mult: float = table[table.size() - 1][1]
	for row in table:
		if age_years < row[0]:
			mult = row[1]
			break
	if stat == &"neili" and age_years >= Balance.DECLINE_AGE:
		mult = maxf(mult, Balance.NEILI_AGE_FLOOR)
	if curve == Disciple.GrowthCurve.ERRATIC:
		mult *= rng.randf_range(Balance.ERRATIC_MIN, Balance.ERRATIC_MAX)
	return mult


## 结算一旬：修炼或休息、体力变化、年龄 +1。返回本旬报告。
static func settle_xun(d: Disciple, plan: TrainingPlan, rng: RandomNumberGenerator) -> Dictionary:
	var report := {"trained": false, "xp": 0.0, "levels": 0}
	var training := plan != null and not plan.rest and Balance.STATS.has(plan.focus)
	if training:
		report["trained"] = true
		var eff := 1.0 if d.stamina >= Balance.LOW_STAMINA else Balance.LOW_STAMINA_EFFICIENCY
		var cap := stat_cap(d, plan.focus)
		if d.stats[plan.focus] < cap:
			var gained: float = Balance.BASE_XP * plan.method_mult * wuxing_coef(d) \
				* plan.master_mult * plan.facility_mult \
				* age_multiplier(d.curve, d.age_years(), plan.focus, rng) * eff
			d.xp[plan.focus] += gained
			report["xp"] = gained
			report["levels"] = _apply_levels(d, plan.focus, cap)
		d.stamina = maxi(0, d.stamina - Balance.TRAIN_STAMINA_COST)
	else:
		d.stamina = mini(Balance.STAMINA_MAX, d.stamina + Balance.REST_STAMINA_GAIN)
	d.age_xun += 1
	return report


static func _apply_levels(d: Disciple, stat: StringName, cap: int) -> int:
	var levels := 0
	while d.stats[stat] < cap:
		var need := xp_threshold(d.stats[stat])
		if d.xp[stat] < need:
			break
		d.xp[stat] -= need
		d.stats[stat] += 1
		levels += 1
	if d.stats[stat] >= cap:
		d.xp[stat] = 0.0
	return levels
