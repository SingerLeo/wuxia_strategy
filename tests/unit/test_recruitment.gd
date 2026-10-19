extends GutTest
## 招收：候选人生成、声望影响质量、要价、招收/婉拒、季节刷新。

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1
	Game.new_game(1)


func test_new_game_has_a_batch_of_candidates() -> void:
	assert_eq(Game.candidates.size(), Recruitment.CANDIDATES_PER_SEASON)


func test_asking_price_is_base_plus_potential() -> void:
	var d := Disciple.new()
	d.potential = 60
	assert_eq(Recruitment.asking_price(d), 40 + 60)


func test_prestige_raises_candidate_quality() -> void:
	var r1 := RandomNumberGenerator.new()
	r1.seed = 7
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	var plain := 0.0
	var famed := 0.0
	var n := 200
	for i in n:
		var a := Recruitment.generate(r1, 0, i * 3)[0]
		var b := Recruitment.generate(r2, 100, i * 3)[0]
		plain += a.potential
		famed += b.potential
	assert_gt(famed / n - plain / n, 10.0, "声望 100 的候选人平均潜力应明显更高")


func test_recruit_spends_silver_and_joins_sect() -> void:
	var c: Disciple = Game.candidates[0]
	var price := Recruitment.asking_price(c)
	var silver_before: int = Game.sect.silver
	var size_before := Game.sect.disciples.size()
	assert_true(Game.recruit(c.id))
	assert_eq(Game.sect.silver, silver_before - price)
	assert_eq(Game.sect.disciples.size(), size_before + 1)
	assert_eq(Game.find_disciple(c.id), c, "招收后能在名册中找到")
	assert_eq(Game.candidates.size(), Recruitment.CANDIDATES_PER_SEASON - 1)


func test_recruit_fails_when_silver_short() -> void:
	Game.sect.silver = 1
	var c: Disciple = Game.candidates[0]
	assert_false(Game.recruit(c.id))
	assert_eq(Game.sect.silver, 1)
	assert_eq(Game.candidates.size(), Recruitment.CANDIDATES_PER_SEASON, "失败不应消耗候选人")


func test_decline_removes_candidate() -> void:
	var c: Disciple = Game.candidates[1]
	Game.decline(c.id)
	assert_eq(Game.candidates.size(), Recruitment.CANDIDATES_PER_SEASON - 1)
	assert_null(Game._find_candidate(c.id))


func test_candidates_refresh_each_season() -> void:
	var first_ids := Game.candidates.map(func(c: Disciple) -> int: return c.id)
	for i in Balance.XUN_PER_SEASON:
		Game.end_xun()
	assert_eq(Game.candidates.size(), Recruitment.CANDIDATES_PER_SEASON)
	for c in Game.candidates:
		assert_false(first_ids.has(c.id), "新季节应换一批候选人")


func test_recruited_ids_are_unique() -> void:
	for i in Balance.XUN_PER_SEASON:
		Game.end_xun()  # 过一季，候选人换一批
	var seen := {}
	for d in Game.sect.disciples:
		seen[d.id] = true
	var c: Disciple = Game.candidates[0]
	Game.recruit(c.id)
	assert_false(seen.has(c.id), "新弟子 id 不应与已有弟子冲突")
