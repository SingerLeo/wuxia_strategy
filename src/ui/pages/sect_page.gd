class_name SectPage
extends Page
## 门派总览：基本信息与概况。

var _grid: GridContainer
var _values: Dictionary = {}


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
	for key in ["门派", "日期", "银两", "弟子人数", "平均体力", "平均忠诚"]:
		_grid.add_child(Page.make_label(key, &"Muted"))
		var v := Page.make_label("")
		_grid.add_child(v)
		_values[key] = v

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
	_values["银两"].text = str(s.silver)
	_values["弟子人数"].text = str(n)
	_values["平均体力"].text = "%.0f" % (float(stamina) / maxi(n, 1))
	_values["平均忠诚"].text = "%.0f" % (float(loyalty) / maxi(n, 1))
