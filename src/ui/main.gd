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

	Game.state_changed.connect(_on_state_changed)
	Game.log_added.connect(_on_log_added)
	_on_log_added("欢迎来到" + Game.sect.sect_name + "。为弟子安排本旬事务，然后点击「结束本旬」。")
	_update_header()
	show_page(0)


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
	_add_page("武学", PlaceholderPage.new("武学", "武学研修与路线选择 —— 即将加入"))
	_add_page("江湖", PlaceholderPage.new("江湖", "势力、地图与外交 —— 即将加入"))
	_add_page("事件", PlaceholderPage.new("事件", "江湖传闻与门内事务 —— 即将加入"))


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

	var end_btn := Button.new()
	end_btn.text = "结束本旬  ▶"
	end_btn.theme_type_variation = &"PrimaryButton"
	end_btn.custom_minimum_size = Vector2(180, 0)
	end_btn.pressed.connect(Game.end_xun)
	row.add_child(end_btn)
	return bar


func _on_nav_toggled(on: bool, index: int) -> void:
	if on and index != _current:
		show_page(index)


func _on_state_changed() -> void:
	_update_header()
	if _current >= 0:
		_pages[_current].refresh()


func _on_log_added(text: String) -> void:
	_log.append_text(text + "\n")


func _update_header() -> void:
	_sect_label.text = Game.sect.sect_name
	_date_label.text = UiText.date_text(Game.sect)
	_silver_label.text = "银两 %d" % Game.sect.silver
