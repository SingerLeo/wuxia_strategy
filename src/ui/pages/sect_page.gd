class_name SectPage
extends Page
## 门派总览：基本信息与本旬提醒。

var _grid: GridContainer
var _values: Dictionary = {}
var _reminders: VBoxContainer


func _init() -> void:
	super._init()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	box.add_child(Page.make_label("门派总览", &"Heading"))

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(_grid)
	for key in ["门派", "日期", UiText.RES_SILVER, UiText.RES_PRESTIGE, "历史最高威望", "任务等级",
			UiText.RES_LEGACY, "荣耀", "弟子人数", "平均体力", "平均忠诚"]:
		_grid.add_child(Page.make_label(key, &"Muted"))
		var v := Page.make_label("")
		_grid.add_child(v)
		_values[key] = v

	box.add_child(Page.make_label("本旬提醒", &"Subheading"))
	_reminders = VBoxContainer.new()
	_reminders.add_theme_constant_override("separation", 6)
	box.add_child(_reminders)

	box.add_child(Page.make_label("设施", &"Subheading"))
	box.add_child(Page.make_label("练武场、藏经阁、药庐等设施将在后续版本加入。", &"Muted"))


func refresh() -> void:
	var s := Game.sect
	var n := s.disciples.size()
	var stamina := 0
	var loyalty := 0
	for d in s.disciples:
		stamina += d.stamina
		loyalty += d.loyalty
	_values["门派"].text = s.sect_name
	_values["日期"].text = UiText.date_text(s)
	_values[UiText.RES_SILVER].text = str(s.silver)
	_values[UiText.RES_PRESTIGE].text = str(s.prestige)
	_values["历史最高威望"].text = str(s.prestige_peak)
	_values["任务等级"].text = "%d 级" % s.task_tier()
	_values[UiText.RES_LEGACY].text = str(s.legacy)
	_values["荣耀"].text = str(s.honor)
	_values["弟子人数"].text = str(n)
	_values["平均体力"].text = "%.0f" % (float(stamina) / maxi(n, 1))
	_values["平均忠诚"].text = "%.0f" % (float(loyalty) / maxi(n, 1))

	for c in _reminders.get_children():
		_reminders.remove_child(c)
		c.queue_free()
	var items := Game.reminders()
	if items.is_empty():
		_reminders.add_child(Page.make_label("一切妥当，可以结束本旬。", &"Muted"))
	for text in items:
		var l := Page.make_label("· " + text)
		l.add_theme_color_override("font_color", ThemeBuilder.WARN)
		_reminders.add_child(l)
