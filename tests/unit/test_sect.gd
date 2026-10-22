extends GutTest


func _make_sect(seed_value: int, count: int) -> Sect:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sect := Sect.new("测试派", rng)
	for i in count:
		sect.add_disciple(DiscipleFactory.create(rng, i))
	return sect


func _plans_for(sect: Sect) -> Dictionary:
	var plans := {}
	for d in sect.disciples:
		plans[d.id] = TrainingPlan.train(Balance.TRAINABLE[d.id % Balance.TRAINABLE.size()])
	return plans


func test_prestige_cannot_go_below_zero() -> void:
	var sect := _make_sect(1, 0)
	sect.change_prestige(-30)
	assert_eq(sect.prestige, 0)
	assert_eq(sect.prestige_peak, 0)


func test_prestige_peak_never_decreases() -> void:
	var sect := _make_sect(1, 0)
	sect.change_prestige(120)
	sect.change_prestige(-80)
	assert_eq(sect.prestige, 40)
	assert_eq(sect.prestige_peak, 120, "历史最高威望只增不减")
	sect.change_prestige(50)
	assert_eq(sect.prestige_peak, 120, "未超过旧纪录时不变")
	sect.change_prestige(100)  # 当前 40+50+100 = 190，超过旧纪录 120
	assert_eq(sect.prestige, 190)
	assert_eq(sect.prestige_peak, 190)


func test_task_tier_follows_peak_prestige_thresholds() -> void:
	var sect := _make_sect(1, 0)
	assert_eq(sect.task_tier(), 1)
	sect.change_prestige(49)
	assert_eq(sect.task_tier(), 1)
	sect.change_prestige(1)
	assert_eq(sect.task_tier(), 2, "达到 50 升到 2 级")
	sect.change_prestige(1000)
	assert_eq(sect.task_tier(), Balance.TASK_TIER_PRESTIGE.size(), "封顶在最高等级")


func test_task_tier_survives_prestige_loss() -> void:
	var sect := _make_sect(1, 0)
	sect.change_prestige(200)
	assert_eq(sect.task_tier(), 3)
	sect.change_prestige(-190)
	assert_eq(sect.prestige, 10)
	assert_eq(sect.task_tier(), 3, "任务等级由历史最高威望决定，威望下跌不影响")


func test_resources_round_trip_through_dict() -> void:
	var sect := _make_sect(1, 2)
	sect.silver = 777
	sect.legacy = 42
	sect.honor = 5
	sect.change_prestige(300)
	sect.change_prestige(-100)
	var back := Sect.from_dict(sect.to_dict())
	assert_eq(back.silver, 777)
	assert_eq(back.legacy, sect.legacy, "获得威望会带来底蕴，读档后应一致")
	assert_eq(back.honor, 5)
	assert_eq(back.prestige, 200)
	assert_eq(back.prestige_peak, 300)
	assert_eq(back.task_tier(), sect.task_tier())


func test_old_save_without_new_fields_still_loads() -> void:
	var sect := _make_sect(1, 1)
	sect.change_prestige(80)
	var data := sect.to_dict()
	data.erase("prestige_peak")
	data.erase("legacy")
	var back := Sect.from_dict(data)
	assert_eq(back.legacy, 0)
	assert_eq(back.prestige_peak, 80, "缺历史最高威望时至少取当前威望")


func test_calendar() -> void:
	var sect := _make_sect(1, 0)
	assert_eq(sect.current_year(), 0)
	assert_eq(sect.current_season(), 0)
	for i in 5:
		sect.advance_xun()
	assert_eq(sect.xun, 5)
	assert_eq(sect.current_season(), 1, "第 5 旬属于第二季")
	for i in 7:
		sect.advance_xun()
	assert_eq(sect.current_year(), 1)
	assert_eq(sect.current_season(), 0)


func test_unplanned_disciples_rest() -> void:
	var sect := _make_sect(3, 4)
	for d in sect.disciples:
		d.stamina = 40
	var reports := sect.advance_xun()
	assert_eq(reports.size(), 4)
	for d in sect.disciples:
		assert_eq(d.stamina, 75)


func test_advance_reports_each_disciple() -> void:
	var sect := _make_sect(5, 3)
	var reports := sect.advance_xun(_plans_for(sect))
	assert_eq(reports.size(), 3)
	for r in reports:
		assert_true(r["report"]["trained"])


func test_whole_simulation_is_deterministic() -> void:
	var a := _make_sect(2025, 12)
	var b := _make_sect(2025, 12)
	for i in 60:
		a.advance_xun(_plans_for(a))
		b.advance_xun(_plans_for(b))
	for i in a.disciples.size():
		assert_eq(a.disciples[i].stats, b.disciples[i].stats, "弟子 %d 数值应一致" % i)
		assert_eq(a.disciples[i].xp, b.disciples[i].xp)
		assert_eq(a.disciples[i].stamina, b.disciples[i].stamina)


func test_five_years_of_training_makes_disciples_stronger() -> void:
	var sect := _make_sect(11, 10)
	var before := 0
	for d in sect.disciples:
		for s in Balance.TRAINABLE:
			before += d.stats[s]
	# 修炼 / 休息交替，避免体力长期见底
	for i in 5 * Balance.XUN_PER_YEAR:
		sect.advance_xun(_plans_for(sect) if i % 2 == 0 else {})
	var after := 0
	for d in sect.disciples:
		for s in Balance.TRAINABLE:
			after += d.stats[s]
			assert_lte(d.stats[s], Growth.skill_cap(d, s), "任何时候都不超过上限")
	assert_gt(after, before, "五年修炼后总属性应增长")
