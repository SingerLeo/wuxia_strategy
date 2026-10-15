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
		plans[d.id] = TrainingPlan.train(Balance.STATS[d.id % Balance.STATS.size()])
	return plans


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
		assert_eq(a.disciples[i].stats, b.disciples[i].stats, "弟子 %d 属性应一致" % i)
		assert_eq(a.disciples[i].xp, b.disciples[i].xp)
		assert_eq(a.disciples[i].stamina, b.disciples[i].stamina)


func test_five_years_of_training_makes_disciples_stronger() -> void:
	var sect := _make_sect(11, 10)
	var before := 0
	for d in sect.disciples:
		for s in Balance.STATS:
			before += d.stats[s]
	# 修炼 / 休息交替，避免体力长期见底
	for i in 5 * Balance.XUN_PER_YEAR:
		sect.advance_xun(_plans_for(sect) if i % 2 == 0 else {})
	var after := 0
	for d in sect.disciples:
		for s in Balance.STATS:
			after += d.stats[s]
			assert_lte(d.stats[s], Growth.stat_cap(d, s), "任何时候都不超过上限")
	assert_gt(after, before, "五年修炼后总属性应增长")
