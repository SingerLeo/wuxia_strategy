class_name SectMapView
extends Control
## 山门地图：画出地形（山、河、树）、已摆放的房屋、摆放预览（绿可放/红不可放）与邻居高亮，
## 并把鼠标操作变成信号。摆放规则在 SectMap，状态在 Sect，画法在 MapArt，这里只管"组织"和"听"。
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

const GOOD := Color(0.35, 0.75, 0.45, 0.45)
const BAD := Color(0.85, 0.3, 0.25, 0.5)
const LINK_GOOD := Color("#7fd68a")
const LINK_BAD := Color("#ff8a78")
const ANIM_STEP := 0.08   ## 水波与炊烟的重绘间隔（秒）

var sect: Sect
var selected_id: StringName = &""
var ghost_id: StringName = &""            ## 正在摆放（新建或移动）的建筑；空表示没有预览
var ghost_rot: int = 0
var ghost_origin: Vector2i = SectMap.NONE ## 预览的左上角格子（由页面按"抓取点"算好）
var links: Dictionary = {}                ## 预览位置会与哪些邻居产生位置影响：{建筑 id: 倍率}
var animate := true                       ## 水波、炊烟动画；截图或测试时可以关掉

var _hover: Vector2i = SectMap.NONE
var _press_cell: Vector2i = SectMap.NONE
var _armed := false       ## 左键按下、尚未判定是点击还是拖动
var _dragging := false
var _time := 0.0
var _acc := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SectMap.width() * CELL + PAD * 2, SectMap.height() * CELL + PAD * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_time += delta
	_acc += delta
	if _acc >= ANIM_STEP:
		_acc = 0.0
		queue_redraw()


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
	_draw_terrain()

	if sect == null:
		return

	# 空闲时，鼠标下的建筑高亮
	var hover_id := &""
	if ghost_id == &"" and _hover != SectMap.NONE:
		hover_id = SectMap.building_at(sect, _hover)

	# 建筑按"从上到下"的顺序画，下面的房子可以盖住上面房子的檐影
	var ids: Array = sect.layout.keys()
	ids.sort_custom(func(a, b) -> bool: return int(sect.layout[a]["y"]) < int(sect.layout[b]["y"]))
	for id in ids:
		if id == ghost_id:
			# 正在移动的建筑：原位置只留一圈淡淡的虚框，真身跟着鼠标
			draw_rect(building_box(id).grow(-3), Color(1, 1, 1, 0.3), false, 1.5)
			continue
		var box := building_box(id).grow(-3)
		MapArt.draw_house(self, id, box, sect.building_level(id), 1.0, _time)
		_draw_markers(font, fs, id, box, id == hover_id)

	# 邻居高亮（摆放预览时）
	for id in links:
		var box := building_box(id)
		if box.size == Vector2.ZERO:
			continue
		var good: bool = float(links[id]) > 1.0
		var col := LINK_GOOD if good else LINK_BAD
		draw_rect(box.grow(1), col, false, 3.0)
		_text_outlined(font, "%s ×%.2f" % ["▲" if good else "▼", float(links[id])], box.position + Vector2(6, 18), fs - 2, col)

	# 摆放预览：半透明的房子 + 绿/红的占地提示
	if ghost_id != &"" and ghost_origin != SectMap.NONE:
		var ok := SectMap.can_place(sect, ghost_id, ghost_origin, ghost_rot)
		var box := Rect2(cell_rect(ghost_origin).position, Vector2(SectMap.size_of(ghost_id, ghost_rot)) * CELL).grow(-3)
		MapArt.draw_house(self, ghost_id, box, maxi(1, sect.building_level(ghost_id)), 0.62, _time)
		for c in SectMap.cells(ghost_id, ghost_origin, ghost_rot):
			if SectMap.in_bounds(c):
				draw_rect(cell_rect(c).grow(-1), GOOD if ok else BAD, true)
		draw_rect(box.grow(3), Color(1, 1, 1, 0.9) if ok else Color(1, 0.55, 0.5, 0.95), false, 2.0)


func _draw_terrain() -> void:
	var w := SectMap.width()
	var h := SectMap.height()
	# 第一层：地面、水面
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			if SectMap.terrain(cell) == "~":
				MapArt.draw_water(self, r, x, y,
					_is_water(x, y - 1), _is_water(x + 1, y), _is_water(x, y + 1), _is_water(x - 1, y),
					_is_water(x - 1, y - 1), _is_water(x + 1, y - 1), _is_water(x + 1, y + 1), _is_water(x - 1, y + 1), _time)
			else:
				MapArt.draw_ground(self, r, x, y)

	# 网格线（淡淡的，帮助对位）
	var line := Color(0, 0, 0, 0.18)
	for x in w + 1:
		var px := PAD + x * CELL
		draw_line(Vector2(px, PAD), Vector2(px, PAD + h * CELL), line, 1.0)
	for y in h + 1:
		var py := PAD + y * CELL
		draw_line(Vector2(PAD, py), Vector2(PAD + w * CELL, py), line, 1.0)

	# 第二层：树木与山峰，从上到下画，山脚盖住后面的山
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			match SectMap.terrain(cell):
				"#":
					MapArt.draw_mountain(self, r, x, y)
				".":
					var hh := MapArt.hash2(x, y, 2)
					if hh % 11 == 3:
						MapArt.draw_tree(self, r.position + Vector2(20 + hh % 24, 52), 0.9)
					elif hh % 17 == 5:
						MapArt.draw_bamboo(self, r.position + Vector2(32, 54))


## 河流越界的一侧视为"水还在延伸"，这样河流从地图边缘流出去时不会画出一道岸
func _is_water(x: int, y: int) -> bool:
	var c := Vector2i(x, y)
	return not SectMap.in_bounds(c) or SectMap.terrain(c) == "~"


## 位置加成标记，以及选中/悬停的描边
func _draw_markers(font: Font, fs: int, id: StringName, box: Rect2, hot: bool) -> void:
	var f := SectMap.factor(sect, id)
	if f > 1.001 or f < 0.999:
		var good := f > 1.0
		_text_outlined(font, "▲" if good else "▼", box.position + Vector2(box.size.x - 22, 22), fs, LINK_GOOD if good else LINK_BAD)
	if id == selected_id:
		draw_rect(box.grow(4), ThemeBuilder.GOLD, false, 3.0)
	elif hot:
		draw_rect(box.grow(3), Color(1, 1, 1, 0.65), false, 2.0)


func _text_outlined(font: Font, text: String, pos: Vector2, fs: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
