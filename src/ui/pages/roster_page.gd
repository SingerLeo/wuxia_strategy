class_name RosterPage
extends Page
## 弟子名册：左侧批量操作栏 + 可排序列表，右侧详情与本旬安排。

const COLUMNS: Array[String] = ["姓名", "年龄", "专长", "体力", "本旬安排"]

var _tree: Tree
var _detail: VBoxContainer
var _radar: RadarChart
var _selected_id: int = -1
var _sort_col: int = -1
var _sort_asc: bool = true


func _init() -> void:
	super._init()
	var split := HSplitContainer.new()
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 520
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	left.add_child(_build_batch_bar())

	_tree = Tree.new()
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in COLUMNS.size():
		_tree.set_column_expand(i, i == 0 or i == 4)
		_tree.set_column_custom_minimum_width(i, 80 if i != 0 else 120)
	_update_column_titles()
	_tree.item_selected.connect(_on_item_selected)
	_tree.column_title_clicked.connect(_on_column_title_clicked)
	left.add_child(_tree)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 420
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)


func _build_batch_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.add_child(Page.make_label("批量安排", &"Muted"))
	var train := Button.new()
	train.text = "按专长修炼"
	train.tooltip_text = "体力不低于 %d 的弟子修炼各自当前最高的属性，其余休息" % Game.AUTO_TRAIN_MIN_STAMINA
	train.pressed.connect(Game.train_all_by_specialty)
	bar.add_child(train)
	var rest := Button.new()
	rest.text = "全部休息"
	rest.pressed.connect(Game.rest_all)
	bar.add_child(rest)
	return bar


func row_count() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root else 0


func selected_id() -> int:
	return _selected_id


## 当前列表从上到下的弟子 id
func row_ids() -> Array[int]:
	var ids: Array[int] = []
	var root := _tree.get_root()
	if root:
		for item in root.get_children():
			ids.append(item.get_metadata(0))
	return ids


## 点击表头：同一列再点一次切换升降序
func sort_by(col: int) -> void:
	if _sort_col == col:
		_sort_asc = not _sort_asc
	else:
		_sort_col = col
		_sort_asc = true
	_update_column_titles()
	refresh()


func refresh() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var to_select: TreeItem = null
	for d in _sorted_disciples():
		var item := _tree.create_item(root)
		item.set_metadata(0, d.id)
		item.set_text(0, d.display_name)
		item.set_text(1, str(int(d.age_years())))
		var top := UiText.top_skill(d)
		item.set_text(2, "%s %d" % [UiText.SKILL[top], d.skills[top]])
		item.set_text(3, str(d.stamina))
		item.set_text(4, _plan_text(d.id))
		item.set_custom_color(4, ThemeBuilder.MUTED if Game.plan_of(d.id) == &"" else ThemeBuilder.GOLD)
		if d.stamina < Balance.LOW_STAMINA:
			item.set_custom_color(3, ThemeBuilder.WARN)
		if d.id == _selected_id or (to_select == null and _selected_id < 0):
			to_select = item
	if to_select:
		to_select.select(0)
		_show_detail(to_select.get_metadata(0))
	elif Game.sect.disciples.is_empty():
		_selected_id = -1
		_clear_detail()


func _sorted_disciples() -> Array[Disciple]:
	var list: Array[Disciple] = Game.sect.disciples.duplicate()
	if _sort_col >= 0:
		var col := _sort_col
		var asc := _sort_asc
		list.sort_custom(func(a: Disciple, b: Disciple) -> bool:
			var ka: Variant = _sort_key(a, col)
			var kb: Variant = _sort_key(b, col)
			return ka < kb if asc else ka > kb)
	return list


func _sort_key(d: Disciple, col: int) -> Variant:
	match col:
		0: return d.display_name
		1: return d.age_xun
		2: return d.skills[UiText.top_skill(d)]
		3: return d.stamina
		_: return _plan_text(d.id)


func _update_column_titles() -> void:
	for i in COLUMNS.size():
		var mark := ""
		if i == _sort_col:
			mark = " ▲" if _sort_asc else " ▼"
		_tree.set_column_title(i, COLUMNS[i] + mark)


func _on_column_title_clicked(column: int, mouse_button: int) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		sort_by(column)


func _plan_text(id: int) -> String:
	var stat := Game.plan_of(id)
	return "休息" if stat == &"" else "修炼·" + UiText.SKILL[stat]


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item:
		_show_detail(item.get_metadata(0))


func _clear_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()


func _show_detail(id: int) -> void:
	_selected_id = id
	_clear_detail()
	var d := Game.find_disciple(id)
	if d == null:
		return

	_detail.add_child(Page.make_label(d.display_name, &"Heading"))
	_detail.add_child(Page.make_label("%d 岁 · %s型 · 潜力 %d" % [int(d.age_years()), UiText.CURVE[d.curve], d.potential], &"Muted"))
	var traits := "、".join(d.traits)
	_detail.add_child(Page.make_label("性格：" + traits))

	_detail.add_child(Page.make_label("本旬安排", &"Subheading"))
	_detail.add_child(_make_plan_option(d))

	# 上：技能 / 属性 两列，数字为 1~20 分（鼠标悬停可看原始值与上限）
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 72)
	columns.add_child(_value_column("技能", Balance.SKILLS, UiText.SKILL, d, true))
	columns.add_child(_value_column("属性", Balance.ATTRIBUTES, UiText.ATTR, d, false))
	_detail.add_child(columns)

	# 下：六维雷达
	_detail.add_child(Page.make_label("综合", &"Subheading"))
	_radar = RadarChart.new()
	var labels: Array[String] = []
	var values: Array[float] = []
	var texts: Array[String] = []
	for dim in Dimensions.compute(d):
		labels.append(dim["name"])
		values.append(dim["value"] / Balance.STAT_MAX)
		texts.append(str(UiText.score(dim["value"])))
	_radar.set_data(labels, values, texts)
	_detail.add_child(_radar)

	_detail.add_child(Page.make_label("状态", &"Subheading"))
	var hp_max := Growth.max_hp(d)
	var neili_max := Growth.max_neili(d)
	_detail.add_child(Page.bar_row("生命", d.hp, hp_max, "%d / %d" % [d.hp, hp_max]))
	_detail.add_child(Page.bar_row("内力", d.neili, neili_max, "%d / %d" % [d.neili, neili_max]))
	_detail.add_child(Page.bar_row("体力", d.stamina, Balance.STAMINA_MAX, str(d.stamina)))
	_detail.add_child(Page.bar_row("心情", d.mood, 100, str(d.mood)))
	_detail.add_child(Page.bar_row("忠诚度", d.loyalty, 100, str(d.loyalty)))
	_detail.add_child(Page.bar_row("威望", d.prestige, 100, str(d.prestige)))


## 一列"名称 + 分数"。with_cap 为真时，悬停提示里附带技能上限。
func _value_column(title: String, keys: Array[StringName], names: Dictionary, d: Disciple, with_cap: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(Page.make_label(title, &"Subheading"))
	for key in keys:
		var raw: int = Dimensions.value_of(d, key)
		var score := UiText.score(raw)
		var row := HBoxContainer.new()
		var tip := "实际数值 %d" % raw
		if with_cap:
			tip += " / 上限 %d" % Growth.skill_cap(d, key)
		row.tooltip_text = tip
		row.add_theme_constant_override("separation", 8)
		var name_label := Page.make_label(names[key], &"Muted")
		name_label.custom_minimum_size.x = 76
		row.add_child(name_label)
		var num := Page.make_label(str(score))
		num.add_theme_color_override("font_color", _score_color(score))
		num.custom_minimum_size.x = 32
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		col.add_child(row)
	return col


static func _score_color(score: int) -> Color:
	if score >= 15:
		return ThemeBuilder.GOLD
	if score <= 5:
		return ThemeBuilder.MUTED
	return ThemeBuilder.TEXT


func radar() -> RadarChart:
	return _radar


func _make_plan_option(d: Disciple) -> OptionButton:
	var opt := OptionButton.new()
	opt.add_item("休息")
	for s in Balance.SKILLS:
		opt.add_item("修炼·" + UiText.SKILL[s])
	var current := Game.plan_of(d.id)
	opt.select(0 if current == &"" else Balance.SKILLS.find(current) + 1)
	opt.item_selected.connect(_on_plan_selected.bind(d.id))
	return opt


func _on_plan_selected(index: int, id: int) -> void:
	Game.set_plan(id, &"" if index == 0 else Balance.SKILLS[index - 1])
