extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_same_seed_gives_same_disciple() -> void:
	var a := DiscipleFactory.create(_rng(42), 1)
	var b := DiscipleFactory.create(_rng(42), 1)
	assert_eq(a.aptitudes, b.aptitudes)
	assert_eq(a.stats, b.stats)
	assert_eq(a.potential, b.potential)
	assert_eq(a.traits, b.traits)
	assert_eq(a.age_xun, b.age_xun)


func test_generated_values_are_in_range() -> void:
	var rng := _rng(7)
	for i in 300:
		var d := DiscipleFactory.create(rng, i)
		for a in Balance.APTITUDES:
			assert_between(d.aptitudes[a], Balance.STAT_MIN, Balance.STAT_MAX)
		assert_between(d.potential, Balance.POTENTIAL_MIN, Balance.STAT_MAX)
		for s in Balance.STATS:
			assert_between(d.stats[s], Balance.STAT_MIN, Growth.stat_cap(d, s), "初始属性不应超过上限")
		assert_eq(d.traits.size(), 2)
		assert_ne(d.traits[0], d.traits[1], "性格词条不重复")
		assert_between(d.age_years(), float(Balance.RECRUIT_AGE_MIN), Balance.RECRUIT_AGE_MAX + 1.0)


func test_average_new_disciple_is_modest() -> void:
	var rng := _rng(2024)
	var total := 0.0
	var n := 400
	for i in n:
		var d := DiscipleFactory.create(rng, i)
		for s in Balance.STATS:
			total += d.stats[s]
	var mean := total / (n * Balance.STATS.size())
	assert_between(mean, 20.0, 40.0, "新弟子平均属性应在 20~40（设计文档为 25~40）")


func test_default_name() -> void:
	assert_eq(DiscipleFactory.create(_rng(1), 5).display_name, "弟子5")
	assert_eq(DiscipleFactory.create(_rng(1), 5, "令狐冲").display_name, "令狐冲")
