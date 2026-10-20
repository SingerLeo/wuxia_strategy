class_name Page
extends MarginContainer
## 所有主界面页面的基类。子类在 _init 里搭界面，在 refresh 里按 Game 的当前状态刷新。


func _init() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 16)


## 状态变化或页面被切换到时调用
func refresh() -> void:
	pass


static func make_label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	return l


## 一张信息卡：左侧 标题 + 标签 + 说明 + 补充行，右侧一个操作按钮
static func make_card(title: String, tag: String, desc: String, extra: String, button: Button) -> PanelContainer:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(make_label(title, &"Subheading"))
	head.add_child(make_label(tag, &"Muted"))
	info.add_child(head)
	info.add_child(make_label(desc))
	info.add_child(make_label(extra, &"Muted"))
	row.add_child(info)

	button.custom_minimum_size.x = 190
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return card


## 一行"名称 + 进度条 + 数值文字"
static func bar_row(label: String, value: float, max_value: float, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := make_label(label)
	name_label.custom_minimum_size.x = 56
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value_label := make_label(text, &"Muted")
	value_label.custom_minimum_size.x = 80
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row
