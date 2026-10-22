class_name DiscipleFactory
extends RefCounted
## 生成新弟子。所有随机都来自传入的 rng，同一种子结果可复现。
## boost：质量加成（加在基本功、先天上限与潜力的生成均值上），用于威望影响招生质量，见 Recruitment。


static func create(rng: RandomNumberGenerator, id: int, display_name: String = "", boost: float = 0.0) -> Disciple:
	var d := Disciple.new()
	d.id = id
	d.display_name = display_name if display_name != "" else "弟子%d" % id

	# 生成顺序有依赖：根骨/心智 → 基本功（看根骨、定力）→ 武学（看基本功、智谋）
	for k in Balance.MATURING:
		d.innate[k] = clampi(roundi(rng.randfn(Balance.INNATE_MEAN + boost, Balance.INNATE_DEV)), Balance.STAT_MIN, Balance.STAT_MAX)
		d.stats[k] = maxi(Balance.STAT_MIN, roundi(d.innate[k] * Balance.INNATE_START_RATIO))
	d.potential = clampi(roundi(rng.randfn(Balance.POTENTIAL_MEAN + boost, Balance.POTENTIAL_DEV)), Balance.POTENTIAL_MIN, Balance.STAT_MAX)
	d.curve = rng.randi_range(0, Disciple.GrowthCurve.size() - 1) as Disciple.GrowthCurve

	for k in Balance.BASICS:
		if Balance.TRAINABLE.has(k):
			var raw := roundi(rng.randfn(Balance.BASICS_MEAN + boost, Balance.BASICS_DEV))
			d.stats[k] = clampi(raw, Balance.STAT_MIN, Growth.skill_cap(d, k))

	# 武学：随机 N 项"入门所学"较高，其余只是略知皮毛
	var pool: Array = Balance.MARTIAL.duplicate()
	var starters: Array[StringName] = []
	for i in Balance.STARTER_SKILLS:
		var idx := rng.randi_range(0, pool.size() - 1)
		starters.append(pool[idx])
		pool.remove_at(idx)
	for s in Balance.MARTIAL:
		var related: int = d.stats[Balance.RELATED[s]]
		var ratio := Balance.INITIAL_MAJOR_RATIO if starters.has(s) else Balance.INITIAL_MINOR_RATIO
		var raw := roundi(rng.randfn(related * ratio, Balance.INITIAL_SKILL_DEV))
		d.stats[s] = clampi(raw, Balance.STAT_MIN, Growth.skill_cap(d, s))

	var trait_pool: Array = Balance.TRAITS.duplicate()
	for i in 2:
		var idx := rng.randi_range(0, trait_pool.size() - 1)
		d.traits.append(trait_pool[idx])
		trait_pool.remove_at(idx)

	var age_years := rng.randi_range(Balance.RECRUIT_AGE_MIN, Balance.RECRUIT_AGE_MAX)
	d.age_xun = age_years * Balance.XUN_PER_YEAR + rng.randi_range(0, Balance.XUN_PER_YEAR - 1)
	d.loyalty = rng.randi_range(50, 70)
	d.hp = Growth.max_hp(d)
	d.neili = Growth.max_neili(d)
	return d
