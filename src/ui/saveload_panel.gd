class_name SaveLoadPanel
extends ColorRect
## 存档/读档面板：自动存档位（只读）+ 若干手动槽位，每个槽位可存入/读取。
## 作为全屏遮罩使用，由主界面控制显隐。

var _rows: VBoxContainer


func _init() -> void:
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"OrnatePanel"
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var head := HBoxContainer.new()
	var title := Page.make_label("存档 / 读档", &"Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	box.add_child(head)

	box.add_child(Page.make_label("每旬结束会自动存档到「自动存档」位；手动存档请选槽位存入，存入会覆盖该槽位原有内容。", &"Muted"))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)


## 按当前存档状态重建所有槽位行
func refresh() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var infos := Game.slot_infos()
	_rows.add_child(_slot_row(SaveSystem.AUTOSAVE, "自动存档", infos[0]))
	for i in SaveSystem.SLOT_COUNT:
		_rows.add_child(_slot_row(i, "存档 %d" % (i + 1), infos[i + 1]))


func _slot_row(index: int, title: String, info: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var name_label := Page.make_label(title, &"Subheading")
	name_label.custom_minimum_size.x = 110
	row.add_child(name_label)

	var info_text := "（空）"
	if not info.is_empty():
		info_text = "%s · %s · 弟子 %d 人 · 银两 %d\n%s" % [
			info["sect_name"], UiText.date_text_of_xun(info["xun"]),
			info["disciples"], info["silver"], info["saved_at"]]
	var info_label := Page.make_label(info_text, &"Muted" if info.is_empty() else &"")
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_label)

	if index != SaveSystem.AUTOSAVE:
		var save_btn := Button.new()
		save_btn.text = "存入"
		save_btn.tooltip_text = "把当前进度存入%s（覆盖原有内容）" % title
		save_btn.pressed.connect(_on_save_pressed.bind(index))
		row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "读取"
	load_btn.disabled = info.is_empty()
	load_btn.tooltip_text = "" if not info.is_empty() else "空槽位"
	load_btn.pressed.connect(_on_load_pressed.bind(index))
	row.add_child(load_btn)
	return panel


func _on_save_pressed(index: int) -> void:
	if Game.save_to_slot(index):
		refresh()


func _on_load_pressed(index: int) -> void:
	if Game.load_from_slot(index):
		visible = false
