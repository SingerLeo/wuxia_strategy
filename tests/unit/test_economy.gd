extends GutTest
## 银两收支、建筑效果、底蕴来源、购置与升级。

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1


func _sect(disciple_count: int = 0) -> Sect:
	var s := Sect.new("测试派", rng)
	for i in disciple_count:
		s.add_disciple(DiscipleFactory.create(rng, i))
	return s


# --- 收入与支出 ---

func test_estate_income_sums_owned_estates() -> void:
	var s := _sect()
	assert_eq(Economy.estate_income(s), 0)
	s.estates[&"farm"] = 2
	s.estates[&"shop"] = 1
	assert_eq(Economy.estate_income(s), 2 * 9 + 20)


func test_disciples_cost_upkeep_each() -> void:
	var s := _sect(5)
	assert_eq(Economy.disciple_upkeep(s), 5 * Catalog.DISCIPLE_UPKEEP)


func test_building_upkeep_depends_on_level() -> void:
	var s := _sect()
	assert_eq(Economy.building_upkeep(s), 0)
	s.buildings[&"dojo"] = 1
	assert_eq(Economy.building_upkeep(s), 3)
	s.buildings[&"dojo"] = 3
	s.buildings[&"clinic"] = 2
	assert_eq(Economy.building_upkeep(s), 10 + 4)


func test_net_and_runway() -> void:
	var s := _sect(10)             # 养育 20
	s.estates[&"farm"] = 1         # 收入 9
	s.silver = 110
	assert_eq(Economy.net_per_xun(s), -11)
	assert_eq(Economy.runway(s), 10, "110 / 11 = 10 旬")
	s.estates[&"farm"] = 3         # 收入 27 > 支出 20
	assert_eq(Economy.runway(s), -1, "收支为正则不会耗尽")


# --- 每旬结算 ---

func test_advance_xun_applies_income_and_upkeep() -> void:
	var s := _sect(3)              # 养育 6
	s.estates[&"farm"] = 2         # 收入 18
	s.buildings[&"dojo"] = 1       # 维护 3
	s.silver = 100
	s.advance_xun()
	assert_eq(s.silver, 100 + 18 - 6 - 3)
	assert_eq(s.last_settlement["income"], 18)
	assert_eq(s.last_settlement["upkeep_disciples"], 6)
	assert_eq(s.last_settlement["upkeep_buildings"], 3)
	assert_eq(s.last_settlement["shortfall"], 0)


func test_silver_never_goes_negative_and_shortfall_is_reported() -> void:
	var s := _sect(10)             # 养育 20，无收入
	s.silver = 5
	s.advance_xun()
	assert_eq(s.silver, 0)
	assert_eq(s.last_settlement["shortfall"], 15)


# --- 底蕴 ---

func test_legacy_comes_from_disciples_training_xp() -> void:
	var s := _sect(0)
	var d := Disciple.new()
	d.potential = 100
	d.age_xun = 20 * Balance.XUN_PER_YEAR
	s.add_disciple(d)
	s.advance_xun({d.id: TrainingPlan.train(&"jian")})
	var expected := roundi(s.last_settlement["legacy_gain"])
	assert_gt(expected, 0, "有人修炼就有底蕴产出")
	assert_eq(s.legacy, expected)


func test_resting_disciples_produce_no_legacy() -> void:
	var s := _sect(4)
	s.advance_xun()
	assert_eq(s.legacy, 0)
	assert_eq(s.last_settlement["legacy_gain"], 0)


func test_gaining_prestige_converts_to_legacy_losing_does_not() -> void:
	var s := _sect()
	s.change_prestige(40)
	assert_eq(s.legacy, 40)
	s.change_prestige(-25)
	assert_eq(s.legacy, 40, "失去威望不扣底蕴")
	s.change_prestige(10)
	assert_eq(s.legacy, 50)


func test_library_boosts_legacy_gain() -> void:
	var s := _sect()
	s.buildings[&"library"] = 2    # +30%
	s.change_prestige(100)
	assert_eq(s.legacy, 130)


# --- 建筑效果 ---

func test_dojo_speeds_up_training() -> void:
	var plain := _sect()
	var upgraded := _sect()
	upgraded.buildings[&"dojo"] = 3  # +30%
	var a := Disciple.new()
	var b := Disciple.new()
	for d in [a, b]:
		d.potential = 100
		d.age_xun = 20 * Balance.XUN_PER_YEAR
	plain.add_disciple(a)
	upgraded.add_disciple(b)
	# 比较"本旬获得的经验"，而不是剩余经验（一次修炼可能连升几级）
	var gain_plain: float = plain.advance_xun({a.id: TrainingPlan.train(&"jian")})[0]["report"]["xp"]
	var gain_upgraded: float = upgraded.advance_xun({b.id: TrainingPlan.train(&"jian")})[0]["report"]["xp"]
	assert_gt(gain_plain, 0.0)
	assert_almost_eq(gain_upgraded, gain_plain * 1.3, 0.001)


func test_clinic_speeds_up_resting() -> void:
	var s := _sect()
	s.buildings[&"clinic"] = 2  # 每级 +5
	var d := Disciple.new()
	d.stamina = 40
	s.add_disciple(d)
	s.advance_xun()
	assert_eq(d.stamina, 40 + Balance.REST_STAMINA_GAIN + 10)


# --- 购置与升级（Game） ---

func _game() -> Node:
	var g: Node = load("res://src/game/game.gd").new()
	add_child_autofree(g)
	g.new_game(1)
	return g


func test_new_game_starts_with_two_farms() -> void:
	var g := _game()
	assert_eq(g.sect.estate_count(&"farm"), 2)
	assert_eq(g.sect.silver, Catalog.START_SILVER)


func test_buy_estate_spends_silver_and_adds_one() -> void:
	var g := _game()
	var before: int = g.sect.silver
	assert_true(g.buy_estate(&"shop"))
	assert_eq(g.sect.silver, before - 600)
	assert_eq(g.sect.estate_count(&"shop"), 1)


func test_buy_estate_fails_without_silver_or_at_max() -> void:
	var g := _game()
	g.sect.silver = 100
	assert_false(g.buy_estate(&"farm"), "银两不足")
	g.sect.silver = 100000
	for i in 4:
		g.buy_estate(&"farm")        # 已有 2，再买 4 → 6（上限）
	assert_eq(g.sect.estate_count(&"farm"), 6)
	var silver: int = g.sect.silver
	assert_false(g.buy_estate(&"farm"), "已达上限")
	assert_eq(g.sect.silver, silver, "失败时不扣钱")
	assert_false(g.buy_estate(&"nope"), "未知产业")


func test_upgrade_building_levels_up_and_costs_silver() -> void:
	var g := _game()
	g.sect.silver = 5000
	assert_true(g.upgrade_building(&"dojo"))
	assert_eq(g.sect.building_level(&"dojo"), 1)
	assert_eq(g.sect.silver, 5000 - 200)
	assert_true(g.upgrade_building(&"dojo"))
	assert_eq(g.sect.building_level(&"dojo"), 2)
	assert_eq(g.sect.silver, 5000 - 200 - 400)


func test_upgrade_building_stops_at_max_level_and_when_poor() -> void:
	var g := _game()
	g.sect.silver = 10
	assert_false(g.upgrade_building(&"dojo"), "银两不足")
	g.sect.silver = 1000000
	for i in 10:
		g.upgrade_building(&"dojo")
	assert_eq(g.sect.building_level(&"dojo"), Economy.building_max_level(&"dojo"))
	assert_eq(Economy.next_building_cost(&"dojo", 5), -1)


func test_end_xun_logs_settlement_and_warns_on_shortfall() -> void:
	var g := _game()
	g.sect.silver = 0
	g.sect.estates.clear()
	var lines: Array[String] = []
	g.log_added.connect(func(t: String) -> void: lines.append(t))
	g.end_xun()
	var text := "\n".join(lines)
	assert_string_contains(text, "本旬收入 0")
	assert_string_contains(text, "银两不足")


func test_reminder_when_silver_runs_low() -> void:
	var g := _game()
	g.sect.estates.clear()                  # 无收入，养育 12×2 = 24/旬
	g.sect.silver = 100                     # 够撑 4 旬
	var found := false
	for line in g.reminders():
		if "入不敷出" in line:
			found = true
	assert_true(found)


func test_estates_and_buildings_survive_save_and_load() -> void:
	var g := _game()
	g.sect.silver = 5000
	g.buy_estate(&"shop")
	g.upgrade_building(&"library")
	var back := Sect.from_dict(g.sect.to_dict())
	assert_eq(back.estate_count(&"shop"), 1)
	assert_eq(back.estate_count(&"farm"), 2)
	assert_eq(back.building_level(&"library"), 1)
