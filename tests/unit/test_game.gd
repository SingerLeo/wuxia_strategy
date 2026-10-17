extends GutTest
## 测试 Game 的逻辑。用独立实例，不依赖全局 autoload 的状态。

var game: Node


func before_each() -> void:
	game = load("res://src/game/game.gd").new()
	add_child_autofree(game)
	game.new_game(1)


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
	game.set_plan(0, &"neili")
	assert_eq(game.plan_of(0), &"neili")
	assert_signal_emitted(game, "state_changed")


func test_end_xun_applies_plans_and_advances_time() -> void:
	game.set_plan(0, &"neili")
	watch_signals(game)
	game.end_xun()
	assert_eq(game.sect.xun, 1)
	assert_eq(game.find_disciple(0).stamina, 80, "修炼的弟子消耗体力")
	assert_eq(game.find_disciple(1).stamina, 100, "休息的弟子体力已满")
	assert_signal_emitted(game, "state_changed")
	assert_signal_emitted(game, "log_added")


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
