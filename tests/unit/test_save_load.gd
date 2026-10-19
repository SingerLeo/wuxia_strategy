extends GutTest
## 存档/读档（H 类）：序列化往返、版本校验、自动存档。

const TEST_SAVE := "user://test_save_load.json"

var game: Node


func before_each() -> void:
	game = load("res://src/game/game.gd").new()
	add_child_autofree(game)
	game.saver = SaveSystem.new(TEST_SAVE)
	game.saver.clear()
	game.new_game(1)


func after_each() -> void:
	game.saver.clear()


func test_no_save_means_load_fails() -> void:
	assert_false(game.has_save())
	assert_false(game.load_game())


func test_end_xun_autosaves() -> void:
	game.end_xun()
	assert_true(game.has_save(), "每旬结束应自动存档")


func test_save_load_round_trip() -> void:
	game.set_plan(0, &"neigong")
	game.end_xun()
	game.end_xun()
	game.recruit(game.candidates[0].id)
	assert_true(game.save_game())

	var xun: int = game.sect.xun
	var silver: int = game.sect.silver
	var names: Array = game.sect.disciples.map(func(d: Disciple) -> String: return d.display_name)
	var candidate_count: int = game.candidates.size()
	var next_id: int = game._next_id
	var rng_state := str(game.sect.rng.state)

	game.new_game(9)  # 换一个完全不同的局面
	assert_ne(game.sect.disciples.size(), names.size())

	assert_true(game.load_game())
	assert_eq(game.sect.xun, xun)
	assert_eq(game.sect.silver, silver)
	assert_eq(game.sect.disciples.map(func(d: Disciple) -> String: return d.display_name), names)
	assert_eq(game.candidates.size(), candidate_count)
	assert_eq(game._next_id, next_id)
	assert_eq(game.plan_of(0), &"neigong", "修炼安排也要还原")
	assert_eq(str(game.sect.rng.state), rng_state, "随机数状态也要还原（读档后走势不变）")


func test_disciple_fields_survive_round_trip() -> void:
	game.end_xun()
	game.save_game()
	var before: Disciple = game.sect.disciples[3]
	var snap := {
		"skills": before.skills.duplicate(), "attributes": before.attributes.duplicate(),
		"xp": before.xp.duplicate(), "traits": before.traits.duplicate(),
		"potential": before.potential, "curve": before.curve, "age_xun": before.age_xun,
		"stamina": before.stamina, "loyalty": before.loyalty, "mood": before.mood,
	}
	game.new_game(9)
	game.load_game()
	var after: Disciple = game.find_disciple(before.id)
	assert_not_null(after)
	assert_eq(after.skills, snap["skills"])
	assert_eq(after.attributes, snap["attributes"])
	assert_eq(after.traits, snap["traits"])
	assert_eq(after.potential, snap["potential"])
	assert_eq(after.curve, snap["curve"])
	assert_eq(after.age_xun, snap["age_xun"])
	assert_eq(after.stamina, snap["stamina"])
	assert_eq(after.loyalty, snap["loyalty"])
	assert_almost_eq(float(after.xp[&"neigong"]), float(snap["xp"][&"neigong"]), 0.0001)


func test_version_mismatch_is_rejected() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999}))
	f.close()
	assert_false(game.load_game(), "版本不符的存档应被拒绝")


func test_corrupt_file_is_rejected() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("这不是 JSON")
	f.close()
	assert_false(game.load_game())
