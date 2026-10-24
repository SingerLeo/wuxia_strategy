class_name SectMapView
extends Control
## 山门地图：画出格子地形、已摆放的建筑，以及摆放时的预览（绿色可放、红色不可放）。
## 只负责"画"和"把鼠标事件变成信号"；摆放规则在 SectMap，状态在 Sect。

signal hovered(cell: Vector2i)            ## 鼠标所在格子；移出地图为 SectMap.NONE
signal clicked(cell: Vector2i, button: int)
signal rotate_requested
signal cancel_requested

const CELL := 64
const PAD := 8

const GROUND := Color("#2a2722")
const GROUND_ALT := Color("#2e2b26")
const ROCK := Color("#4d493f")
const POND := Color("#2b4150")
const GOOD := Color(0.35, 0.75, 0.45, 0.55)
const BAD := Color(0.85, 0.3, 0.25, 0.55)

var sect: Sect
var selected_id: StringName = &""
var ghost_id: StringName = &""    ## 正在摆放的建筑；空表示没有预览
var ghost_rot: int = 0

var _hover: Vector2i = SectMap.NONE


func _init() -> void:
	custom_minimum_size = Vector2(SectMap.width() * CELL + PAD * 2, SectMap.height() * CELL + PAD * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)


func hover_cell() -> Vector2i:
	return _hover


## 像素位置 -> 格子；不在地图内返回 SectMap.NONE
func cell_at(pos: Vector2) -> Vector2i:
	var c := Vector2i(floori((pos.x - PAD) / CELL), floori((pos.y - PAD) / CELL))
	return c if SectMap.in_bounds(c) else SectMap.NONE


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(PAD, PAD) + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != _hover:
			_hover = c
			hovered.emit(c)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var c := cell_at(event.position)
		clicked.emit(c, event.button_index)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and ghost_id != &"":
			rotate_requested.emit()
			accept_event()
		elif event.keycode == KEY_ESCAPE and ghost_id != &"":
			cancel_requested.emit()
			accept_event()  # 摆放中按 Esc 只取消摆放，不弹出系统菜单


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != SectMap.NONE:
		_hover = SectMap.NONE
		hovered.emit(SectMap.NONE)
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()

	# 底板
	draw_rect(Rect2(Vector2.ZERO, size), ThemeBuilder.PANEL, true)

	# 地形
	for y in SectMap.height():
		for x in SectMap.width():
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			match SectMap.terrain(cell):
				"#":
					draw_rect(r, ROCK, true)
					_center_text(font, "山", r, fs, Color(1, 1, 1, 0.25))
				"~":
					draw_rect(r, POND, true)
					_center_text(font, "水", r, fs, Color(1, 1, 1, 0.25))
				_:
					draw_rect(r, GROUND if (x + y) % 2 == 0 else GROUND_ALT, true)

	# 网格线
	var line := Color(ThemeBuilder.BORDER, 0.6)
	for x in SectMap.width() + 1:
		var px := PAD + x * CELL
		draw_line(Vector2(px, PAD), Vector2(px, PAD + SectMap.height() * CELL), line, 1.0)
	for y in SectMap.height() + 1:
		var py := PAD + y * CELL
		draw_line(Vector2(PAD, py), Vector2(PAD + SectMap.width() * CELL, py), line, 1.0)

	# 已摆放的建筑
	if sect != null:
		for id in sect.layout:
			if id == ghost_id:
				continue  # 正在移动的建筑先不画，免得和预览叠在一起
			_draw_building(font, fs, id)

	# 摆放预览
	if ghost_id != &"" and _hover != SectMap.NONE and sect != null:
		var ok := SectMap.can_place(sect, ghost_id, _hover, ghost_rot)
		for c in SectMap.cells(ghost_id, _hover, ghost_rot):
			if SectMap.in_bounds(c):
				draw_rect(cell_rect(c).grow(-1), GOOD if ok else BAD, true)
		var sz := SectMap.size_of(ghost_id, ghost_rot)
		var box := Rect2(cell_rect(_hover).position, Vector2(sz) * CELL)
		draw_rect(box, Color(1, 1, 1, 0.8) if ok else Color(1, 0.5, 0.45, 0.9), false, 2.0)
		_center_text(font, Catalog.BUILDINGS[ghost_id]["name"], box, fs, Color(1, 1, 1, 0.95))


func _draw_building(font: Font, fs: int, id: StringName) -> void:
	var cells := SectMap.placed_cells(sect, id)
	if cells.is_empty():
		return
	var p: Dictionary = sect.layout[id]
	var sz := SectMap.size_of(id, p["rot"])
	var box := Rect2(cell_rect(Vector2i(p["x"], p["y"])).position, Vector2(sz) * CELL).grow(-2)
	var base := Color(Catalog.BUILDINGS[id]["color"])
	draw_rect(box, base, true)
	draw_rect(box, base.lightened(0.25), false, 2.0)
	if id == selected_id:
		draw_rect(box.grow(2), ThemeBuilder.GOLD, false, 3.0)

	var name_text: String = Catalog.BUILDINGS[id]["name"]
	var level := sect.building_level(id)
	_center_text(font, name_text, Rect2(box.position, Vector2(box.size.x, box.size.y * 0.6)), fs + 2, Color(1, 1, 1, 0.95))
	_center_text(font, "Lv %d" % level, Rect2(box.position + Vector2(0, box.size.y * 0.45), Vector2(box.size.x, box.size.y * 0.5)), fs - 2, Color(1, 1, 1, 0.75))

	# 位置加成标记：▲ 有加成，▼ 受影响
	var f := SectMap.factor(sect, id)
	if f > 1.001 or f < 0.999:
		var mark := "▲" if f > 1.0 else "▼"
		var col := Color("#9be3a0") if f > 1.0 else Color("#ff9a8a")
		draw_string(font, box.position + Vector2(box.size.x - 20, 18), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, col)


func _center_text(font: Font, text: String, rect: Rect2, fs: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(rect.position.x + (rect.size.x - w) / 2.0, rect.position.y + rect.size.y / 2.0 + fs * 0.35)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
