extends GutTest
## 界面外壳的冒烟测试：能创建、能切换页面、名册与 Game 数据一致。

var main: Control


func before_each() -> void:
	Game.saver = SaveSystem.new("user://test_saves_ui")
	Game.new_game(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await get_tree().process_frame


func after_each() -> void:
	Game.saver.clear_all()


func test_has_all_pages() -> void:
	assert_eq(main.page_count(), 7)


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


func test_roster_sorting_toggles_direction() -> void:
	main.show_page(1)
	var roster: RosterPage = main.get_page(1)
	Game.sect.disciples[0].stamina = 10
	Game.sect.disciples[1].stamina = 90
	roster.sort_by(3)  # 体力升序
	var asc := roster.row_ids()
	assert_eq(asc[0], Game.sect.disciples[0].id, "体力最低的排最前")
	roster.sort_by(3)  # 再点：降序
	var desc := roster.row_ids()
	assert_eq(desc[desc.size() - 1], asc[0], "降序时最低体力排最后")


func test_roster_batch_buttons_change_plans() -> void:
	main.show_page(1)
	Game.train_all_by_specialty()
	assert_ne(Game.schedule_of(0), Game.REST)
	Game.rest_all()
	assert_eq(Game.schedule_of(0), Game.REST)


func test_space_ends_the_xun() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	main._unhandled_key_input(ev)
	assert_eq(Game.sect.xun, 1)


func test_locked_nav_entries_are_disabled_and_not_pages() -> void:
	assert_eq(main.page_count(), 7, "江湖/事件只是锁定的导航项，不算页面")


func test_detail_shows_six_axis_radar_for_selected_disciple() -> void:
	main.show_page(1)
	var radar: RadarChart = (main.get_page(1) as RosterPage).radar()
	assert_not_null(radar)
	assert_eq(radar.axis_count(), 6)
	for v in radar.values():
		assert_between(v, 0.0, 1.0)


func test_game_over_overlay_shows_and_restart_hides() -> void:
	assert_false(main.overlay_visible())
	Game.debug_disband_all()
	assert_true(main.overlay_visible())
	main.show_page(1)  # 名册为空时切换页面也不应报错
	Game.new_game(3)
	assert_false(main.overlay_visible())


func test_end_xun_updates_pages_without_error() -> void:
	main.show_page(1)
	Game.assign(0, 0)
	Game.end_xun()
	assert_eq(Game.sect.xun, 1)
	assert_eq((main.get_page(1) as RosterPage).row_count(), Game.sect.disciples.size())


func test_recruit_page_lists_candidates() -> void:
	main.show_page(3)
	var page: RecruitPage = main.get_page(3)
	assert_eq(page.candidate_count(), Game.candidates.size())


func test_recruit_from_page_adds_to_roster() -> void:
	main.show_page(3)
	var page: RecruitPage = main.get_page(3)
	var id: int = Game.candidates[0].id
	Game.recruit(id)
	main.show_page(1)
	var roster := main.get_page(1) as RosterPage
	assert_eq(roster.row_count(), Game.sect.disciples.size())
	var ids := roster.row_ids()
	assert_true(ids.has(id), "新弟子应出现在名册里")


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func test_escape_toggles_menu() -> void:
	assert_false(main.menu_visible())
	main._unhandled_key_input(_key(KEY_ESCAPE))
	assert_true(main.menu_visible())
	main._unhandled_key_input(_key(KEY_ESCAPE))
	assert_false(main.menu_visible())


func test_space_does_not_advance_while_menu_open() -> void:
	main._unhandled_key_input(_key(KEY_ESCAPE))
	main._unhandled_key_input(_key(KEY_SPACE))
	assert_eq(Game.sect.xun, 0, "菜单打开时空格不应结束本旬")


func test_saveload_panel_shows_all_slots() -> void:
	main._saveload.refresh()
	var rows: Array[Node] = main._saveload._rows.get_children()
	assert_eq(rows.size(), SaveSystem.SLOT_COUNT + 1, "自动存档 + 全部手动槽位")
	for row in rows:
		var hbox: Node = row.get_child(0)
		var load_btn := hbox.get_child(hbox.get_child_count() - 1) as Button
		assert_true(load_btn.disabled, "空槽位的读取按钮应禁用")


func test_escape_closes_saveload_before_menu() -> void:
	main._saveload.visible = true
	main._unhandled_key_input(_key(KEY_ESCAPE))
	assert_false(main._saveload.visible)
	assert_false(main.menu_visible(), "Esc 先关存档面板，而不是开菜单")


func test_training_page_edits_schedule_and_lists_disciples() -> void:
	main.show_page(2)
	var page: TrainingPage = main.get_page(2)
	assert_eq(page.selected_schedule(), Game.schedules[0].id, "默认选中第一个日程")
	assert_eq(page.assignment_rows(), Game.sect.disciples.size())
	var s: Schedule = Game.add_schedule("新")
	page.select_schedule(s.id)
	assert_eq(page.selected_schedule(), s.id)
	page._on_slots_changed(8.0, &"jianshu")
	assert_eq(s.slots_of(&"jianshu"), 8)
	Game.remove_schedule(s.id)
	assert_eq(page.selected_schedule(), Game.schedules[0].id, "所选日程被删后改选第一个")
