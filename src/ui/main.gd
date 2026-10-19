class_name Main
extends Control
## 主界面外壳：顶栏（门派/日期/银两）+ 左侧导航 + 中央页面 + 底部日志与"结束本旬"。

var _pages: Array[Page] = []
var _nav_buttons: Array[Button] = []
var _current: int = -1

var _nav_box: VBoxContainer
var _content: MarginContainer
var _log: RichTextLabel
var _sect_label: Label
var _date_label: Label
var _silver_label: Label
var _end_button: Button
var _overlay: Control
var _menu: Control
var _menu_load_btn: Button
var _prestige_label: Label
var _honor_label: Label
var _locked_header_added := false


func _ready() -> void:
	theme = ThemeBuilder.build()

	var bg := ColorRect.new()
	bg.color = ThemeBuilder.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	body.add_child(_build_nav())
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)

	root.add_child(_build_bottom_bar())

	_register_pages()
	_build_game_over_overlay()
	_build_menu_overlay()

	Game.state_changed.connect(_on_state_changed)
	Game.log_added.connect(_on_log_added)
	_on_log_added("欢迎来到" + Game.sect.sect_name + "。为弟子安排本旬事务，然后点击「结束本旬」。")
	_update_header()
	show_page(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			_toggle_menu()
		KEY_SPACE:
			if not _menu.visible:
				Game.end_xun()
		KEY_F9:  # 开发用：遣散全部弟子，查看灭亡界面
			Game.debug_disband_all()


func menu_visible() -> bool:
	return _menu.visible


func overlay_visible() -> bool:
	return _overlay.visible


func page_count() -> int:
	return _pages.size()


func get_page(index: int) -> Page:
	return _pages[index]


func nav_pressed_count() -> int:
	var n := 0
	for b in _nav_buttons:
		n += 1 if b.button_pressed else 0
	return n


func show_page(index: int) -> void:
	_current = index
	for i in _pages.size():
		_pages[i].visible = (i == index)
	# 用 button_pressed 而非 set_pressed_no_signal，这样按钮组才会取消其他按钮；
	# 此时 _current 已更新，_on_nav_toggled 不会重复切换
	_nav_buttons[index].button_pressed = true
	_pages[index].refresh()


func _register_pages() -> void:
	_add_page("门派", SectPage.new())
	_add_page("弟子", RosterPage.new())
	_add_page("招收", RecruitPage.new())
	_add_page("设施", PlaceholderPage.new("设施", "练武场、藏经阁等建设 —— 即将加入"))
	_add_page("武学", PlaceholderPage.new("武学", "武学研修与路线选择 —— 即将加入"))
	# P1 的"反馈"类内容：先占位并锁定，见 docs/scope.md
	_add_locked_nav("江湖")
	_add_locked_nav("事件")


func _add_locked_nav(title: String) -> void:
	if not _locked_header_added:
		_locked_header_added = true
		var gap := Control.new()
		gap.custom_minimum_size.y = 12
		_nav_box.add_child(gap)
		_nav_box.add_child(Page.make_label("  即将开放", &"Muted"))
	var btn := Button.new()
	btn.text = title
	btn.disabled = true
	btn.theme_type_variation = &"NavButton"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 46
	_nav_box.add_child(btn)


func _add_page(title: String, page: Page) -> void:
	var index := _pages.size()
	_pages.append(page)
	page.visible = false
	_content.add_child(page)

	var group: ButtonGroup = _nav_buttons[0].button_group if not _nav_buttons.is_empty() else ButtonGroup.new()
	var btn := Button.new()
	btn.text = title
	btn.toggle_mode = true
	btn.button_group = group
	btn.theme_type_variation = &"NavButton"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 46
	btn.toggled.connect(_on_nav_toggled.bind(index))
	_nav_buttons.append(btn)
	_nav_box.add_child(btn)


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bar.add_child(row)
	_sect_label = Page.make_label("", &"Subheading")
	row.add_child(_sect_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_date_label = Page.make_label("")
	row.add_child(_date_label)
	_silver_label = Page.make_label("")
	row.add_child(_silver_label)
	_prestige_label = Page.make_label("")
	row.add_child(_prestige_label)
	_honor_label = Page.make_label("")
	row.add_child(_honor_label)
	var menu_btn := Button.new()
	menu_btn.text = "菜单"
	menu_btn.tooltip_text = "Esc"
	menu_btn.pressed.connect(_toggle_menu)
	row.add_child(menu_btn)
	return bar


func _build_nav() -> Control:
	var nav := PanelContainer.new()
	nav.custom_minimum_size.x = 180
	_nav_box = VBoxContainer.new()
	_nav_box.add_theme_constant_override("separation", 6)
	nav.add_child(_nav_box)
	return nav


func _build_bottom_bar() -> Control:
	var bar := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	_log = RichTextLabel.new()
	_log.custom_minimum_size.y = 110
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.bbcode_enabled = false
	row.add_child(_log)

	_end_button = Button.new()
	_end_button.text = "结束本旬  ▶"
	_end_button.theme_type_variation = &"PrimaryButton"
	_end_button.custom_minimum_size = Vector2(180, 0)
	_end_button.pressed.connect(Game.end_xun)
	row.add_child(_end_button)
	return bar


## 门派灭亡时盖在整个界面上的遮罩，只有"重新开始"一个出口
func _build_game_over_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Page.make_label("门派覆灭", &"Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Page.make_label("再无弟子，山门已空。江湖不会记得这一派。", &"Muted")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var restart := Button.new()
	restart.text = "重新开始"
	restart.theme_type_variation = &"PrimaryButton"
	restart.pressed.connect(Game.new_game)
	box.add_child(restart)


## Esc 系统菜单：继续 / 存档 / 读档 / 设置（占位）/ 退出
func _build_menu_overlay() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0, 0, 0, 0.6)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	add_child(_menu)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Page.make_label("菜单", &"Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := Button.new()
	resume.text = "继续（Esc）"
	resume.pressed.connect(_toggle_menu)
	box.add_child(resume)

	var save := Button.new()
	save.text = "保存进度"
	save.pressed.connect(Game.save_game)
	box.add_child(save)

	_menu_load_btn = Button.new()
	_menu_load_btn.text = "读取存档"
	_menu_load_btn.pressed.connect(func() -> void:
		if Game.load_game():
			_toggle_menu())
	box.add_child(_menu_load_btn)

	var save_dir := Button.new()
	save_dir.text = "打开存档目录"
	save_dir.tooltip_text = ProjectSettings.globalize_path("user://")
	save_dir.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path("user://")))
	box.add_child(save_dir)

	var settings := Button.new()
	settings.text = "设置（未开放）"
	settings.disabled = true
	box.add_child(settings)

	var quit := Button.new()
	quit.text = "退出游戏"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)


func _toggle_menu() -> void:
	_menu.visible = not _menu.visible
	if _menu.visible:
		_menu_load_btn.disabled = not Game.has_save()


func _on_nav_toggled(on: bool, index: int) -> void:
	if on and index != _current:
		show_page(index)


func _on_state_changed() -> void:
	_overlay.visible = Game.over
	_end_button.disabled = Game.over
	_update_header()
	if _current >= 0:
		_pages[_current].refresh()


func _on_log_added(text: String) -> void:
	_log.append_text(text + "\n")


func _update_header() -> void:
	_sect_label.text = Game.sect.sect_name
	_date_label.text = UiText.date_text(Game.sect)
	_silver_label.text = "银两 %d" % Game.sect.silver
	_prestige_label.text = "声望 %d" % Game.sect.prestige
	_honor_label.text = "荣耀 %d" % Game.sect.honor
