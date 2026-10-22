extends GutTest
## 训练科目、日程与按日程结算。

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1


## 基本功与心智全 50、武学全 10、潜力 100、20 岁、稳健型
func _standard() -> Disciple:
	var d := Disciple.new()
	d.potential = 100
	d.curve = Disciple.GrowthCurve.STEADY
	d.age_xun = 20 * Balance.XUN_PER_YEAR
	for s in Balance.MARTIAL:
		d.stats[s] = 10
	return d


func test_focus_weights_sum_to_one_and_only_trainable() -> void:
	assert_eq(Training.FOCI.size(), Training.FOCUS_WEIGHTS.size())
	for f in Training.FOCI:
		assert_true(UiText.FOCUS.has(f), "%s 缺少显示名" % f)
		var total := 0.0
		for stat in Training.FOCUS_WEIGHTS[f]:
			assert_true(Balance.TRAINABLE.has(stat), "%s 里的 %s 不能修炼" % [f, stat])
			total += Training.FOCUS_WEIGHTS[f][stat]
		assert_almost_eq(total, 1.0, 0.001, "%s 的权重之和应为 1" % f)


func test_every_trainable_stat_is_covered_by_some_focus() -> void:
	var covered := {}
	for f in Training.FOCI:
		for stat in Training.FOCUS_WEIGHTS[f]:
			covered[stat] = true
	for stat in Balance.TRAINABLE:
		assert_true(covered.has(stat), "%s 没有任何科目能练" % stat)


func test_set_slots_caps_total_at_twenty() -> void:
	var s := Schedule.new()
	assert_eq(s.set_slots(&"jianshu", 12), 12)
	assert_eq(s.set_slots(&"dazuo", 12), 8, "只剩 8 份")
	assert_eq(s.used_slots(), Training.SLOTS)
	assert_eq(s.set_slots(&"jianshu", 4), 4, "改小自己的份数不受限")
	assert_eq(s.used_slots(), 12)
	s.set_slots(&"dazuo", 0)
	assert_false(s.slots.has(&"dazuo"), "0 份就移除")
	assert_eq(s.set_slots(&"不存在", 5), 0)


func test_allocation_splits_time_by_slots_and_weights() -> void:
	var s := Schedule.new()
	s.set_slots(&"jianshu", 10)   # 一半时间：剑法 .6、身法 .25、反应 .15
	s.set_slots(&"qingshen", 10)  # 一半时间：轻功 .5、身法 .3、反应 .2
	var a := s.allocation()
	assert_almost_eq(a[&"jian"], 0.3, 0.001)
	assert_almost_eq(a[&"shenfa"], 0.275, 0.001, "两个科目都练身法，叠加")
	assert_almost_eq(a[&"fanying"], 0.175, 0.001)
	assert_almost_eq(a[&"qinggong"], 0.25, 0.001)
	var total := 0.0
	for k in a:
		total += a[k]
	assert_almost_eq(total, 1.0, 0.001, "分满 20 份，比例合计为 1")


func test_allocation_applies_focus_multiplier() -> void:
	var s := Schedule.new()
	s.set_slots(&"anqishu", 20)
	var a := s.allocation({&"anqishu": 1.5})
	assert_almost_eq(a[&"anqi"], 0.9, 0.001, "教习加成 ×1.5")


func test_schedule_round_trip() -> void:
	var s := Schedule.new(7, "试")
	s.set_slots(&"waijia", 9)
	s.intensity = Training.Intensity.LIGHT
	var back := Schedule.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.id, 7)
	assert_eq(back.schedule_name, "试")
	assert_eq(back.slots_of(&"waijia"), 9)
	assert_eq(back.intensity, Training.Intensity.LIGHT)


func test_presets_are_valid() -> void:
	for s in Training.preset_schedules():
		assert_eq(s.used_slots(), Training.SLOTS, s.schedule_name)


func test_full_single_focus_schedule_matches_single_stat_training() -> void:
	# 20 份全给"暗器"科目：暗器分到 60% 时间，所以经验是整旬只练暗器的 60%
	var s := Schedule.new()
	s.set_slots(&"anqishu", 20)
	var a := _standard()
	var b := _standard()
	var r1 := Growth.settle_xun(a, TrainingPlan.from_schedule(s), rng)
	var r2 := Growth.settle_xun(b, TrainingPlan.train(&"anqi"), rng)
	assert_almost_eq(r1["xp"], r2["xp"], 0.001, "总经验相同（对应项都是 50）")
	assert_almost_eq(a.xp[&"anqi"], 12.0, 0.001, "暗器分到 60%，未到 15.5 的升级门槛")
	assert_almost_eq(a.xp[&"fanying"], 8.0, 0.001, "反应分到 40%")
	assert_eq(a.stamina, b.stamina, "体力消耗相同")


func test_schedule_spreads_xp_across_stats() -> void:
	var s := Schedule.new()
	s.set_slots(&"jianshu", 20)
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.from_schedule(s), rng)
	assert_almost_eq(report["xp"], 20.0, 0.001)
	assert_almost_eq(d.xp[&"jian"], 12.0, 0.001, "剑法 60%")
	assert_almost_eq(d.xp[&"shenfa"], 5.0, 0.001, "身法 25%")
	assert_almost_eq(d.xp[&"fanying"], 3.0, 0.001, "反应 15%")


func test_partial_schedule_gives_less_xp_and_costs_less_stamina() -> void:
	var s := Schedule.new()
	s.set_slots(&"dazuo", 10)  # 只分一半时间
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.from_schedule(s), rng)
	assert_almost_eq(report["xp"], 10.0, 0.001)
	assert_eq(d.stamina, 90, "体力只耗一半")


func test_intensity_scales_xp_and_stamina() -> void:
	var s := Schedule.new()
	s.set_slots(&"waijia", 20)
	s.intensity = Training.Intensity.HEAVY
	var d := _standard()
	var report := Growth.settle_xun(d, TrainingPlan.from_schedule(s), rng)
	assert_almost_eq(report["xp"], 25.0, 0.001, "重训经验 ×1.25")
	assert_eq(d.stamina, 70, "重训体力 ×1.5")
	s.intensity = Training.Intensity.LIGHT
	var e := _standard()
	report = Growth.settle_xun(e, TrainingPlan.from_schedule(s), rng)
	assert_almost_eq(report["xp"], 15.0, 0.001)
	assert_eq(e.stamina, 88)


func test_empty_schedule_is_rest() -> void:
	var d := _standard()
	d.stamina = 50
	var report := Growth.settle_xun(d, TrainingPlan.from_schedule(Schedule.new()), rng)
	assert_false(report["trained"])
	assert_eq(d.stamina, 85)


func test_report_gains_list_levelled_stats() -> void:
	var s := Schedule.new()
	s.set_slots(&"jianshu", 20)
	var d := _standard()
	d.xp[&"jian"] = 10.0  # 再得 12 就超过 15.5 的门槛
	var report := Growth.settle_xun(d, TrainingPlan.from_schedule(s), rng)
	assert_eq(report["gains"], {&"jian": 1}, "只列出升了级的项")
	assert_eq(report["levels"], 1)
