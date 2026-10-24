extends GutTest
## 建筑页的交互：选址摆放、旋转、取消、拖拽移动、拆除二次确认、悬停预览与邻居高亮。
## 页面方法里的 cell 是"鼠标所在格"，建筑左上角 = 鼠标格 - 抓取点；测试里用 page.cursor_for(origin) 换算。
## 拖拽、滚轮则直接给地图控件注入鼠标事件。

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


# --- 注入鼠标事件 ---

func _px(cell: Vector2i) -> Vector2:
	return Vector2(SectMapView.PAD + SectMapView.CELL * (cell.x + 0.5), SectMapView.PAD + SectMapView.CELL * (cell.y + 0.5))


func _button(button: int, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	page.map()._gui_input(e)


func _press(cell: Vector2i) -> void:
	_button(MOUSE_BUTTON_LEFT, true, _px(cell))


func _release(cell: Vector2i) -> void:
	_button(MOUSE_BUTTON_LEFT, false, _px(cell))


func _move(pos: Vector2, held: bool = true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	page.map()._gui_input(e)


# --- 新建 ---

func test_begin_place_refuses_when_poor() -> void:
	Game.sect.silver = 10
	assert_false(page.begin_place(&"dojo"))
	assert_eq(page.placing_id(), &"")
	assert_string_contains(page.hint_text(), "银两不足")


func test_place_a_new_building_with_left_click() -> void:
	assert_true(page.begin_place(&"clinic"))
	assert_eq(page.placing_id(), &"clinic")
	assert_true(page.click_cell(page.cursor_for(Vector2i(3, 3))))
	assert_eq(Game.sect.building_level(&"clinic"), 1)
	assert_eq(Game.sect.layout[&"clinic"], {"x": 3, "y": 3, "rot": 0})
	assert_eq(page.placing_id(), &"", "放下后退出摆放模式")
	assert_eq(page.selected_id(), &"clinic", "放下后选中它")
	assert_eq(Game.sect.silver, 10000 - 150)


func test_building_center_follows_the_cursor() -> void:
	page.begin_place(&"dojo")            # 3×3，抓取点在正中 (1,1)
	page.hover_cell(Vector2i(4, 4))
	assert_eq(page.ghost_origin(), Vector2i(3, 3), "鼠标在中心格，左上角偏 (-1,-1)")
	assert_eq(page.map().ghost_origin, Vector2i(3, 3), "预览位置已同步给地图控件")
	page.hover_cell(SectMap.NONE)
	assert_eq(page.ghost_origin(), SectMap.NONE)


func test_invalid_spot_keeps_placing_and_explains_why() -> void:
	page.begin_place(&"clinic")
	assert_false(page.click_cell(page.cursor_for(Vector2i(1, 1))), "(1,1) 是山石")
	assert_eq(page.placing_id(), &"clinic", "失败后仍在摆放")
	assert_string_contains(page.hint_text(), "山石")
	assert_eq(Game.sect.silver, 10000, "失败不扣钱")


func test_rotate_changes_footprint_and_is_saved() -> void:
	page.begin_place(&"library")           # 2×3
	page.rotate_ghost()
	assert_eq(page.placing_rot(), 1)
	assert_true(page.click_cell(page.cursor_for(Vector2i(0, 6))), "旋转后占 3×2，放在 (0,6) 合法")
	assert_eq(Game.sect.layout[&"library"]["rot"], 1)


func test_right_click_cancels() -> void:
	page.begin_place(&"clinic")
	page.click_cell(Vector2i(3, 3), MOUSE_BUTTON_RIGHT)
	assert_eq(page.placing_id(), &"")
	assert_eq(Game.sect.building_level(&"clinic"), 0)
	assert_eq(page.map().ghost_id, &"", "预览也要撤掉")


func test_mouse_wheel_rotates_while_placing() -> void:
	page.begin_place(&"clinic")
	_button(MOUSE_BUTTON_WHEEL_UP, true, _px(Vector2i(3, 3)))
	assert_eq(page.placing_rot(), 1)
	_button(MOUSE_BUTTON_WHEEL_DOWN, true, _px(Vector2i(3, 3)))
	assert_eq(page.placing_rot(), 0)


func test_wheel_does_nothing_when_not_placing() -> void:
	_button(MOUSE_BUTTON_WHEEL_UP, true, _px(Vector2i(3, 3)))
	assert_eq(page.placing_rot(), 0)
	assert_eq(page.placing_id(), &"")


# --- 选中、移动、拆除 ---

func test_click_selects_and_deselects() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	assert_true(page.click_cell(Vector2i(4, 4)), "点到练武场内部")
	assert_eq(page.selected_id(), &"dojo")
	page.click_cell(Vector2i(0, 0))
	assert_eq(page.selected_id(), &"", "点空地取消选中")


func test_move_via_palette_is_free_and_updates_position() -> void:
	Game.build_at(&"clinic", Vector2i(3, 3), 0)
	var silver: int = Game.sect.silver
	assert_true(page.begin_place(&"clinic"), "已建的建筑进入的是移动")
	assert_true(page.click_cell(page.cursor_for(Vector2i(6, 0))))
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


# --- 拖拽移动 ---

func test_drag_moves_a_building() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)       # 占 x3-5, y3-5
	var silver: int = Game.sect.silver
	_press(Vector2i(4, 4))                          # 抓住正中那格
	_move(_px(Vector2i(3, 4)))                      # 向左拖一格：开始拖动
	assert_true(page.is_dragging())
	assert_eq(page.placing_id(), &"dojo")
	assert_eq(page.ghost_origin(), Vector2i(2, 3), "抓的是中心格，所以左上角在鼠标左上")
	_release(Vector2i(3, 4))
	assert_false(page.is_dragging())
	assert_eq(Game.sect.layout[&"dojo"]["x"], 2)
	assert_eq(Game.sect.layout[&"dojo"]["y"], 3)
	assert_eq(Game.sect.silver, silver, "拖动移动免费")
	assert_eq(page.placing_id(), &"")
	assert_eq(page.selected_id(), &"dojo")


func test_drag_keeps_the_grabbed_cell_under_the_cursor() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	_press(Vector2i(3, 3))                          # 抓住左上角那格
	_move(_px(Vector2i(2, 3)))
	assert_eq(page.ghost_origin(), Vector2i(2, 3), "抓的是左上角，鼠标到哪左上角就到哪")


func test_drag_to_a_bad_spot_returns_to_original() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	_press(Vector2i(4, 4))
	_move(_px(Vector2i(5, 4)))                      # 左上角会到 (4,3)，压到 (6,5) 的山石
	_release(Vector2i(5, 4))
	assert_eq(Game.sect.layout[&"dojo"], {"x": 3, "y": 3, "rot": 0}, "放不下就留在原处")
	assert_string_contains(page.hint_text(), "放回原处")
	assert_eq(page.placing_id(), &"")


func test_drag_released_outside_the_map_cancels() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	_press(Vector2i(4, 4))
	_move(_px(Vector2i(3, 4)))
	_move(Vector2(2, 2))                            # 拖出地图
	_button(MOUSE_BUTTON_LEFT, false, Vector2(2, 2))
	assert_eq(Game.sect.layout[&"dojo"], {"x": 3, "y": 3, "rot": 0})
	assert_eq(page.placing_id(), &"")


func test_press_and_release_on_same_cell_is_a_click_not_a_drag() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	_press(Vector2i(4, 4))
	_release(Vector2i(4, 4))
	assert_false(page.is_dragging())
	assert_eq(page.selected_id(), &"dojo")
	_press(Vector2i(0, 0))
	_release(Vector2i(0, 0))
	assert_eq(page.selected_id(), &"", "点空地取消选中")


func test_cannot_drag_empty_ground() -> void:
	_press(Vector2i(0, 0))
	_move(_px(Vector2i(1, 0)))
	assert_false(page.is_dragging())
	assert_eq(page.placing_id(), &"")


# --- 预览与高亮 ---

func test_hover_previews_the_position_bonus() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	page.begin_place(&"clinic")
	page.hover_cell(page.cursor_for(Vector2i(6, 3)))       # 紧挨练武场
	assert_string_contains(page.hint_text(), "可以放在这里")
	assert_string_contains(page.hint_text(), "1.50")
	page.hover_cell(page.cursor_for(Vector2i(10, 0)))      # 远离
	assert_false("1.50" in page.hint_text())
	page.hover_cell(page.cursor_for(Vector2i(1, 1)))
	assert_string_contains(page.hint_text(), "不能放在这里")


func test_neighbors_are_highlighted_on_the_map() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	page.begin_place(&"clinic")
	page.hover_cell(page.cursor_for(Vector2i(6, 3)))
	assert_true(page.map().links.has(&"dojo"), "紧挨练武场时，练武场被标成有关联的邻居")
	assert_almost_eq(float(page.map().links[&"dojo"]), 1.5, 0.001)
	page.hover_cell(page.cursor_for(Vector2i(10, 0)))
	assert_true(page.map().links.is_empty(), "离开后高亮消失")
	page.hover_cell(page.cursor_for(Vector2i(1, 1)))
	assert_true(page.map().links.is_empty(), "放不下的位置不显示加成")


func test_placing_a_dojo_shows_its_effect_on_an_existing_clinic() -> void:
	Game.build_at(&"clinic", Vector2i(6, 3), 0)
	page.begin_place(&"dojo")
	page.hover_cell(page.cursor_for(Vector2i(3, 3)))       # 练武场放在药庐左边
	assert_true(page.map().links.has(&"clinic"))
	assert_string_contains(page.hint_text(), "药庐")


func test_preview_does_not_change_the_layout() -> void:
	Game.build_at(&"dojo", Vector2i(3, 3), 0)
	page.begin_place(&"clinic")
	page.hover_cell(page.cursor_for(Vector2i(6, 3)))
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
