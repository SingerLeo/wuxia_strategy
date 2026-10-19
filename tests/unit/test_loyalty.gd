extends GutTest
## 忠诚与去留：心情/忠诚的旬结算、叛门判定与提醒。

var rng: RandomNumberGenerator
var game: Node


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1
	game = load("res://src/game/game.gd").new()
	add_child_autofree(game)
	game.saver = SaveSystem.new("user://test_loyalty_save.json")
	game.new_game(1)


func after_each() -> void:
	game.saver.clear()


func _disciple(mood_value: int = 70, loyalty_value: int = 60) -> Disciple:
	var d := Disciple.new()
	d.mood = mood_value
	d.loyalty = loyalty_value
	return d


func test_level_up_improves_mood_and_loyalty() -> void:
	var d := _disciple()
	Growth.settle_xun(d, TrainingPlan.train(&"neigong"), rng)  # 标准弟子 1 旬升 1 级
	assert_eq(d.mood, 70 + Balance.MOOD_LEVEL_UP)
	assert_eq(d.loyalty, 60 + Balance.LOYALTY_LEVEL_UP)


func test_overwork_reduces_mood_and_loyalty() -> void:
	var d := _disciple()
	d.stamina = 20  # 低于 LOW_STAMINA 仍修炼
	Growth.settle_xun(d, TrainingPlan.train(&"neigong"), rng)
	assert_eq(d.mood, 70 + Balance.MOOD_OVERWORK)
	assert_eq(d.loyalty, 60 + Balance.LOYALTY_OVERWORK)


func test_rest_recovers_mood() -> void:
	var d := _disciple(50)
	Growth.settle_xun(d, null, rng)
	assert_eq(d.mood, 51)


func test_low_mood_drains_loyalty() -> void:
	var d := _disciple(20, 60)
	Growth.settle_xun(d, null, rng)  # 休息后心情 21，仍低于 LOW_MOOD
	assert_eq(d.loyalty, 60 + Balance.LOYALTY_LOW_MOOD)


func test_mood_and_loyalty_are_clamped() -> void:
	var d := _disciple(100, 1)
	d.stamina = 20
	Growth.settle_xun(d, TrainingPlan.train(&"neigong"), rng)
	assert_eq(d.mood, 97)
	assert_eq(d.loyalty, 0, "忠诚不会为负")


func test_defection_removes_disciple_and_plan() -> void:
	var d: Disciple = game.sect.disciples[0]
	d.loyalty = 0
	game.set_plan(d.id, &"")  # 休息：避免升级带来的忠诚回升干扰判定
	var size_before: int = game.sect.disciples.size()
	game.end_xun()
	assert_eq(game.sect.disciples.size(), size_before - 1)
	assert_null(game.find_disciple(d.id))
	assert_false(game.plans.has(d.id), "叛门者的安排应一并清除")


func test_everyone_defecting_ends_the_game() -> void:
	for d in game.sect.disciples:
		d.loyalty = 0
	watch_signals(game)
	game.end_xun()
	assert_true(game.over)
	assert_signal_emitted(game, "game_over")


func test_reminders_warn_about_low_loyalty() -> void:
	assert_eq(game.reminders().size(), 1, "开局只有闲着提醒")
	game.sect.disciples[0].loyalty = Balance.LOYALTY_WARN
	game.sect.disciples[1].loyalty = 0
	assert_eq(game.reminders().size(), 2, "新增忠诚提醒")


func test_report_carries_mood_and_loyalty() -> void:
	var d := _disciple()
	var report := Growth.settle_xun(d, null, rng)
	assert_eq(report["mood"], d.mood)
	assert_eq(report["loyalty"], d.loyalty)
