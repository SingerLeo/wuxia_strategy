class_name DiscipleFactory
extends RefCounted
## 生成新弟子。所有随机都来自传入的 rng，同一种子结果可复现。


static func create(rng: RandomNumberGenerator, id: int, display_name: String = "") -> Disciple:
	var d := Disciple.new()
	d.id = id
	d.display_name = display_name if display_name != "" else "弟子%d" % id

	for a in Balance.APTITUDES:
		d.aptitudes[a] = clampi(roundi(rng.randfn(Balance.APTITUDE_MEAN, Balance.APTITUDE_DEV)), Balance.STAT_MIN, Balance.STAT_MAX)
	d.potential = clampi(roundi(rng.randfn(Balance.POTENTIAL_MEAN, Balance.POTENTIAL_DEV)), Balance.POTENTIAL_MIN, Balance.STAT_MAX)
	d.curve = rng.randi_range(0, Disciple.GrowthCurve.size() - 1) as Disciple.GrowthCurve

	for s in Balance.STATS:
		var apt: int = d.aptitudes[Balance.STAT_APTITUDE[s]]
		var raw := roundi(rng.randfn(apt * Balance.INITIAL_STAT_RATIO, Balance.INITIAL_STAT_DEV))
		d.stats[s] = clampi(raw, Balance.STAT_MIN, Growth.stat_cap(d, s))

	var pool: Array = Balance.TRAITS.duplicate()
	for i in 2:
		var idx := rng.randi_range(0, pool.size() - 1)
		d.traits.append(pool[idx])
		pool.remove_at(idx)

	var age_years := rng.randi_range(Balance.RECRUIT_AGE_MIN, Balance.RECRUIT_AGE_MAX)
	d.age_xun = age_years * Balance.XUN_PER_YEAR + rng.randi_range(0, Balance.XUN_PER_YEAR - 1)
	d.loyalty = rng.randi_range(50, 70)
	return d
