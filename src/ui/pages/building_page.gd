class_name BuildingPage
extends Page
## 建筑：花银两升级门派建筑；每座建筑有每旬的维护费，并提供效果。

var _summary: Label
var _list: VBoxContainer


func _init() -> void:
	super._init()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	box.add_child(Page.make_label("建筑", &"Heading"))
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
	_summary.text = "%s %d  ·  建筑维护 %d 两/旬" % [UiText.RES_SILVER, s.silver, Economy.building_upkeep(s)]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for id in Catalog.BUILDINGS:
		_list.add_child(_make_card(id))


func _make_card(id: StringName) -> Control:
	var s := Game.sect
	var info: Dictionary = Catalog.BUILDINGS[id]
	var level := s.building_level(id)
	var max_level := Economy.building_max_level(id)
	var cost := Economy.next_building_cost(id, level)

	var upkeep_now := 0 if level == 0 else int(info["upkeep"][level - 1])
	var extra := "当前维护费 %d 两/旬" % upkeep_now
	if cost >= 0:
		extra += "  →  升级后 %d 两/旬" % int(info["upkeep"][level])

	var btn := Button.new()
	if cost < 0:
		btn.text = "已满级"
		btn.disabled = true
	else:
		btn.text = ("建造（%d 两）" if level == 0 else "升级（%d 两）") % cost
		btn.theme_type_variation = &"PrimaryButton"
		var afford := s.silver >= cost
		btn.disabled = not afford
		btn.tooltip_text = "" if afford else "银两不足"
		btn.pressed.connect(_on_upgrade_pressed.bind(id))

	var tag := "未建" if level == 0 else "Lv %d / %d" % [level, max_level]
	return Page.make_card(info["name"], tag, info["desc"], extra, btn)


func _on_upgrade_pressed(id: StringName) -> void:
	Game.upgrade_building(id)
