class_name RecruitPage
extends Page
## 招收（B 类，P0）：本季候选人列表 + 详情 + 招收/婉拒。
## 候选人每季刷新，质量随门派威望提升；要价 = 40 + 潜力。

const COLUMNS: Array[String] = ["姓名", "年龄", "专长", "性格", "要价"]

var _tree: Tree
var _detail: VBoxContainer
var _silver_label: Label
var _recruit_btn: Button
var _decline_btn: Button
var _selected_id: int = -1


func _init() -> void:
	super._init()
	var split := HSplitContainer.new()
	split.split_offset = -150
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 520
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(Page.make_label("本季候选人", &"Subheading"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_silver_label = Page.make_label("", &"Muted")
	head.add_child(_silver_label)
	left.add_child(head)
	left.add_child(Page.make_label("每季第一天刷新一批，威望越高，来投的资质越好。", &"Muted"))

	_tree = Tree.new()
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in COLUMNS.size():
		_tree.set_column_title(i, COLUMNS[i])
		_tree.set_column_expand(i, i == 0 or i == 3)
		_tree.set_column_custom_minimum_width(i, 70 if i != 0 else 120)
	_tree.item_selected.connect(_on_item_selected)
	left.add_child(_tree)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 520
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)


func candidate_count() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root else 0


func selected_id() -> int:
	return _selected_id


func refresh() -> void:
	_silver_label.text = "银两 %d" % Game.sect.silver
	_tree.clear()
	var root := _tree.create_item()
	var to_select: TreeItem = null
	for c in Game.candidates:
		var item := _tree.create_item(root)
		item.set_metadata(0, c.id)
		item.set_text(0, c.display_name)
		item.set_text(1, str(int(c.age_years())))
		var top := UiText.top_skill(c)
		item.set_text(2, "%s %d" % [UiText.STAT[top], c.stats[top]])
		item.set_text(3, "、".join(c.traits))
		item.set_text(4, str(Recruitment.asking_price(c)))
		if c.id == _selected_id or (to_select == null and _selected_id < 0):
			to_select = item
	if to_select:
		to_select.select(0)
		_show_detail(to_select.get_metadata(0))
	elif Game.candidates.is_empty():
		_selected_id = -1
		_clear_detail()
		_detail.add_child(Page.make_label("本季候选人已用尽，等下一季。", &"Muted"))


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
	var c := _find(id)
	if c == null:
		return

	_detail.add_child(Page.make_label(c.display_name, &"Heading"))
	_detail.add_child(Page.make_label("%d 岁 · %s型" % [int(c.age_years()), UiText.CURVE[c.curve]], &"Muted"))
	_detail.add_child(Page.make_label("性格：" + "、".join(c.traits)))

	# 资质预览：心智与基本功（1~20 分；潜力与先天上限是隐藏的，不直接展示）
	_detail.add_child(Page.make_label(UiText.CAT_MIND, &"Subheading"))
	_detail.add_child(_score_grid(c, Balance.MIND))
	_detail.add_child(Page.make_label(UiText.CAT_BASICS, &"Subheading"))
	_detail.add_child(_score_grid(c, Balance.BASICS))

	# 武学概览
	_detail.add_child(Page.make_label("入门所学", &"Subheading"))
	var skills_text := ""
	var first := true
	for s in Balance.MARTIAL:
		if c.stats[s] >= 15:
			if not first:
				skills_text += "、"
			skills_text += "%s %d" % [UiText.STAT[s], c.stats[s]]
			first = false
	_detail.add_child(Page.make_label(skills_text if skills_text != "" else "无过人之处", &"Muted"))

	# 操作
	var price := Recruitment.asking_price(c)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_recruit_btn = Button.new()
	_recruit_btn.theme_type_variation = &"PrimaryButton"
	_recruit_btn.pressed.connect(_on_recruit_pressed.bind(id))
	bar.add_child(_recruit_btn)
	_decline_btn = Button.new()
	_decline_btn.text = "婉拒"
	_decline_btn.pressed.connect(_on_decline_pressed.bind(id))
	bar.add_child(_decline_btn)
	_detail.add_child(bar)
	_update_buttons(price)


## 四列"名称 分数"的网格
func _score_grid(c: Disciple, keys: Array[StringName]) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 6)
	for k in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Page.make_label(UiText.STAT[k], &"Muted")
		name_label.custom_minimum_size.x = 64
		row.add_child(name_label)
		var num := Page.make_label(str(UiText.score(c.stats[k])))
		num.add_theme_font_size_override("font_size", 22)
		row.add_child(num)
		grid.add_child(row)
	return grid


func _update_buttons(price: int) -> void:
	if _recruit_btn == null:
		return
	var afford := Game.sect.silver >= price
	_recruit_btn.text = "收为弟子（%d 两）" % price
	_recruit_btn.disabled = not afford
	_recruit_btn.tooltip_text = "" if afford else "银两不足"


func _find(id: int) -> Disciple:
	for c in Game.candidates:
		if c.id == id:
			return c
	return null


func _on_recruit_pressed(id: int) -> void:
	if Game.recruit(id):
		_selected_id = -1
		refresh()


func _on_decline_pressed(id: int) -> void:
	Game.decline(id)
	_selected_id = -1
	refresh()
