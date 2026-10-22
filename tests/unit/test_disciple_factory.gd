extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_same_seed_gives_same_disciple() -> void:
	var a := DiscipleFactory.create(_rng(42), 1)
	var b := DiscipleFactory.create(_rng(42), 1)
	assert_eq(a.stats, b.stats)
	assert_eq(a.innate, b.innate)
	assert_eq(a.potential, b.potential)
	assert_eq(a.traits, b.traits)
	assert_eq(a.age_xun, b.age_xun)


func test_generated_values_are_in_range() -> void:
	var rng := _rng(7)
	for i in 300:
		var d := DiscipleFactory.create(rng, i)
		assert_eq(d.stats.size(), 24, "武学、基本功、心智各 8 项")
		for k in d.stats:
			assert_between(d.stats[k], Balance.STAT_MIN, Balance.STAT_MAX)
		assert_between(d.potential, Balance.POTENTIAL_MIN, Balance.STAT_MAX)
		for s in Balance.TRAINABLE:
			assert_between(d.stats[s], Balance.STAT_MIN, Growth.skill_cap(d, s), "初始值不应超过上限")
		for k in Balance.MATURING:
			assert_lte(d.stats[k], d.innate[k], "根骨与心智入门时不超过先天上限")
		assert_eq(d.traits.size(), 2)
		assert_ne(d.traits[0], d.traits[1], "性格词条不重复")
		assert_between(d.age_years(), float(Balance.RECRUIT_AGE_MIN), Balance.RECRUIT_AGE_MAX + 1.0)


func test_new_disciple_starts_with_full_hp_and_neili() -> void:
	var d := DiscipleFactory.create(_rng(5), 1)
	assert_eq(d.hp, Growth.max_hp(d))
	assert_eq(d.neili, Growth.max_neili(d))
	assert_eq(d.stamina, Balance.STAMINA_MAX)


func test_new_disciples_have_a_specialty_not_all_rounders() -> void:
	var rng := _rng(2024)
	var top_total := 0.0
	var all_total := 0.0
	var n := 400
	for i in n:
		var d := DiscipleFactory.create(rng, i)
		top_total += d.stats[UiText.top_skill(d)]
		for s in Balance.MARTIAL:
			all_total += d.stats[s]
	var top_mean := top_total / n
	var all_mean := all_total / (n * Balance.MARTIAL.size())
	assert_between(top_mean, 18.0, 40.0, "最擅长的一项应有一定基础")
	assert_between(all_mean, 5.0, 20.0, "整体武学平均应明显低于专长")
	assert_gt(top_mean, all_mean * 1.5, "有明显的专长，不是样样平均")


func test_default_name() -> void:
	assert_eq(DiscipleFactory.create(_rng(1), 5).display_name, "弟子5")
	assert_eq(DiscipleFactory.create(_rng(1), 5, "令狐冲").display_name, "令狐冲")


func test_categories_are_eight_each_and_disjoint() -> void:
	assert_eq(Balance.MARTIAL.size(), 8)
	assert_eq(Balance.BASICS.size(), 8)
	assert_eq(Balance.MIND.size(), 8)
	var seen := {}
	for k in Balance.MARTIAL + Balance.BASICS + Balance.MIND:
		assert_false(seen.has(k), "%s 重复" % k)
		seen[k] = true
		assert_true(UiText.STAT.has(k), "%s 缺少显示名" % k)
	for k in Balance.TRAINABLE:
		assert_true(Balance.RELATED.has(k), "%s 缺少对应项" % k)
		assert_false(Balance.MIND.has(k), "心智不能修炼")
	assert_false(Balance.TRAINABLE.has(&"gengu"), "根骨不能修炼")
