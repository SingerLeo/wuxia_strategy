extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1


## 标准弟子：基本功与心智全 50、武学全 10、潜力 100、20 岁、稳健型
func _standard() -> Disciple:
	var d := Disciple.new()
	d.potential = 100
	d.curve = Disciple.GrowthCurve.STEADY
	d.age_xun = 20 * Balance.XUN_PER_YEAR
	for s in Balance.MARTIAL:
		d.stats[s] = 10
	return d


func test_training_accumulates_xp() -> void:
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.train(&"jian"), rng)
	assert_true(report["trained"])
	assert_almost_eq(report["xp"], 20.0, 0.001, "20 × 悟性系数 1.0 × 对应项系数 1.0")
	assert_eq(d.stats[&"jian"], 11, "20 经验超过 15.5 门槛，升 1 级")
	assert_almost_eq(d.xp[&"jian"], 4.5, 0.001, "升级后余 4.5")


func test_wuxing_speeds_up_training() -> void:
	var d := _standard()
	d.stats[&"wuxing"] = 100
	var report := Growth.settle_xun(d, TrainingPlan.train(&"jian"), rng)
	assert_almost_eq(report["xp"], 30.0, 0.001)


func test_related_stat_speeds_up_its_skill() -> void:
	var d := _standard()
	d.stats[&"shenfa"] = 100   # 剑法看身法：0.7 + 0.6 = 1.3
	d.stats[&"yinggong"] = 0   # 刀法看硬功：0.7
	var r1 := Growth.settle_xun(d, TrainingPlan.train(&"jian"), rng)
	assert_almost_eq(r1["xp"], 26.0, 0.001)
	var r2 := Growth.settle_xun(d, TrainingPlan.train(&"dao"), rng)
	assert_almost_eq(r2["xp"], 14.0, 0.001)


func test_basics_are_trainable_and_follow_their_related_stat() -> void:
	var d := _standard()
	d.stats[&"dingli"] = 100   # 内功看定力
	var report := Growth.settle_xun(d, TrainingPlan.train(&"neigong"), rng)
	assert_true(report["trained"])
	assert_almost_eq(report["xp"], 26.0, 0.001)
	d.stats[&"gengu"] = 0      # 硬功看根骨
	assert_almost_eq(Growth.settle_xun(d, TrainingPlan.train(&"yinggong"), rng)["xp"], 14.0, 0.001)


func test_mind_and_gengu_cannot_be_trained() -> void:
	var d := _standard()
	for key in [&"wuxing", &"letian", &"gengu"]:
		var before: int = d.stats[key]
		var report := Growth.settle_xun(d, TrainingPlan.train(key), rng)
		assert_false(report["trained"], "%s 不能修炼" % key)
		assert_eq(d.stats[key], before)


func test_plan_multipliers_stack() -> void:
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.train(&"jian", 1.2, 1.5, 1.1), rng)
	assert_almost_eq(report["xp"], 20.0 * 1.2 * 1.5 * 1.1, 0.001)


func test_training_costs_stamina_and_rest_recovers() -> void:
	var d := _standard()
	Growth.settle_xun(d, TrainingPlan.train(&"quanjiao"), rng)
	assert_eq(d.stamina, 80)
	Growth.settle_xun(d, TrainingPlan.resting(), rng)
	assert_eq(d.stamina, 100, "恢复 35 但不超过上限 100")


func test_qinmian_lowers_stamina_cost() -> void:
	var d := _standard()
	assert_eq(Growth.train_stamina_cost(d), 20, "勤勉 50 → 20")
	d.stats[&"qinmian"] = 100
	assert_eq(Growth.train_stamina_cost(d), 15)
	d.stats[&"qinmian"] = 0
	assert_eq(Growth.train_stamina_cost(d), 25)


func test_null_plan_means_rest() -> void:
	var d := _standard()
	d.stamina = 50
	var report := Growth.settle_xun(d, null, rng)
	assert_false(report["trained"])
	assert_eq(d.stamina, 85)


func test_low_stamina_halves_efficiency() -> void:
	var d := _standard()
	d.stamina = 20
	Growth.settle_xun(d, TrainingPlan.train(&"jian"), rng)
	assert_almost_eq(d.xp[&"jian"], 10.0, 0.001)
	assert_eq(d.stamina, 0, "体力不会为负")


func test_skill_cannot_exceed_cap() -> void:
	var d := _standard()
	d.potential = 40  # 身法 50 → 剑法上限 round(40 × 0.85) = 34
	assert_eq(Growth.skill_cap(d, &"jian"), 34)
	d.stats[&"jian"] = 34
	var report := Growth.settle_xun(d, TrainingPlan.train(&"jian"), rng)
	assert_eq(d.stats[&"jian"], 34)
	assert_eq(report["levels"], 0)
	assert_almost_eq(d.xp[&"jian"], 0.0, 0.001, "到顶后不再累积经验")


func test_cap_depends_on_related_stat() -> void:
	var d := _standard()
	d.stats[&"shenfa"] = 100
	d.stats[&"yinggong"] = 0
	assert_eq(Growth.skill_cap(d, &"jian"), 100, "剑法看身法")
	assert_eq(Growth.skill_cap(d, &"dao"), 70, "刀法看硬功")
	assert_eq(Growth.skill_cap(d, &"yishu"), 85, "医术看智谋（50）")


func test_training_basics_raises_martial_cap() -> void:
	var d := _standard()
	d.stats[&"yinggong"] = 20
	var before := Growth.skill_cap(d, &"dao")
	d.stats[&"yinggong"] = 80
	assert_gt(Growth.skill_cap(d, &"dao"), before, "硬功练高了，刀法上限跟着提高")


func test_gain_xp_is_a_general_entry_point() -> void:
	var d := _standard()
	# 门槛：10→11 需 15.5，11→12 需 16.05，12→13 需 16.6（共 48.15）
	var levels := Growth.gain_xp(d, &"dao", 60.0)
	assert_eq(levels, 3)
	assert_eq(d.stats[&"dao"], 13)
	assert_almost_eq(d.xp[&"dao"], 11.85, 0.001)
	assert_eq(Growth.gain_xp(d, &"dao", 5.0), 0, "16.85 不足 13→14 的 17.15，不升级")
	assert_eq(Growth.gain_xp(d, &"dao", 0.5), 1, "凑够 17.15，升一级")
	assert_eq(d.stats[&"dao"], 14)


## 把弟子放到生日前一旬，下一次结算就满一岁
func _before_birthday(d: Disciple, years: int) -> void:
	d.age_xun = years * Balance.XUN_PER_YEAR - 1


func test_mind_matures_on_birthday_toward_innate() -> void:
	var d := _standard()
	d.stats[&"wuxing"] = 30
	d.innate[&"wuxing"] = 80
	_before_birthday(d, 15)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"wuxing"], 40, "15 岁补上差距 50 的 20%")
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"wuxing"], 40, "不到生日不长")


func test_mind_matures_slower_with_age_and_stops_at_innate() -> void:
	var d := _standard()
	d.stats[&"zhimou"] = 40
	d.innate[&"zhimou"] = 60
	_before_birthday(d, 35)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"zhimou"], 42, "35 岁只补 6%（向上取整）")
	d.stats[&"zhimou"] = 60
	_before_birthday(d, 16)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"zhimou"], 60, "到先天上限就不再自然增长")


func test_gengu_only_matures_in_youth() -> void:
	var d := _standard()
	d.stats[&"gengu"] = 40
	d.innate[&"gengu"] = 70
	_before_birthday(d, 16)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"gengu"], 49, "少年期补 30%")
	_before_birthday(d, 20)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.stats[&"gengu"], 49, "成年后根骨不再长")


func test_experience_raises_mind_and_its_ceiling() -> void:
	var d := _standard()
	d.innate[&"danshi"] = 50
	assert_eq(Growth.gain_experience(d, &"danshi", 5), 5)
	assert_eq(d.stats[&"danshi"], 55)
	assert_eq(d.innate[&"danshi"], 55, "阅历同时抬高先天上限，不会被年龄增长吃掉")
	d.stats[&"danshi"] = 98
	assert_eq(Growth.gain_experience(d, &"danshi", 5), 2, "不超过 100")
	assert_eq(Growth.gain_experience(d, &"jian", 5), 0, "阅历只作用于心智")


func test_each_xun_ages_by_one() -> void:
	var d := _standard()
	var before := d.age_xun
	Growth.settle_xun(d, null, rng)
	Growth.settle_xun(d, TrainingPlan.train(&"neigong"), rng)
	assert_eq(d.age_xun, before + 2)


func test_age_multiplier_by_curve() -> void:
	var c := Disciple.GrowthCurve
	assert_almost_eq(Growth.age_multiplier(c.PRECOCIOUS, 15.0, &"quanjiao", rng), 1.5, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.LATE, 15.0, &"quanjiao", rng), 0.7, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.LATE, 30.0, &"quanjiao", rng), 1.4, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.STEADY, 30.0, &"quanjiao", rng), 1.0, 0.001)
	assert_almost_eq(Growth.age_multiplier(c.STEADY, 60.0, &"quanjiao", rng), 0.5, 0.001)


func test_neigong_declines_slower_in_old_age() -> void:
	var c := Disciple.GrowthCurve.STEADY
	assert_almost_eq(Growth.age_multiplier(c, 60.0, &"neigong", rng), 0.8, 0.001)
	assert_almost_eq(Growth.age_multiplier(c, 60.0, &"qinggong", rng), 0.5, 0.001)


func test_erratic_varies_within_bounds_and_is_reproducible() -> void:
	var c := Disciple.GrowthCurve.ERRATIC
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var seen := {}
	for i in 50:
		var m1 := Growth.age_multiplier(c, 20.0, &"quanjiao", r1)
		var m2 := Growth.age_multiplier(c, 20.0, &"quanjiao", r2)
		assert_eq(m1, m2, "同一种子应得到同一序列")
		assert_between(m1, Balance.ERRATIC_MIN, Balance.ERRATIC_MAX)
		seen[snappedf(m1, 0.01)] = true
	assert_gt(seen.size(), 10, "起伏型倍率应当真的变化")


func test_max_hp_and_neili_follow_basics() -> void:
	var d := _standard()
	d.stats[&"gengu"] = 50
	d.stats[&"yinggong"] = 50
	d.stats[&"neigong"] = 10
	assert_eq(Growth.max_hp(d), 100)    # 60 + 50 × 0.5 + 50 × 0.3
	assert_eq(Growth.max_neili(d), 40)   # 20 + 10 × 2
	d.stats[&"neigong"] = 60
	assert_eq(Growth.max_neili(d), 140)


func test_requirement_factor_discounts_when_below_requirement() -> void:
	var d := _standard()
	d.stats[&"wuxing"] = 45
	assert_almost_eq(Growth.requirement_factor(d, {&"wuxing": 90}), 0.5, 0.001)
	d.stats[&"wuxing"] = 95
	assert_almost_eq(Growth.requirement_factor(d, {&"wuxing": 90}), 1.0, 0.001, "达标则无折扣")
	assert_almost_eq(Growth.requirement_factor(d, {}), 1.0, 0.001, "无门槛")


func test_requirement_factor_uses_worst_attribute() -> void:
	var d := _standard()
	d.stats[&"wuxing"] = 90
	d.stats[&"gengu"] = 30
	assert_almost_eq(Growth.requirement_factor(d, {&"wuxing": 90, &"gengu": 60}), 0.5, 0.001)


## 数值锚点：潜力/悟性/对应项全 100 的早慧型天才，12 岁起专攻一门，
## 按"体力 ≥40 修炼、否则休息"的节奏，10 年（120 旬）内从 1 练到 100。
## 勤勉固定为 50（体力消耗 20），以保持与引入勤勉之前同一锚点。
## 调整 Balance 的修炼数值后必须重跑本测试。
func test_genius_maxes_a_skill_within_ten_years() -> void:
	var d := Disciple.new()
	d.potential = 100
	d.curve = Disciple.GrowthCurve.PRECOCIOUS
	d.age_xun = 12 * Balance.XUN_PER_YEAR
	for k in d.stats:
		d.stats[k] = 100
	d.stats[&"qinmian"] = 50
	d.stats[&"jian"] = 1
	assert_eq(Growth.skill_cap(d, &"jian"), 100, "天才的剑法上限应为 100")

	var budget := 10 * Balance.XUN_PER_YEAR
	var reached := -1
	for i in budget:
		var plan := TrainingPlan.train(&"jian") if d.stamina >= 40 else TrainingPlan.resting()
		Growth.settle_xun(d, plan, rng)
		if d.stats[&"jian"] >= 100:
			reached = i + 1
			break
	assert_eq(d.stats[&"jian"], 100, "天才应在 10 年内练满，实际 %d 旬时为 %d" % [budget, d.stats[&"jian"]])
	if reached > 0:
		gut.p("天才剑法练满用时：%d 旬（%.1f 年）" % [reached, reached / float(Balance.XUN_PER_YEAR)])
