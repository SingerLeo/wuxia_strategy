class_name RadarChart
extends Control
## 雷达图（多边形）。第一项在正上方，顺时针排列。
## 数据：labels 为各轴名称，values 为 0~1 的比例，texts 为各轴旁显示的数字。

const RINGS := 4

var _labels: Array[String] = []
var _values: Array[float] = []
var _texts: Array[String] = []


func _init() -> void:
	custom_minimum_size = Vector2(360, 330)


func set_data(labels: Array[String], values: Array[float], texts: Array[String]) -> void:
	_labels = labels
	_values = values
	_texts = texts
	queue_redraw()


func axis_count() -> int:
	return _values.size()


func values() -> Array[float]:
	return _values


func _angle(i: int, n: int) -> float:
	return -PI / 2.0 + TAU * i / n


func _draw() -> void:
	var n := _values.size()
	if n < 3:
		return
	var center := size / 2.0
	var radius := minf(size.x * 0.5 - 70.0, size.y * 0.5 - 32.0)
	if radius <= 10.0:
		return

	# 网格：同心多边形与轴线
	for r in range(1, RINGS + 1):
		var ring := PackedVector2Array()
		for i in n:
			ring.append(center + Vector2.from_angle(_angle(i, n)) * radius * r / RINGS)
		ring.append(ring[0])
		draw_polyline(ring, ThemeBuilder.BORDER, 1.0, true)
	for i in n:
		draw_line(center, center + Vector2.from_angle(_angle(i, n)) * radius, ThemeBuilder.BORDER, 1.0, true)

	# 数据多边形
	var pts := PackedVector2Array()
	for i in n:
		var v := clampf(_values[i], 0.04, 1.0)
		pts.append(center + Vector2.from_angle(_angle(i, n)) * radius * v)
	draw_colored_polygon(pts, Color(ThemeBuilder.GOLD, 0.28))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, ThemeBuilder.GOLD, 2.0, true)
	for p in pts:
		draw_circle(p, 3.5, ThemeBuilder.GOLD)

	# 轴标签
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size() + 3
	for i in n:
		var text := "%s %s" % [_labels[i], _texts[i]]
		var dir := Vector2.from_angle(_angle(i, n))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var anchor := center + dir * (radius + 18.0)
		var pos := Vector2(anchor.x - w / 2.0 + dir.x * w / 2.0, anchor.y + fs * 0.35 + dir.y * fs * 0.6)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ThemeBuilder.TEXT)
