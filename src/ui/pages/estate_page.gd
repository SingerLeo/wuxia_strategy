class_name EstatePage
extends Page
## 产业：花银两购置，购置后每旬产生收入。

var _summary: Label
var _list: VBoxContainer


func _init() -> void:
	super._init()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	box.add_child(Page.make_label("产业", &"Heading"))
	_summary = Page.make_label("", &"Muted")
	box.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)


func card_count() -> int:
	return _list.get_child_count()


func refresh() -> void:
	var s := Game.sect
	_summary.text = "%s %d  ·  产业收入 %d 两/旬" % [UiText.RES_SILVER, s.silver, Economy.estate_income(s)]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for id in Catalog.ESTATES:
		_list.add_child(_make_card(id))


func _make_card(id: StringName) -> Control:
	var s := Game.sect
	var info: Dictionary = Catalog.ESTATES[id]
	var count := s.estate_count(id)
	var max_count: int = info["max"]
	var price: int = info["price"]
	var income: int = info["income"]

	var btn := Button.new()
	if count >= max_count:
		btn.text = "已达上限"
		btn.disabled = true
	else:
		btn.text = "购置（%d 两）" % price
		btn.theme_type_variation = &"PrimaryButton"
		var afford := s.silver >= price
		btn.disabled = not afford
		btn.tooltip_text = "" if afford else "银两不足"
		btn.pressed.connect(_on_buy_pressed.bind(id))

	var extra := "每处每旬 +%d 两，约 %d 旬回本；现有 %d 处，合计 +%d 两/旬" % [
		income, ceili(float(price) / income), count, count * income]
	return Page.make_card(info["name"], "%d / %d" % [count, max_count], info["desc"], extra, btn)


func _on_buy_pressed(id: StringName) -> void:
	Game.buy_estate(id)
