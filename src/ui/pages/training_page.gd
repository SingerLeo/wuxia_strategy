class_name TrainingPage
extends Page
## 训练：左侧日程列表，中间编辑所选日程（各科目份数、强度、实际分到各项的比例），
## 右侧给弟子指派日程。教习（指导加成）等长老/阶位系统做出来后再加。

var _list: ItemList
var _editor: VBoxContainer
var _name_edit: LineEdit
var _intensity: OptionButton
var _used_label: Label
var _spins: Dictionary = {}       ## 科目 -> SpinBox
var _preview: Label
var _tree: Tree
var _selected_sid: int = -1
var _refreshing := false          ## refresh 改控件值时不触发编辑回调


func _init() -> void:
	super._init()
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 20)
	add_child(split)
	split.add_child(_build_schedule_list())
	split.add_child(_build_editor())
	split.add_child(_build_assignments())


func _build_schedule_list() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 220
	box.add_theme_constant_override("separation", 8)
	box.add_child(Page.make_label("日程", &"Heading"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 延后执行：refresh 会清空并重建列表，不能在它自己的信号里做
	_list.item_selected.connect(func(i: int) -> void: select_schedule.call_deferred(_list.get_item_metadata(i)))
	box.add_child(_list)
	var bar := HBoxContainer.new()
	var add := Button.new()
	add.text = "新建"
	add.pressed.connect(func() -> void: select_schedule(Game.add_schedule().id))
	bar.add_child(add)
	var del := Button.new()
	del.text = "删除"
	del.tooltip_text = "删除所选日程；指派了它的弟子改为休息"
	del.pressed.connect(func() -> void:
		if _selected_sid >= 0:
			Game.remove_schedule(_selected_sid))
	bar.add_child(del)
	box.add_child(bar)
	return box


func _build_editor() -> Control:
	_editor = VBoxContainer.new()
	_editor.custom_minimum_size.x = 560
	_editor.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 200
	_name_edit.text_submitted.connect(func(t: String) -> void: Game.rename_schedule(_selected_sid, t))
	_name_edit.focus_exited.connect(func() -> void: Game.rename_schedule(_selected_sid, _name_edit.text))
	head.add_child(_name_edit)
	head.add_child(Page.make_label("强度", &"Muted"))
	_intensity = OptionButton.new()
	for i in UiText.INTENSITY.size():
		_intensity.add_item(UiText.INTENSITY[i], i)
	_intensity.tooltip_text = "轻：经验 ×%.2f、体力 ×%.1f；中：×1；重：经验 ×%.2f、体力 ×%.1f" % [
		Training.INTENSITY_XP[0], Training.INTENSITY_STAMINA[0], Training.INTENSITY_XP[2], Training.INTENSITY_STAMINA[2]]
	_intensity.item_selected.connect(func(i: int) -> void:
		if not _refreshing:
			Game.set_schedule_intensity(_selected_sid, i))
	head.add_child(_intensity)
	_editor.add_child(head)

	_used_label = Page.make_label("", &"Muted")
	_editor.add_child(_used_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for f in Training.FOCI:
		var name_label := Page.make_label(UiText.FOCUS[f], &"Subheading")
		name_label.custom_minimum_size.x = 110
		grid.add_child(name_label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = Training.SLOTS
		spin.step = 1
		spin.suffix = "份"
		spin.value_changed.connect(_on_slots_changed.bind(f))
		_spins[f] = spin
		grid.add_child(spin)
		grid.add_child(Page.make_label(UiText.focus_desc(f), &"Muted"))
	_editor.add_child(grid)

	_editor.add_child(Page.make_label("本旬实际分到", &"Subheading"))
	_preview = Page.make_label("", &"Muted")
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size.x = 520
	_editor.add_child(_preview)
	return _editor


func _build_assignments() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.add_child(Page.make_label("弟子安排", &"Heading"))
	var by_spec := Button.new()
	by_spec.text = "按专长指派"
	by_spec.tooltip_text = "体力不低于 %d 的弟子指派最侧重其专长的日程，其余休息" % Game.AUTO_TRAIN_MIN_STAMINA
	by_spec.pressed.connect(Game.train_all_by_specialty)
	bar.add_child(by_spec)
	var all_sel := Button.new()
	all_sel.text = "全部用所选日程"
	all_sel.pressed.connect(func() -> void:
		if _selected_sid >= 0:
			for d in Game.sect.disciples:
				Game.assign(d.id, _selected_sid))
	bar.add_child(all_sel)
	var rest := Button.new()
	rest.text = "全部休息"
	rest.pressed.connect(Game.rest_all)
	bar.add_child(rest)
	box.add_child(bar)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 4:
		_tree.set_column_title(i, ["姓名", "专长", "体力", "日程（点击修改）"][i])
		_tree.set_column_expand(i, i == 0 or i == 3)
	_tree.item_edited.connect(_on_assignment_edited)
	box.add_child(_tree)
	return box


func refresh() -> void:
	_refreshing = true
	if Game.find_schedule(_selected_sid) == null:
		_selected_sid = Game.schedules[0].id if not Game.schedules.is_empty() else -1
	_list.clear()
	for s in Game.schedules:
		var i := _list.add_item("%s（%d 人）" % [s.schedule_name, Game.schedule_member_count(s.id)])
		_list.set_item_metadata(i, s.id)
		if s.id == _selected_sid:
			_list.select(i)
	_refresh_editor()
	_refresh_assignments()
	_refreshing = false


func select_schedule(sid: int) -> void:
	_selected_sid = sid
	refresh()


func selected_schedule() -> int:
	return _selected_sid


func assignment_rows() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root else 0


func _refresh_editor() -> void:
	var s := Game.find_schedule(_selected_sid)
	_editor.visible = s != null
	if s == null:
		return
	if not _name_edit.has_focus():
		_name_edit.text = s.schedule_name
	_intensity.select(s.intensity)
	var room := Training.SLOTS - s.used_slots()
	for f in _spins:
		var spin: SpinBox = _spins[f]
		spin.max_value = s.slots_of(f) + room   # 剩余份数决定还能加多少
		spin.set_value_no_signal(s.slots_of(f))
	_used_label.text = "已分配 %d / %d 份；没分出去的时间用于休整（经验少拿，体力少耗）" % [s.used_slots(), Training.SLOTS]
	_used_label.add_theme_color_override("font_color", ThemeBuilder.GOLD if room == 0 else ThemeBuilder.MUTED)

	var alloc := s.allocation()
	var parts: Array[String] = []
	for stat in Balance.TRAINABLE:
		if alloc.has(stat):
			parts.append("%s %d%%" % [UiText.STAT[stat], roundi(alloc[stat] * 100)])
	_preview.text = "、".join(parts) if not parts.is_empty() else "（空日程，等同休息）"


func _refresh_assignments() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var options := "休息"
	for s in Game.schedules:
		options += "," + s.schedule_name.replace(",", "，")
	for d in Game.sect.disciples:
		var item := _tree.create_item(root)
		item.set_metadata(0, d.id)
		item.set_text(0, d.display_name)
		var top := UiText.top_skill(d)
		item.set_text(1, "%s %d" % [UiText.STAT[top], d.stats[top]])
		item.set_text(2, str(d.stamina))
		if d.stamina < Balance.LOW_STAMINA:
			item.set_custom_color(2, ThemeBuilder.WARN)
		item.set_cell_mode(3, TreeItem.CELL_MODE_RANGE)
		item.set_text(3, options)
		item.set_range(3, _option_index(Game.schedule_of(d.id)))
		item.set_editable(3, true)


## 下拉选项序号：0 为休息，之后按 Game.schedules 的顺序
func _option_index(sid: int) -> int:
	for i in Game.schedules.size():
		if Game.schedules[i].id == sid:
			return i + 1
	return 0


func _on_assignment_edited() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	var idx := int(item.get_range(3))
	var sid := Game.REST if idx == 0 else Game.schedules[idx - 1].id
	Game.assign.call_deferred(item.get_metadata(0), sid)  # 延后：assign 会触发重建这棵树


func _on_slots_changed(value: float, focus: StringName) -> void:
	if _refreshing:
		return
	Game.set_schedule_slots(_selected_sid, focus, int(value))
