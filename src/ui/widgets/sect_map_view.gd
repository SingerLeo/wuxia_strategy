class_name SectMapView
extends Control
## 山门地图：画出格子地形、已摆放的建筑、摆放预览（绿可放/红不可放）与邻居高亮，
## 并把鼠标操作变成信号。摆放规则在 SectMap，状态在 Sect，这里只管"画"和"听"。
##
## 鼠标：
##   空闲时  左键点击 → clicked；按住建筑拖到别的格子 → drag_started，松开 → dropped
##   摆放中  左键 → clicked（放下）；右键 → clicked(RIGHT)（取消）；滚轮 / R → rotate_requested；Esc → cancel_requested

signal hovered(cell: Vector2i)            ## 鼠标所在格子；移出地图为 SectMap.NONE
signal clicked(cell: Vector2i, button: int)
signal drag_started(cell: Vector2i)       ## 在 cell 处的建筑上按下并拖动
signal dropped(cell: Vector2i)            ## 拖动后松开，cell 为松开处（地图外为 NONE）
signal rotate_requested
signal cancel_requested

const CELL := 64
const PAD := 8

const GROUND := Color("#2a2722")
const GROUND_ALT := Color("#2e2b26")
const GRASS_TUFT := Color("#3d4a35")
const ROCK := Color("#4d493f")
const POND := Color("#2b4150")
const POND_WAVE := Color("#4a6b80")
const GOOD := Color(0.35, 0.75, 0.45, 0.55)
const BAD := Color(0.85, 0.3, 0.25, 0.55)
const LINK_GOOD := Color("#7fd68a")
const LINK_BAD := Color("#ff8a78")

var sect: Sect
var selected_id: StringName = &""
var ghost_id: StringName = &""            ## 正在摆放（新建或移动）的建筑；空表示没有预览
var ghost_rot: int = 0
var ghost_origin: Vector2i = SectMap.NONE ## 预览的左上角格子（由页面按"抓取点"算好）
var links: Dictionary = {}                ## 预览位置会与哪些邻居产生位置影响：{建筑 id: 倍率}

var _hover: Vector2i = SectMap.NONE
var _press_cell: Vector2i = SectMap.NONE
var _armed := false       ## 左键按下、尚未判定是点击还是拖动
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(SectMap.width() * CELL + PAD * 2, SectMap.height() * CELL + PAD * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)


func hover_cell() -> Vector2i:
	return _hover


func is_dragging() -> bool:
	return _dragging


## 像素位置 -> 格子；不在地图内返回 SectMap.NONE
func cell_at(pos: Vector2) -> Vector2i:
	var c := Vector2i(floori((pos.x - PAD) / CELL), floori((pos.y - PAD) / CELL))
	return c if SectMap.in_bounds(c) else SectMap.NONE


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(PAD, PAD) + Vector2(cell) * CELL, Vector2(CELL, CELL))


## 已摆放建筑在画布上的矩形；未摆放返回空矩形
func building_box(id: StringName) -> Rect2:
	if sect == null or not sect.layout.has(id):
		return Rect2()
	var p: Dictionary = sect.layout[id]
	return Rect2(cell_rect(Vector2i(p["x"], p["y"])).position, Vector2(SectMap.size_of(id, p["rot"])) * CELL)


# --- 输入 ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		var left_held: bool = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if _armed and not _dragging and left_held and c != SectMap.NONE and c != _press_cell:
			_armed = false
			_dragging = true
			drag_started.emit(_press_cell)
		if c != _hover:
			_hover = c
			hovered.emit(c)
		queue_redraw()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and ghost_id != &"":
			rotate_requested.emit()
			accept_event()
		elif event.keycode == KEY_ESCAPE and ghost_id != &"":
			cancel_requested.emit()
			accept_event()  # 摆放中按 Esc 只取消摆放，不弹出系统菜单


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var c := cell_at(event.position)
	if event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if ghost_id != &"":
					clicked.emit(c, MOUSE_BUTTON_LEFT)   # 摆放中：按下即放
				else:
					_press_cell = c
					_armed = true                         # 空闲：松开时再判定是点击还是拖动
			MOUSE_BUTTON_RIGHT:
				clicked.emit(c, MOUSE_BUTTON_RIGHT)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if ghost_id != &"":
					rotate_requested.emit()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging:
			_dragging = false
			dropped.emit(c)
		elif _armed:
			_armed = false
			clicked.emit(c, MOUSE_BUTTON_LEFT)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != SectMap.NONE:
		_hover = SectMap.NONE
		hovered.emit(SectMap.NONE)
		queue_redraw()


# --- 绘制 ---

func _draw() -> void:
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()

	draw_rect(Rect2(Vector2.ZERO, size), ThemeBuilder.PANEL, true)
	_draw_terrain(font, fs)

	# 网格线
	var line := Color(ThemeBuilder.BORDER, 0.45)
	for x in SectMap.width() + 1:
		var px := PAD + x * CELL
		draw_line(Vector2(px, PAD), Vector2(px, PAD + SectMap.height() * CELL), line, 1.0)
	for y in SectMap.height() + 1:
		var py := PAD + y * CELL
		draw_line(Vector2(PAD, py), Vector2(PAD + SectMap.width() * CELL, py), line, 1.0)

	if sect == null:
		return

	# 空闲时，鼠标下的建筑高亮
	var hover_id := &""
	if ghost_id == &"" and _hover != SectMap.NONE:
		hover_id = SectMap.building_at(sect, _hover)

	for id in sect.layout:
		if id == ghost_id:
			# 正在移动的建筑：原位置只留一圈淡淡的虚框，真身跟着鼠标
			draw_rect(building_box(id).grow(-3), Color(1, 1, 1, 0.22), false, 1.5)
			continue
		_draw_building(font, fs, id, id == hover_id)

	# 邻居高亮（摆放预览时）
	for id in links:
		var box := building_box(id)
		if box.size == Vector2.ZERO:
			continue
		var good: bool = float(links[id]) > 1.0
		var col := LINK_GOOD if good else LINK_BAD
		draw_rect(box.grow(1), col, false, 3.0)
		var tag := "%s ×%.2f" % ["▲" if good else "▼", float(links[id])]
		_text_outlined(font, tag, box.position + Vector2(6, 18), fs - 2, col)

	# 摆放预览
	if ghost_id != &"" and ghost_origin != SectMap.NONE:
		var ok := SectMap.can_place(sect, ghost_id, ghost_origin, ghost_rot)
		for c in SectMap.cells(ghost_id, ghost_origin, ghost_rot):
			if SectMap.in_bounds(c):
				draw_rect(cell_rect(c).grow(-1), GOOD if ok else BAD, true)
		var box := Rect2(cell_rect(ghost_origin).position, Vector2(SectMap.size_of(ghost_id, ghost_rot)) * CELL)
		draw_rect(box, Color(1, 1, 1, 0.85) if ok else Color(1, 0.55, 0.5, 0.95), false, 2.0)
		_center_text(font, Catalog.BUILDINGS[ghost_id]["name"], box, fs + 2, Color(1, 1, 1, 0.95), true)


func _draw_terrain(font: Font, fs: int) -> void:
	for y in SectMap.height():
		for x in SectMap.width():
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			match SectMap.terrain(cell):
				"#":
					draw_rect(r, GROUND, true)
					draw_style_box(_box(ROCK, ROCK.lightened(0.18), 12, 1), r.grow(-4))
					draw_style_box(_box(ROCK.lightened(0.08), Color(0, 0, 0, 0), 8, 0), Rect2(r.position + Vector2(10, 9), Vector2(24, 16)))
					_center_text(font, "山", r, fs, Color(1, 1, 1, 0.3), false)
				"~":
					draw_rect(r, POND, true)
					for k in 2:
						var y0 := r.position.y + 20 + k * 22
						var wave := PackedVector2Array()
						for i in 5:
							wave.append(Vector2(r.position.x + 8 + i * 12, y0 + (3 if i % 2 == 0 else -3)))
						draw_polyline(wave, POND_WAVE, 1.5, true)
					_center_text(font, "水", r, fs, Color(1, 1, 1, 0.22), false)
				_:
					draw_rect(r, GROUND if (x + y) % 2 == 0 else GROUND_ALT, true)
					# 固定位置的草丛：用格子坐标算一个稳定的"随机"，每次重绘位置不变
					var h := (x * 73856093) ^ (y * 19349663)
					if absi(h) % 7 == 0:
						var o := r.position + Vector2(10 + absi(h / 7) % 36, 14 + absi(h / 11) % 34)
						draw_line(o, o + Vector2(-2, -6), GRASS_TUFT, 1.5)
						draw_line(o, o + Vector2(1, -7), GRASS_TUFT, 1.5)
						draw_line(o, o + Vector2(4, -5), GRASS_TUFT, 1.5)


func _draw_building(font: Font, fs: int, id: StringName, hot: bool) -> void:
	var box := building_box(id).grow(-3)
	if box.size == Vector2.ZERO:
		return
	var info: Dictionary = Catalog.BUILDINGS[id]
	var base := Color(info["color"])

	# 阴影 → 本体（圆角）→ 顶部高光
	draw_style_box(_box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 10, 0), Rect2(box.position + Vector2(3, 5), box.size))
	draw_style_box(_box(base, base.lightened(0.28), 10, 2), box)
	draw_rect(Rect2(box.position + Vector2(8, 7), Vector2(box.size.x - 16, 3)), Color(1, 1, 1, 0.22), true)

	# 水印大字
	_center_text(font, info["glyph"], box, int(fs * 2.4), Color(1, 1, 1, 0.10), false)

	# 名称与等级
	var level := sect.building_level(id)
	_center_text(font, info["name"], Rect2(box.position, Vector2(box.size.x, box.size.y * 0.62)), fs + 2, Color(1, 1, 1, 0.97), true)
	_center_text(font, "Lv %d" % level, Rect2(box.position + Vector2(0, box.size.y * 0.42), Vector2(box.size.x, box.size.y * 0.5)), fs - 2, Color(1, 1, 1, 0.8), true)

	# 位置加成标记
	var f := SectMap.factor(sect, id)
	if f > 1.001 or f < 0.999:
		var good := f > 1.0
		_text_outlined(font, "▲" if good else "▼", box.position + Vector2(box.size.x - 20, 18), fs - 2, LINK_GOOD if good else LINK_BAD)

	if id == selected_id:
		draw_rect(box.grow(3), ThemeBuilder.GOLD, false, 3.0)
	elif hot:
		draw_rect(box.grow(2), Color(1, 1, 1, 0.6), false, 2.0)


# --- 小工具 ---

func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s


func _center_text(font: Font, text: String, rect: Rect2, fs: int, color: Color, outline: bool) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(rect.position.x + (rect.size.x - w) / 2.0, rect.position.y + rect.size.y / 2.0 + fs * 0.35)
	if outline:
		_text_outlined(font, text, pos, fs, color)
	else:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _text_outlined(font: Font, text: String, pos: Vector2, fs: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
