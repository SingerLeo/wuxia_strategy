extends GutTest
## 建筑页的交互：选址摆放、旋转、取消、移动、拆除二次确认、悬停预览。
## 用页面的公开方法模拟鼠标操作（begin_place / click_cell / hover_cell …）。

var main: Control
var page: BuildingPage


func before_each() -> void:
	Game.new_game(1)
	Game.sect.silver = 10000
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	page = null
	for i in main.page_count():
		if main.get_page(i) is BuildingPage:
			page = main.get_page(i)
			main.show_page(i)
	assert_not_null(page, "主界面里应当有建筑页")


func test_begin_place_refuses_when_poor() -> void:
	Game.sect.silver = 10
	assert_false(page.begin_place(&"dojo"))
	assert_eq(page.placing_id(), &"")
	assert_string_contains(page.hint_text(), "银两不足")


func test_place_a_new_building_with_left_click() -> void:
	assert_true(page.begin_place(&"clinic"))
	assert_eq(page.placing_id(), &"clinic")
	assert_true(page.click_cell(Vector2i(3, 3)))
	assert_eq(Game.sect.building_level(&"clinic"), 1)
	assert_eq(Game.sect.layout[&"clinic"], {"x": 3, "y": 3, "rot": 0})
	assert_eq(page.placing_id(), &"", "放下后退出摆放模式")
	assert_eq(page.selected_id(), &"clinic", "放下后选中它")
	assert_eq(Game.sect.silver, 10000 - 150)


func test_invalid_spot_keeps_placing_and_explains_why() -> void:
	page.begin_place(&"clinic")
	assert_false(page.click_cell(Vector2i(1, 1)), "(1,1) 是山石")
	assert_eq(page.placing_id(), &"clinic", "失败后仍在摆放")
	assert_string_contains(page.hint_text(), "山石")
	assert_eq(Game.sect.silver, 10000, "失败不扣钱")


func test_rotate_changes_footprint_and_is_saved() -> void:
	page.begin_place(&"library")           # 2×3
	page.rotate_ghost()
	assert_eq(page.placing_rot(), 1)
	# 旋转后占 3×2：放在 (0,6) 会越界（y 方向 6+2=8 刚好到边，x 方向 0+3 合法）
	assert_true(page.click_cell(Vector2i(0, 6)))
	assert_eq(Game.sect.layout[&"library"]["rot"], 1)
	assert_eq(SectMap.size_of(&"library", 1), Vector2i(3, 2))


func test_right_click_cancels() -> void:
	page.begin_place(&"clinic")
	page.click_cell(Vector2i(3, 3), MOUSE_BUTTON_RIGHT)
	assert_eq(page.placing_id(), &"")
	assert_eq(Game.sect.building_level(&"clinic"), 0)


func test_click_selects_and_deselects() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	assert_true(page.click_cell(Vector2i(4, 4)), "点到练武场内部")
	assert_eq(page.selected_id(), &"dojo")
	page.click_cell(Vector2i(0, 0))
	assert_eq(page.selected_id(), &"", "点空地取消选中")


func test_move_is_free_and_updates_position() -> void:
	Game.build_at(&"clinic", Vector2i(3, 3), 0)
	var silver: int = Game.sect.silver
	assert_true(page.begin_place(&"clinic"), "已建的建筑进入的是移动")
	assert_true(page.click_cell(Vector2i(6, 0)))
	assert_eq(Game.sect.layout[&"clinic"]["x"], 6)
	assert_eq(Game.sect.silver, silver)


func test_demolish_needs_two_clicks() -> void:
	Game.build_at(&"clinic", Vector2i(3, 3), 0)
	page.select(&"clinic")
	page._on_demolish(&"clinic")
	assert_eq(Game.sect.building_level(&"clinic"), 1, "第一次只是要求确认")
	page._on_demolish(&"clinic")
	assert_eq(Game.sect.building_level(&"clinic"), 0)
	assert_false(Game.sect.layout.has(&"clinic"))
	assert_eq(page.selected_id(), &"")


func test_hover_previews_the_position_bonus() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	page.begin_place(&"clinic")
	page.hover_cell(Vector2i(6, 3))        # 紧挨练武场
	assert_string_contains(page.hint_text(), "可以放在这里")
	assert_string_contains(page.hint_text(), "1.50")
	page.hover_cell(Vector2i(10, 0))       # 远离
	assert_false("1.50" in page.hint_text())
	page.hover_cell(Vector2i(1, 1))
	assert_string_contains(page.hint_text(), "不能放在这里")


func test_preview_does_not_change_the_layout() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	page.begin_place(&"clinic")
	page.hover_cell(Vector2i(6, 3))
	assert_false(Game.sect.layout.has(&"clinic"), "预览不能真的把建筑放进去")


func test_map_view_converts_pixels_to_cells() -> void:
	var v := page.map()
	var c := SectMapView.CELL
	var p := SectMapView.PAD
	assert_eq(v.cell_at(Vector2(p + c * 2 + 5, p + c * 3 + 5)), Vector2i(2, 3))
	assert_eq(v.cell_at(Vector2(1, 1)), SectMap.NONE, "边距内不算格子")
	assert_eq(v.cell_at(Vector2(p + c * 99, p)), SectMap.NONE)


func test_ghost_preview_is_pushed_to_the_map_view() -> void:
	page.begin_place(&"dojo")
	assert_eq(page.map().ghost_id, &"dojo")
	page.cancel()
	assert_eq(page.map().ghost_id, &"")
