class_name BuildingPage
extends Page
## 建筑：在山门地图上摆放、移动、升级、拆除门派建筑。位置会影响效果（邻接规则见 Catalog.SYNERGIES）。
##
## 操作：
##   建造  右侧点"建造" → 地图上出现预览（建筑中心跟着鼠标；绿可放、红不可放；有加成的邻居会高亮）
##         左键放下，滚轮 / R 旋转，右键 / Esc 取消
##   移动  直接按住地图上的建筑拖到新位置再松开；放不下会自动回原处
##   选中  点地图上的建筑或右侧清单，可升级、移动、拆除（拆除要点两次确认）
##
## 术语：cursor 指鼠标所在的格子；origin 指建筑占地的左上角格子；
##       origin = cursor - grab，grab 是"鼠标抓着建筑的哪一格"。

var _map: SectMapView
var _hint: Label
var _rotate_btn: Button
var _summary: Label
var _palette: VBoxContainer
var _info: VBoxContainer

var _placing: StringName = &""    ## 正在摆放（新建或移动）的建筑；空表示没有
var _rot: int = 0
var _grab: Vector2i = Vector2i.ZERO
var _cursor: Vector2i = SectMap.NONE
var _dragging := false
var _selected: StringName = &""
var _confirm_demolish := false
var _hint_text := ""


func _init() -> void:
	super._init()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# 左：标题 + 地图 + 提示 + 图例
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(Page.make_label("建筑", &"Heading"))
	_summary = Page.make_label("", &"Muted")
	left.add_child(_summary)

	_map = SectMapView.new()
	_map.hovered.connect(_on_hovered)
	_map.clicked.connect(_on_clicked)
	_map.drag_started.connect(_on_drag_started)
	_map.dropped.connect(_on_dropped)
	_map.rotate_requested.connect(rotate_ghost)
	_map.cancel_requested.connect(cancel)
	left.add_child(_map)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	left.add_child(bar)
	_hint = Page.make_label("")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 420
	bar.add_child(_hint)
	_rotate_btn = Button.new()
	_rotate_btn.text = "旋转 (R)"
	_rotate_btn.pressed.connect(rotate_ghost)
	bar.add_child(_rotate_btn)
	left.add_child(Page.make_label("▲ 位置加成   ▼ 位置受影响   山、水不可建   拖动建筑可直接移动", &"Muted"))

	# 右：清单 + 详情
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	scroll.add_child(right)
	right.add_child(Page.make_label("建筑清单", &"Subheading"))
	_palette = VBoxContainer.new()
	_palette.add_theme_constant_override("separation", 6)
	right.add_child(_palette)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	right.add_child(_info)


# --- 供测试和外部调用的状态与操作 ---

func map() -> SectMapView:
	return _map


func placing_id() -> StringName:
	return _placing


func selected_id() -> StringName:
	return _selected


func placing_rot() -> int:
	return _rot


func is_dragging() -> bool:
	return _dragging


func hint_text() -> String:
	return _hint_text


## 当前预览的左上角格子；没有预览为 SectMap.NONE
func ghost_origin() -> Vector2i:
	if _placing == &"" or _cursor == SectMap.NONE:
		return SectMap.NONE
	return _cursor - _grab


## 想让建筑落在 origin，鼠标应当在哪一格（测试用）
func cursor_for(origin: Vector2i) -> Vector2i:
	return origin + _grab


## 进入摆放模式：未建的建筑是"建造"，已建的是"移动"。银两不足的新建会被拒绝。
func begin_place(id: StringName) -> bool:
	if not Catalog.BUILDINGS.has(id):
		return false
	var s := Game.sect
	if s.building_level(id) == 0 and s.silver < Economy.next_building_cost(id, 0):
		_set_hint("银两不足，建不起%s。" % Catalog.BUILDINGS[id]["name"])
		return false
	_placing = id
	_selected = &""
	_dragging = false
	_confirm_demolish = false
	_rot = int(s.layout[id]["rot"]) if s.layout.has(id) else 0
	_grab = SectMap.default_grab(id, _rot)
	_refresh_ghost()
	_set_hint(_placing_hint())
	_rebuild_side()
	return true


## 开始拖动 cell 处的建筑（只有已摆放的建筑能拖）。按住的那一格会一直跟着鼠标。
func begin_drag(cell: Vector2i) -> bool:
	var s := Game.sect
	var id := SectMap.building_at(s, cell) if cell != SectMap.NONE else &""
	if id == &"":
		return false
	var p: Dictionary = s.layout[id]
	_placing = id
	_selected = id
	_dragging = true
	_confirm_demolish = false
	_rot = int(p["rot"])
	_grab = cell - Vector2i(p["x"], p["y"])
	_cursor = cell
	_refresh_ghost()
	_set_hint(_placing_hint())
	_rebuild_side()
	return true


## 拖动后松开。放得下就移动过去，放不下（或松在地图外）就回原处。
func drop(cell: Vector2i) -> bool:
	if not _dragging:
		return false
	_dragging = false
	var id := _placing
	if cell == SectMap.NONE:
		_end_placing("已放回原处。")
		return false
	var origin := cell - _grab
	if Game.move_building(id, origin, _rot):
		_selected = id
		_end_placing("已把%s挪到新位置。" % Catalog.BUILDINGS[id]["name"])
		return true
	_end_placing("放不下：%s，已放回原处。" % SectMap.placement_error(Game.sect, id, origin, _rot))
	return false


func rotate_ghost() -> void:
	if _placing == &"":
		return
	_rot = (_rot + 1) % 2
	_grab = SectMap.default_grab(_placing, _rot)   # 旋转后改回以中心为抓取点
	_refresh_ghost()
	_update_hover_hint()


func cancel() -> void:
	if _placing == &"":
		return
	_dragging = false
	_end_placing("已取消。")


## 在格子上点击（左键放下 / 选中；右键取消）。返回是否产生了有效操作。
func click_cell(cell: Vector2i, button: int = MOUSE_BUTTON_LEFT) -> bool:
	if button == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	if button != MOUSE_BUTTON_LEFT:
		return false
	if _placing != &"":
		_cursor = cell
		return _try_place(cell)
	var id := SectMap.building_at(Game.sect, cell) if cell != SectMap.NONE else &""
	select(id)
	return id != &""


func select(id: StringName) -> void:
	_selected = id
	_confirm_demolish = false
	_sync_map()
	if id == &"":
		_set_hint(_idle_hint())
	_rebuild_side()


func hover_cell(cell: Vector2i) -> void:
	_cursor = cell
	_refresh_ghost()
	_update_hover_hint()


func refresh() -> void:
	var s := Game.sect
	_map.sect = s
	# 建筑被拆除/读档后，选中的对象可能已经不存在
	if _selected != &"" and s.building_level(_selected) <= 0:
		_selected = &""
	_summary.text = "%s %d  ·  建筑维护 %d 两/旬" % [UiText.RES_SILVER, s.silver, Economy.building_upkeep(s)]
	_sync_map()
	if _hint_text == "":
		_set_hint(_idle_hint())
	_rebuild_side()


# --- 内部 ---

func _end_placing(message: String) -> void:
	_placing = &""
	_dragging = false
	_refresh_ghost()
	_set_hint(message)
	_rebuild_side()


## 把预览状态（位置、旋转、邻居高亮）同步给地图控件
func _refresh_ghost() -> void:
	var origin := ghost_origin()
	_map.ghost_id = _placing
	_map.ghost_rot = _rot
	_map.ghost_origin = origin
	_map.links = {}
	if _placing != &"" and origin != SectMap.NONE and SectMap.can_place(Game.sect, _placing, origin, _rot):
		_map.links = SectMap.preview_links(Game.sect, _placing, origin, _rot)
	_sync_map()


func _sync_map() -> void:
	_map.sect = Game.sect
	_map.selected_id = _selected
	_rotate_btn.visible = _placing != &""
	_map.queue_redraw()


func _set_hint(text: String) -> void:
	_hint_text = text
	_hint.text = text


func _idle_hint() -> String:
	return "点击地图上的建筑查看详情，按住拖动可移动；在右侧选一座建筑来建造。"


func _placing_hint() -> String:
	var info: Dictionary = Catalog.BUILDINGS[_placing]
	var sz := SectMap.size_of(_placing, _rot)
	var verb := "移动" if Game.sect.building_level(_placing) > 0 else "建造"
	return "%s%s（占 %d×%d）：左键放下，滚轮或 R 旋转，右键 / Esc 取消。" % [verb, info["name"], sz.x, sz.y]


func _on_hovered(cell: Vector2i) -> void:
	hover_cell(cell)


func _on_clicked(cell: Vector2i, button: int) -> void:
	click_cell(cell, button)


func _on_drag_started(cell: Vector2i) -> void:
	begin_drag(cell)


func _on_dropped(cell: Vector2i) -> void:
	drop(cell)


## 摆放时，悬停到哪就把"能不能放、放这里有什么加成"写在提示里
func _update_hover_hint() -> void:
	if _placing == &"":
		return
	var origin := ghost_origin()
	if origin == SectMap.NONE:
		_set_hint(_placing_hint())
		return
	var err := SectMap.placement_error(Game.sect, _placing, origin, _rot)
	if err != "":
		_set_hint("不能放在这里：%s。" % err)
		return
	var f := SectMap.preview_factor(Game.sect, _placing, origin, _rot)
	var text := "可以放在这里。"
	if f > 1.001:
		text += "  位置加成 ×%.2f ▲" % f
	elif f < 0.999:
		text += "  位置影响 ×%.2f ▼" % f
	var others := SectMap.preview_links(Game.sect, _placing, origin, _rot)
	for other in others:
		if float(others[other]) != 1.0 and not _placing_is_target_of(other):
			text += "\n对%s的影响 ×%.2f" % [Catalog.BUILDINGS[other]["name"], others[other]]
	_set_hint(text)


## other 是不是"影响 _placing 的邻居"（即 _placing 是被影响者）。用来避免把同一条规则重复写两次。
func _placing_is_target_of(other: StringName) -> bool:
	for rule in Catalog.SYNERGIES:
		if rule["target"] == _placing and rule["other"] == other:
			return true
	return false


func _try_place(cursor: Vector2i) -> bool:
	if cursor == SectMap.NONE:
		return false
	var id := _placing
	var origin := cursor - _grab
	var ok := false
	if Game.sect.building_level(id) > 0:
		ok = Game.move_building(id, origin, _rot)
	else:
		ok = Game.build_at(id, origin, _rot)
	if ok:
		_selected = id
		_end_placing("已放下%s。" % Catalog.BUILDINGS[id]["name"])
	else:
		var err := SectMap.placement_error(Game.sect, id, origin, _rot)
		_set_hint("放不下：%s。" % (err if err != "" else "银两不足"))
	return ok


# --- 右侧：清单与详情 ---

func _rebuild_side() -> void:
	_clear(_palette)
	_clear(_info)
	var s := Game.sect
	for id in Catalog.BUILDINGS:
		_palette.add_child(_make_row(id))
	if _selected != &"" and s.building_level(_selected) > 0:
		_build_info(_selected)


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _make_row(id: StringName) -> Control:
	var s := Game.sect
	var info: Dictionary = Catalog.BUILDINGS[id]
	var level := s.building_level(id)
	var sz: Array = info["size"]

	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 52
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if level == 0:
		var cost := Economy.next_building_cost(id, 0)
		btn.text = "%s  %d×%d    建造 %d 两" % [info["name"], sz[0], sz[1], cost]
		btn.disabled = s.silver < cost
		btn.tooltip_text = "银两不足" if btn.disabled else info["desc"]
		btn.pressed.connect(begin_place.bind(id))
	else:
		var placed := "已摆放" if s.layout.has(id) else "未摆放"
		btn.text = "%s  Lv %d    %s" % [info["name"], level, placed]
		btn.tooltip_text = info["desc"]
		btn.pressed.connect(select.bind(id))
		if id == _selected:
			btn.theme_type_variation = &"PrimaryButton"
	return btn


func _build_info(id: StringName) -> void:
	var s := Game.sect
	var info: Dictionary = Catalog.BUILDINGS[id]
	var level := s.building_level(id)
	var max_level := Economy.building_max_level(id)

	_info.add_child(Page.make_label("%s  Lv %d / %d" % [info["name"], level, max_level], &"Subheading"))
	_info.add_child(Page.make_label(info["desc"], &"Muted"))
	_info.add_child(Page.make_label("当前效果：" + Economy.effect_text(s, id)))
	var upkeep: int = info["upkeep"][level - 1]
	_info.add_child(Page.make_label("维护费 %d 两/旬" % upkeep, &"Muted"))

	# 位置加成：列出所有与它有关的规则，生效的标 ✔
	var rules: Array[Dictionary] = []
	for rule in Catalog.SYNERGIES:
		if rule["target"] == id:
			rules.append(rule)
	if not rules.is_empty():
		_info.add_child(Page.make_label("位置加成", &"Subheading"))
		var active := SectMap.active_synergies(s, id)
		for rule in rules:
			var on := false
			for a in active:
				if a["other"] == rule["other"]:
					on = true
			var other_name: String = Catalog.BUILDINGS[rule["other"]]["name"]
			var need := "紧挨%s" % other_name if rule["kind"] == "adjacent" else "避开%s（相隔 %d 格以上）" % [other_name, int(rule["dist"])]
			var line := "%s %s ×%.2f" % ["✔" if on else "○", rule["note"], rule["mult"]]
			if not on:
				line += "\n    条件：" + ("需要" + need if rule["kind"] == "adjacent" else need)
			var l := Page.make_label(line, &"" if on else &"Muted")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 300
			if on:
				l.add_theme_color_override("font_color", ThemeBuilder.GOLD)
			_info.add_child(l)

	# 它对邻居的影响：别的建筑的规则里把它当作"邻居"
	var affects: Array[String] = []
	for rule in Catalog.SYNERGIES:
		if rule["other"] == id:
			var t: String = Catalog.BUILDINGS[rule["target"]]["name"]
			var how := "紧挨它时" if rule["kind"] == "adjacent" else "离它 %d 格以内时" % int(rule["dist"])
			affects.append("%s%s效果 ×%.2f" % [how, t, rule["mult"]])
	if not affects.is_empty():
		_info.add_child(Page.make_label("对邻居的影响", &"Subheading"))
		for text in affects:
			_info.add_child(Page.make_label("· " + text, &"Muted"))

	# 操作
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_info.add_child(actions)

	var up := Button.new()
	var cost := Economy.next_building_cost(id, level)
	if cost < 0:
		up.text = "已满级"
		up.disabled = true
	else:
		up.text = "升级（%d 两）" % cost
		up.theme_type_variation = &"PrimaryButton"
		up.disabled = s.silver < cost
		up.tooltip_text = "银两不足" if up.disabled else ""
		up.pressed.connect(_on_upgrade.bind(id))
	actions.add_child(up)

	var mv := Button.new()
	mv.text = "移动" if s.layout.has(id) else "摆放"
	mv.pressed.connect(begin_place.bind(id))
	actions.add_child(mv)

	var rm := Button.new()
	var refund := int(Game.building_invested(id) * Catalog.DEMOLISH_REFUND)
	rm.text = ("确认拆除（退 %d 两）" if _confirm_demolish else "拆除（退 %d 两）") % refund
	rm.pressed.connect(_on_demolish.bind(id))
	actions.add_child(rm)


func _on_upgrade(id: StringName) -> void:
	Game.upgrade_building(id)


## 拆除要点两次：第一次变成"确认拆除"，第二次才真的拆
func _on_demolish(id: StringName) -> void:
	if not _confirm_demolish:
		_confirm_demolish = true
		_rebuild_side()
		return
	_confirm_demolish = false
	if Game.demolish_building(id):
		_selected = &""
		_set_hint("已拆除。")
		_sync_map()
		_rebuild_side()
