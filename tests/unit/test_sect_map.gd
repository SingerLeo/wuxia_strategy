extends GutTest
## 山门地图：地形、占地、摆放规则、邻接加成，以及建造/移动/拆除。
## 地图见 Catalog.MAP（12×8）：山石在 (1,1)(2,1)(1,2)(6,5)(5,7)(6,7)，池塘在 (8,1)(9,1)(8,2)(9,2)。

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1


func _sect() -> Sect:
	return Sect.new("测试派", rng)


func _place(s: Sect, id: StringName, x: int, y: int, rot: int = 0) -> void:
	s.layout[id] = {"x": x, "y": y, "rot": rot}
	s.buildings[id] = maxi(1, s.building_level(id))


# --- 地形与占地 ---

func test_map_dimensions_and_terrain() -> void:
	assert_eq(SectMap.width(), 12)
	assert_eq(SectMap.height(), 8)
	assert_eq(SectMap.terrain(Vector2i(0, 0)), ".")
	assert_eq(SectMap.terrain(Vector2i(1, 1)), "#")
	assert_eq(SectMap.terrain(Vector2i(8, 1)), "~")
	assert_eq(SectMap.terrain(Vector2i(99, 0)), "", "越界没有地形")
	assert_true(SectMap.is_buildable(Vector2i(0, 0)))
	assert_false(SectMap.is_buildable(Vector2i(1, 1)))


func test_every_row_has_the_same_width() -> void:
	for row in Catalog.MAP:
		assert_eq(String(row).length(), SectMap.width())


func test_size_and_rotation() -> void:
	assert_eq(SectMap.size_of(&"library", 0), Vector2i(2, 3))
	assert_eq(SectMap.size_of(&"library", 1), Vector2i(3, 2), "旋转后宽高对调")
	assert_eq(SectMap.cells(&"dojo", Vector2i(3, 3), 0).size(), 9)
	assert_true(SectMap.cells(&"clinic", Vector2i(4, 4), 0).has(Vector2i(5, 5)))


# --- 能否摆放 ---

func test_placement_rejects_out_of_bounds() -> void:
	var s := _sect()
	assert_ne(SectMap.placement_error(s, &"dojo", Vector2i(10, 0), 0), "", "3×3 放在最右边会越界")
	assert_ne(SectMap.placement_error(s, &"clinic", Vector2i(-1, 0), 0), "")


func test_placement_rejects_rock_and_pond() -> void:
	var s := _sect()
	assert_string_contains(SectMap.placement_error(s, &"clinic", Vector2i(1, 1), 0), "山石")
	assert_string_contains(SectMap.placement_error(s, &"clinic", Vector2i(8, 1), 0), "池塘")


func test_placement_rejects_overlap_but_not_self() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	assert_string_contains(SectMap.placement_error(s, &"clinic", Vector2i(4, 4), 0), "练武场")
	assert_true(SectMap.can_place(s, &"dojo", Vector2i(3, 3), 0), "原地不算与自己重叠")
	assert_true(SectMap.can_place(s, &"dojo", Vector2i(2, 3), 0), "向左平移一格也可以")
	assert_false(SectMap.can_place(s, &"dojo", Vector2i(4, 3), 0), "向右平移一格会压到 (6,5) 的山石")


func test_building_at_finds_the_covering_building() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	assert_eq(SectMap.building_at(s, Vector2i(5, 5)), &"dojo")
	assert_eq(SectMap.building_at(s, Vector2i(6, 3)), &"")


# --- 邻接加成 ---

func test_adjacent_means_sharing_an_edge() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)              # 占 x3-5, y3-5
	_place(s, &"clinic", 6, 3)            # 占 x6-7, y3-4：紧挨
	assert_true(SectMap.are_adjacent(s, &"clinic", &"dojo"))
	assert_eq(SectMap.distance(s, &"clinic", &"dojo"), 1)
	_place(s, &"clinic", 7, 3)            # 中间隔一列
	assert_false(SectMap.are_adjacent(s, &"clinic", &"dojo"))
	assert_eq(SectMap.distance(s, &"clinic", &"dojo"), 2)


func test_clinic_next_to_dojo_gets_bonus() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	_place(s, &"clinic", 6, 3)
	assert_almost_eq(SectMap.factor(s, &"clinic"), 1.5, 0.001)
	assert_eq(SectMap.active_synergies(s, &"clinic").size(), 1)
	_place(s, &"clinic", 7, 3)
	assert_almost_eq(SectMap.factor(s, &"clinic"), 1.0, 0.001, "隔开就没有加成")


func test_library_too_close_to_dojo_is_penalized() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	_place(s, &"library", 3, 0)           # 占 x3-4, y0-2，紧贴练武场上沿
	assert_almost_eq(SectMap.factor(s, &"library"), 0.7, 0.001)
	_place(s, &"library", 10, 4)          # 远离
	assert_almost_eq(SectMap.factor(s, &"library"), 1.0, 0.001)


func test_unplaced_buildings_have_neutral_factor() -> void:
	var s := _sect()
	s.buildings[&"clinic"] = 2
	s.buildings[&"dojo"] = 2
	assert_almost_eq(SectMap.factor(s, &"clinic"), 1.0, 0.001, "没摆放就没有位置加成，也不受罚")


# --- 预览辅助 ---

func test_default_grab_is_the_center() -> void:
	assert_eq(SectMap.default_grab(&"dojo", 0), Vector2i(1, 1))
	assert_eq(SectMap.default_grab(&"clinic", 0), Vector2i(1, 1))
	assert_eq(SectMap.default_grab(&"library", 0), Vector2i(1, 1))   # 2×3
	assert_eq(SectMap.default_grab(&"library", 1), Vector2i(1, 1))   # 3×2


func test_preview_links_for_the_building_being_placed() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	var links := SectMap.preview_links(s, &"clinic", Vector2i(6, 3), 0)
	assert_eq(links.keys(), [&"dojo"])
	assert_almost_eq(float(links[&"dojo"]), 1.5, 0.001)
	assert_true(SectMap.preview_links(s, &"clinic", Vector2i(10, 0), 0).is_empty())
	var noisy := SectMap.preview_links(s, &"library", Vector2i(3, 0), 0)
	assert_almost_eq(float(noisy[&"dojo"]), 0.7, 0.001, "藏经阁挨着练武场：藏经阁受影响")


func test_preview_links_include_neighbors_affected_by_the_new_building() -> void:
	var s := _sect()
	_place(s, &"clinic", 6, 3)
	var links := SectMap.preview_links(s, &"dojo", Vector2i(3, 3), 0)
	assert_almost_eq(float(links[&"clinic"]), 1.5, 0.001, "练武场放在药庐旁边，药庐得益")


func test_preview_links_leave_the_layout_untouched() -> void:
	var s := _sect()
	_place(s, &"dojo", 3, 3)
	var before := s.layout.duplicate(true)
	SectMap.preview_links(s, &"clinic", Vector2i(6, 3), 0)
	SectMap.preview_links(s, &"dojo", Vector2i(0, 5), 1)     # 已摆放的也只是临时试一下
	assert_eq(s.layout, before)


# --- 位置倍率接入经济 ---

func test_clinic_bonus_scales_rest_recovery() -> void:
	var s := _sect()
	s.buildings[&"clinic"] = 2
	assert_eq(Economy.rest_bonus(s), 10)
	s.buildings[&"dojo"] = 1
	_place(s, &"dojo", 3, 3)
	_place(s, &"clinic", 6, 3)
	assert_eq(Economy.rest_bonus(s), 15, "10 × 1.5")


func test_library_penalty_reduces_legacy_multiplier() -> void:
	var s := _sect()
	s.buildings[&"library"] = 2           # 无位置时 +30%
	assert_almost_eq(Economy.legacy_mult(s), 1.3, 0.001)
	s.buildings[&"dojo"] = 1
	_place(s, &"dojo", 3, 3)
	_place(s, &"library", 3, 0)
	assert_almost_eq(Economy.legacy_mult(s), 1.0 + 0.3 * 0.7, 0.001)


func test_kitchen_cuts_disciple_upkeep() -> void:
	var s := _sect()
	for i in 10:
		s.add_disciple(DiscipleFactory.create(rng, i))
	assert_eq(Economy.disciple_upkeep(s), 20)
	s.buildings[&"kitchen"] = 2           # -16%
	assert_eq(Economy.disciple_upkeep(s), 17, "20 × 0.84 = 16.8 → 17")
	s.buildings[&"clinic"] = 1
	_place(s, &"clinic", 3, 3)
	_place(s, &"kitchen", 5, 3)           # 紧挨药庐：效果 ×1.25 → -20%
	assert_eq(Economy.disciple_upkeep(s), 16)


# --- 存档 ---

func test_layout_round_trips_through_dict() -> void:
	var s := _sect()
	s.buildings[&"dojo"] = 2
	_place(s, &"dojo", 3, 3, 1)
	var back := Sect.from_dict(s.to_dict())
	assert_eq(back.layout[&"dojo"], {"x": 3, "y": 3, "rot": 1})
	assert_eq(back.building_level(&"dojo"), 2)


func test_old_save_without_layout_loads_as_unplaced() -> void:
	var s := _sect()
	s.buildings[&"dojo"] = 1
	var data := s.to_dict()
	data.erase("layout")
	var back := Sect.from_dict(data)
	assert_true(back.layout.is_empty())
	assert_eq(back.building_level(&"dojo"), 1)


# --- Game：建造 / 移动 / 拆除 ---

func _game() -> Node:
	var g: Node = load("res://src/game/game.gd").new()
	add_child_autofree(g)
	g.new_game(1)
	g.sect.silver = 10000
	return g


func test_build_at_costs_first_level_and_places() -> void:
	var g := _game()
	assert_true(g.build_at(&"dojo", Vector2i(3, 3), 0))
	assert_eq(g.sect.building_level(&"dojo"), 1)
	assert_eq(g.sect.silver, 10000 - 200)
	assert_eq(g.sect.layout[&"dojo"], {"x": 3, "y": 3, "rot": 0})


func test_build_at_fails_on_bad_spot_without_charging() -> void:
	var g := _game()
	assert_false(g.build_at(&"dojo", Vector2i(0, 0), 0), "3×3 会撞山石 (1,1)")
	assert_eq(g.sect.silver, 10000)
	assert_eq(g.sect.building_level(&"dojo"), 0)
	assert_true(g.build_at(&"dojo", Vector2i(3, 3), 0))
	assert_false(g.build_at(&"clinic", Vector2i(4, 4), 0), "与练武场重叠")
	assert_false(g.build_at(&"dojo", Vector2i(7, 3), 0), "已经建过了")


func test_build_at_fails_when_poor() -> void:
	var g := _game()
	g.sect.silver = 50
	assert_false(g.build_at(&"dojo", Vector2i(3, 3), 0))
	assert_eq(g.sect.silver, 50)


func test_move_building_is_free_and_validated() -> void:
	var g := _game()
	g.build_at(&"clinic", Vector2i(3, 3), 0)
	var silver: int = g.sect.silver
	assert_true(g.move_building(&"clinic", Vector2i(6, 0), 0))
	assert_eq(g.sect.layout[&"clinic"], {"x": 6, "y": 0, "rot": 0})
	assert_eq(g.sect.silver, silver, "移动免费")
	assert_false(g.move_building(&"clinic", Vector2i(8, 1), 0), "池塘上不行")
	assert_eq(g.sect.layout[&"clinic"]["x"], 6, "失败时位置不变")
	assert_false(g.move_building(&"dojo", Vector2i(3, 3), 0), "没建的不能移动")


func test_move_building_can_place_a_legacy_unplaced_building() -> void:
	var g := _game()
	g.upgrade_building(&"library")        # 旧方式：建了但没位置
	assert_false(g.sect.layout.has(&"library"))
	assert_true(g.move_building(&"library", Vector2i(10, 4), 0))
	assert_true(g.sect.layout.has(&"library"))


func test_demolish_refunds_half_of_total_invested() -> void:
	var g := _game()
	g.build_at(&"dojo", Vector2i(3, 3), 0)     # 200
	g.upgrade_building(&"dojo")                # 400 → 累计 600
	assert_eq(g.building_invested(&"dojo"), 600)
	var silver: int = g.sect.silver
	assert_true(g.demolish_building(&"dojo"))
	assert_eq(g.sect.silver, silver + 300)
	assert_eq(g.sect.building_level(&"dojo"), 0)
	assert_false(g.sect.layout.has(&"dojo"))
	assert_false(g.demolish_building(&"dojo"), "已经拆了")
	assert_true(g.build_at(&"dojo", Vector2i(3, 3), 0), "拆完可以重建")
