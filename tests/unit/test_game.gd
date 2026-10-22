extends GutTest
## 测试 Game 的逻辑。用独立实例，不依赖全局 autoload 的状态。

var game: Node


func before_each() -> void:
	game = load("res://src/game/game.gd").new()
	add_child_autofree(game)
	game.saver = SaveSystem.new("user://test_saves_game")
	game.new_game(1)


func after_each() -> void:
	game.saver.clear_all()


func test_new_game_creates_initial_disciples() -> void:
	assert_eq(game.sect.disciples.size(), game.INITIAL_DISCIPLES)
	for d in game.sect.disciples:
		assert_ne(d.display_name, "")


func test_same_seed_same_names() -> void:
	var other: Node = load("res://src/game/game.gd").new()
	add_child_autofree(other)
	other.new_game(1)
	for i in game.sect.disciples.size():
		assert_eq(game.sect.disciples[i].display_name, other.sect.disciples[i].display_name)


func test_default_plan_is_rest() -> void:
	assert_eq(game.plan_of(0), &"")


func test_set_plan_emits_state_changed() -> void:
	watch_signals(game)
	game.set_plan(0, &"neigong")
	assert_eq(game.plan_of(0), &"neigong")
	assert_signal_emitted(game, "state_changed")


func test_end_xun_applies_plans_and_advances_time() -> void:
	game.set_plan(0, &"neigong")
	watch_signals(game)
	game.end_xun()
	assert_eq(game.sect.xun, 1)
	var d: Disciple = game.find_disciple(0)
	assert_eq(d.stamina, Balance.STAMINA_MAX - Growth.train_stamina_cost(d), "修炼的弟子消耗体力（多少看勤勉）")
	assert_eq(game.find_disciple(1).stamina, 100, "休息的弟子体力已满")
	assert_signal_emitted(game, "state_changed")
	assert_signal_emitted(game, "log_added")


func test_train_all_by_specialty_uses_top_skill_and_skips_tired() -> void:
	game.find_disciple(1).stamina = 10
	game.train_all_by_specialty()
	assert_eq(game.plan_of(0), UiText.top_skill(game.find_disciple(0)))
	assert_eq(game.plan_of(1), &"", "体力不足者休息")


func test_rest_all_clears_plans() -> void:
	game.train_all_by_specialty()
	game.rest_all()
	for d in game.sect.disciples:
		assert_eq(game.plan_of(d.id), &"")


func test_reminders_flag_idle_and_tired() -> void:
	var r: Array = game.reminders()
	assert_eq(r.size(), 1, "开局全员体力充沛且在休息，只提示闲着")
	game.find_disciple(0).stamina = 5
	assert_eq(game.reminders().size(), 2)
	game.find_disciple(0).stamina = 100
	game.train_all_by_specialty()
	assert_eq(game.reminders().size(), 0, "全部安排妥当则没有提醒")


func test_not_destroyed_at_start() -> void:
	assert_false(game.sect.is_destroyed())
	assert_false(game.over)


func test_sect_destroyed_when_no_disciples() -> void:
	game.sect.disciples.clear()
	assert_true(game.sect.is_destroyed())


func test_disbanding_everyone_ends_the_game() -> void:
	watch_signals(game)
	game.debug_disband_all()
	assert_true(game.over)
	assert_signal_emitted(game, "game_over")


func test_end_xun_does_nothing_after_game_over() -> void:
	game.debug_disband_all()
	var xun: int = game.sect.xun
	game.end_xun()
	assert_eq(game.sect.xun, xun)


func test_new_game_clears_game_over() -> void:
	game.debug_disband_all()
	game.new_game(2)
	assert_false(game.over)
	assert_eq(game.sect.disciples.size(), game.INITIAL_DISCIPLES)


func test_end_xun_detects_destruction() -> void:
	game.sect.disciples.clear()
	game.end_xun()
	assert_true(game.over)


func test_find_disciple() -> void:
	assert_eq(game.find_disciple(3).id, 3)
	assert_null(game.find_disciple(999))
