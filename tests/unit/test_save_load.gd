extends GutTest
## 存档/读档（H 类）：多槽位、序列化往返、版本校验、自动存档。

const TEST_DIR := "user://test_saves_save_load"

var game: Node


func before_each() -> void:
	game = load("res://src/game/game.gd").new()
	add_child_autofree(game)
	game.saver = SaveSystem.new(TEST_DIR)
	game.saver.clear_all()
	game.new_game(1)


func after_each() -> void:
	game.saver.clear_all()


func test_empty_slots_fail_to_load() -> void:
	for i in SaveSystem.SLOT_COUNT:
		assert_false(game.has_save(i))
		assert_false(game.load_from_slot(i))


func test_end_xun_autosaves_to_autosave_slot() -> void:
	game.end_xun()
	assert_true(game.saver.has_save(SaveSystem.AUTOSAVE))
	assert_false(game.has_save(0), "自动存档不占手动槽位")


func test_save_load_round_trip() -> void:
	game.assign(0, 2)
	var custom: Schedule = game.add_schedule("自定")
	game.set_schedule_slots(custom.id, &"yidu", 7)
	game.set_schedule_intensity(custom.id, Training.Intensity.HEAVY)
	game.assign(1, custom.id)
	game.end_xun()
	game.end_xun()
	game.recruit(game.candidates[0].id)
	assert_true(game.save_to_slot(1))

	var xun: int = game.sect.xun
	var silver: int = game.sect.silver
	var names: Array = game.sect.disciples.map(func(d: Disciple) -> String: return d.display_name)
	var candidate_count: int = game.candidates.size()
	var next_id: int = game._next_id
	var rng_state := str(game.sect.rng.state)

	game.new_game(9)  # 换一个完全不同的局面
	assert_ne(game.sect.disciples.size(), names.size())

	assert_true(game.load_from_slot(1))
	assert_eq(game.sect.xun, xun)
	assert_eq(game.sect.silver, silver)
	assert_eq(game.sect.disciples.map(func(d: Disciple) -> String: return d.display_name), names)
	assert_eq(game.candidates.size(), candidate_count)
	assert_eq(game._next_id, next_id)
	assert_eq(game.schedule_of(0), 2, "日程指派也要还原")
	assert_eq(game.schedule_of(1), custom.id)
	var loaded: Schedule = game.find_schedule(custom.id)
	assert_eq(loaded.schedule_name, "自定")
	assert_eq(loaded.slots_of(&"yidu"), 7)
	assert_eq(loaded.intensity, Training.Intensity.HEAVY)
	assert_eq(game.add_schedule().id, custom.id + 1, "新日程 id 接着往后排")
	assert_eq(str(game.sect.rng.state), rng_state, "随机数状态也要还原（读档后走势不变）")


func test_slots_are_independent() -> void:
	game.end_xun()
	game.save_to_slot(0)
	var xun_slot0: int = game.sect.xun
	for i in 3:
		game.end_xun()
	game.save_to_slot(2)

	game.load_from_slot(0)
	assert_eq(game.sect.xun, xun_slot0, "槽位 1 是先存的局面")
	game.load_from_slot(2)
	assert_eq(game.sect.xun, xun_slot0 + 3, "槽位 3 是后存的局面")


func test_saving_overwrites_slot() -> void:
	game.save_to_slot(0)
	game.end_xun()
	game.end_xun()
	game.save_to_slot(0)
	game.load_from_slot(0)
	assert_eq(game.sect.xun, 2, "后存的覆盖了先存的")


func test_slot_info_summarizes_save() -> void:
	game.end_xun()
	game.end_xun()
	game.save_to_slot(2)
	var info: Dictionary = game.saver.info(2)
	assert_eq(info["sect_name"], "青云门")
	assert_eq(info["xun"], 2)
	assert_eq(info["disciples"], 12)
	assert_ne(info["saved_at"], "", "应记录保存时间")
	assert_eq(game.saver.info(1), {}, "空槽位没有摘要")


func test_slot_infos_lists_autosave_first() -> void:
	game.end_xun()  # 自动存档
	game.save_to_slot(0)
	var infos: Array = game.slot_infos()
	assert_eq(infos.size(), SaveSystem.SLOT_COUNT + 1)
	assert_false(infos[0].is_empty(), "第一位是自动存档")
	assert_false(infos[1].is_empty())
	assert_eq(infos[2], {})


func test_version_mismatch_is_rejected() -> void:
	var f := FileAccess.open(game.saver.slot_path(0), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999}))
	f.close()
	assert_false(game.load_from_slot(0), "版本不符的存档应被拒绝")


func test_corrupt_file_is_rejected() -> void:
	var f := FileAccess.open(game.saver.slot_path(0), FileAccess.WRITE)
	f.store_string("这不是 JSON")
	f.close()
	assert_false(game.load_from_slot(0))
