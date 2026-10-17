class_name RosterPage
extends Page
## 弟子名册：左侧列表，右侧详情与本旬安排。

const COLUMNS: Array[String] = ["姓名", "年龄", "专长", "体力", "本旬安排"]

var _tree: Tree
var _detail: VBoxContainer
var _selected_id: int = -1


func _init() -> void:
	super._init()
	var split := HSplitContainer.new()
	add_child(split)

	_tree = Tree.new()
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.custom_minimum_size.x = 520
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in COLUMNS.size():
		_tree.set_column_title(i, COLUMNS[i])
		_tree.set_column_expand(i, i == 0 or i == 4)
		_tree.set_column_custom_minimum_width(i, 80 if i != 0 else 120)
	_tree.item_selected.connect(_on_item_selected)
	split.add_child(_tree)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 420
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)


func row_count() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root else 0


func selected_id() -> int:
	return _selected_id


func refresh() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var to_select: TreeItem = null
	for d in Game.sect.disciples:
		var item := _tree.create_item(root)
		item.set_metadata(0, d.id)
		item.set_text(0, d.display_name)
		item.set_text(1, str(int(d.age_years())))
		var top := UiText.top_stat(d)
		item.set_text(2, "%s %d" % [UiText.STAT[top], d.stats[top]])
		item.set_text(3, str(d.stamina))
		item.set_text(4, _plan_text(d.id))
		item.set_custom_color(4, ThemeBuilder.MUTED if Game.plan_of(d.id) == &"" else ThemeBuilder.GOLD)
		if d.id == _selected_id or (to_select == null and _selected_id < 0):
			to_select = item
	if to_select:
		to_select.select(0)
		_show_detail(to_select.get_metadata(0))
	elif Game.sect.disciples.is_empty():
		_selected_id = -1
		for c in _detail.get_children():
			_detail.remove_child(c)
			c.queue_free()


func _plan_text(id: int) -> String:
	var stat := Game.plan_of(id)
	return "休息" if stat == &"" else "修炼·" + UiText.STAT[stat]


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item:
		_show_detail(item.get_metadata(0))


func _show_detail(id: int) -> void:
	_selected_id = id
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var d := Game.find_disciple(id)
	if d == null:
		return

	_detail.add_child(Page.make_label(d.display_name, &"Heading"))
	_detail.add_child(Page.make_label("%d 岁 · %s型 · 潜力 %d" % [int(d.age_years()), UiText.CURVE[d.curve], d.potential], &"Muted"))
	var traits := "、".join(d.traits)
	_detail.add_child(Page.make_label("性格：" + traits))

	_detail.add_child(Page.make_label("本旬安排", &"Subheading"))
	_detail.add_child(_make_plan_option(d))

	_detail.add_child(Page.make_label("属性", &"Subheading"))
	for s in Balance.STATS:
		_detail.add_child(Page.bar_row(UiText.STAT[s], d.stats[s], Balance.STAT_MAX, "%d / %d" % [d.stats[s], Growth.stat_cap(d, s)]))

	_detail.add_child(Page.make_label("资质", &"Subheading"))
	for a in Balance.APTITUDES:
		_detail.add_child(Page.bar_row(UiText.APT[a], d.aptitudes[a], Balance.STAT_MAX, str(d.aptitudes[a])))

	_detail.add_child(Page.make_label("状态", &"Subheading"))
	_detail.add_child(Page.bar_row("体力", d.stamina, Balance.STAMINA_MAX, str(d.stamina)))
	_detail.add_child(Page.bar_row("士气", d.morale, 100, str(d.morale)))
	_detail.add_child(Page.bar_row("忠诚", d.loyalty, 100, str(d.loyalty)))


func _make_plan_option(d: Disciple) -> OptionButton:
	var opt := OptionButton.new()
	opt.add_item("休息")
	for s in Balance.STATS:
		opt.add_item("修炼·" + UiText.STAT[s])
	var current := Game.plan_of(d.id)
	opt.select(0 if current == &"" else Balance.STATS.find(current) + 1)
	opt.item_selected.connect(_on_plan_selected.bind(d.id))
	return opt


func _on_plan_selected(index: int, id: int) -> void:
	Game.set_plan(id, &"" if index == 0 else Balance.STATS[index - 1])
