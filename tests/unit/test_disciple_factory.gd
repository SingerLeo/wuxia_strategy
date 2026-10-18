extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_same_seed_gives_same_disciple() -> void:
	var a := DiscipleFactory.create(_rng(42), 1)
	var b := DiscipleFactory.create(_rng(42), 1)
	assert_eq(a.attributes, b.attributes)
	assert_eq(a.skills, b.skills)
	assert_eq(a.potential, b.potential)
	assert_eq(a.traits, b.traits)
	assert_eq(a.age_xun, b.age_xun)


func test_generated_values_are_in_range() -> void:
	var rng := _rng(7)
	for i in 300:
		var d := DiscipleFactory.create(rng, i)
		for a in Balance.ATTRIBUTES:
			assert_between(d.attributes[a], Balance.STAT_MIN, Balance.STAT_MAX)
		assert_between(d.potential, Balance.POTENTIAL_MIN, Balance.STAT_MAX)
		for s in Balance.SKILLS:
			assert_between(d.skills[s], Balance.STAT_MIN, Growth.skill_cap(d, s), "初始技能不应超过上限")
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
		top_total += d.skills[UiText.top_skill(d)]
		for s in Balance.SKILLS:
			all_total += d.skills[s]
	var top_mean := top_total / n
	var all_mean := all_total / (n * Balance.SKILLS.size())
	assert_between(top_mean, 18.0, 40.0, "最擅长的一项应有一定基础")
	assert_between(all_mean, 5.0, 20.0, "整体技能平均应明显低于专长")
	assert_gt(top_mean, all_mean * 1.5, "有明显的专长，不是样样平均")


func test_default_name() -> void:
	assert_eq(DiscipleFactory.create(_rng(1), 5).display_name, "弟子5")
	assert_eq(DiscipleFactory.create(_rng(1), 5, "令狐冲").display_name, "令狐冲")
