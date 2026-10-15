extends GutTest
## 界面外壳的冒烟测试：能创建、能切换页面、名册与 Game 数据一致。

var main: Control


func before_each() -> void:
	Game.new_game(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await get_tree().process_frame


func test_has_all_pages() -> void:
	assert_eq(main.page_count(), 5)


func test_first_page_is_visible_and_only_one_nav_pressed() -> void:
	assert_true(main.get_page(0).visible)
	assert_false(main.get_page(1).visible)
	assert_eq(main.nav_pressed_count(), 1)


func test_switching_pages() -> void:
	main.show_page(1)
	assert_true(main.get_page(1).visible)
	assert_false(main.get_page(0).visible)
	assert_eq(main.nav_pressed_count(), 1, "切换后仍只有一个导航按钮处于按下状态")


func test_roster_lists_all_disciples_and_selects_first() -> void:
	main.show_page(1)
	var roster: RosterPage = main.get_page(1)
	assert_eq(roster.row_count(), Game.sect.disciples.size())
	assert_eq(roster.selected_id(), Game.sect.disciples[0].id)


func test_end_xun_updates_pages_without_error() -> void:
	main.show_page(1)
	Game.set_plan(0, &"neili")
	Game.end_xun()
	assert_eq(Game.sect.xun, 1)
	assert_eq((main.get_page(1) as RosterPage).row_count(), Game.sect.disciples.size())
