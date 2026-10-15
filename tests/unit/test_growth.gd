extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1


## 一个资质全 50、潜力 100、属性全 10、20 岁、稳健型的标准弟子
func _standard() -> Disciple:
	var d := Disciple.new()
	d.potential = 100
	d.curve = Disciple.GrowthCurve.STEADY
	d.age_xun = 20 * Balance.XUN_PER_YEAR
	for s in Balance.STATS:
		d.stats[s] = 10
	return d


func test_training_accumulates_xp() -> void:
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.train(&"neili"), rng)
	assert_true(report["trained"])
	assert_almost_eq(d.xp[&"neili"], 10.0, 0.001, "10 × 悟性系数 1.0")
	assert_eq(d.stats[&"neili"], 10, "经验未达标不升级")


func test_levels_up_when_xp_reaches_threshold() -> void:
	var d := _standard()
	var plan := TrainingPlan.train(&"neili")
	for i in 3:
		Growth.settle_xun(d, plan, rng)
	assert_eq(d.stats[&"neili"], 11, "10 级需 30 经验，3 旬 ×10")
	assert_almost_eq(d.xp[&"neili"], 0.0, 0.001)


func test_wuxing_speeds_up_training() -> void:
	var d := _standard()
	d.aptitudes[&"wuxing"] = 100
	Growth.settle_xun(d, TrainingPlan.train(&"neili"), rng)
	assert_almost_eq(d.xp[&"neili"], 15.0, 0.001)


func test_plan_multipliers_stack() -> void:
	var d := _standard()
	Growth.settle_xun(d, TrainingPlan.train(&"neili", 1.2, 1.5, 1.1), rng)
	assert_almost_eq(d.xp[&"neili"], 10.0 * 1.2 * 1.5 * 1.1, 0.001)


func test_training_costs_stamina_and_rest_recovers() -> void:
	var d := _standard()
	Growth.settle_xun(d, TrainingPlan.train(&"waigong"), rng)
	assert_eq(d.stamina, 80)
	Growth.settle_xun(d, TrainingPlan.resting(), rng)
	assert_eq(d.stamina, 100, "恢复 35 但不超过上限 100")


func test_null_plan_means_rest() -> void:
	var d := _standard()
	d.stamina = 50
	var report := Growth.settle_xun(d, null, rng)
	assert_false(report["trained"])
	assert_eq(d.stamina, 85)


func test_low_stamina_halves_efficiency() -> void:
	var d := _standard()
	d.stamina = 20
	Growth.settle_xun(d, TrainingPlan.train(&"neili"), rng)
	assert_almost_eq(d.xp[&"neili"], 5.0, 0.001)
	assert_eq(d.stamina, 0, "体力不会为负")


func test_stat_cannot_exceed_cap() -> void:
	var d := _standard()
	d.potential = 40  # 资质 50 → 上限 round(40 × 0.85) = 34
	assert_eq(Growth.stat_cap(d, &"neili"), 34)
	d.stats[&"neili"] = 34
	var report := Growth.settle_xun(d, TrainingPlan.train(&"neili"), rng)
	assert_eq(d.stats[&"neili"], 34)
	assert_eq(report["levels"], 0)
	assert_almost_eq(d.xp[&"neili"], 0.0, 0.001, "到顶后不再累积经验")


func test_cap_depends_on_related_aptitude() -> void:
	var d := _standard()
	d.aptitudes[&"gengu"] = 100
	d.aptitudes[&"shenfa"] = 0
	assert_eq(Growth.stat_cap(d, &"neili"), 100)
	assert_eq(Growth.stat_cap(d, &"qinggong"), 70)


func test_each_xun_ages_by_one() -> void:
	var d := _standard()
	var before := d.age_xun
	Growth.settle_xun(d, null, rng)
	Growth.settle_xun(d, TrainingPlan.train(&"neili"), rng)
	assert_eq(d.age_xun, before + 2)


func test_age_multiplier_by_curve() -> void:
	var c := Disciple.GrowthCurve
	assert_almost_eq(Growth.age_multiplier(c.PRECOCIOUS, 15.0, &"waigong", rng), 1.5, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.LATE, 15.0, &"waigong", rng), 0.7, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.LATE, 30.0, &"waigong", rng), 1.4, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.STEADY, 30.0, &"waigong", rng), 1.0, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.STEADY, 60.0, &"waigong", rng), 0.5, 0.001)


func test_neili_declines_slower_in_old_age() -> void:
	var c := Disciple.GrowthCurve.STEADY
	assert_almost_eq(Growth.age_multiplier(c, 60.0, &"neili", rng), 0.8, 0.001)
	assert_almost_eq(Growth.age_multiplier(c, 60.0, &"qinggong", rng), 0.5, 0.001)


func test_erratic_varies_within_bounds_and_is_reproducible() -> void:
	var c := Disciple.GrowthCurve.ERRATIC
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var seen := {}
	for i in 50:
		var m1 := Growth.age_multiplier(c, 20.0, &"waigong", r1)
		var m2 := Growth.age_multiplier(c, 20.0, &"waigong", r2)
		assert_eq(m1, m2, "同一种子应得到同一序列")
		assert_between(m1, Balance.ERRATIC_MIN, Balance.ERRATIC_MAX)
		seen[snappedf(m1, 0.01)] = true
	assert_gt(seen.size(), 10, "起伏型倍率应当真的变化")
