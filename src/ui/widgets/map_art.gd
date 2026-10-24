class_name MapArt
extends RefCounted
## 山门地图的程序化美术：用线条和多边形画出中式房屋、山峰、河流、树木。不依赖任何图片资源。
## 所有 draw_* 函数都要在某个 CanvasItem 的 _draw() 里调用，ci 就是那个 CanvasItem。

# --- 调色板 ---
const ROOF := Color("#4b5058")          # 青瓦
const ROOF_DARK := Color("#34383f")
const ROOF_LIGHT := Color("#6a727d")
const WALL := Color("#d9d0bb")          # 粉墙
const PILLAR := Color("#8f2f26")        # 朱红柱
const WOOD := Color("#5a3a24")
const STONE := Color("#837e71")         # 台基
const STONE_DARK := Color("#5c584e")
const PAVING := Color("#6f6b5f")
const GOLD := Color("#d9b45c")
const PLAQUE := Color("#6b1f1a")

const WATER_DEEP := Color("#26475a")
const WATER_MID := Color("#2f5870")
const WATER_LIGHT := Color("#5b8aa3")
const BANK := Color("#7d6e4c")
const BANK_LIGHT := Color("#9c8a60")

const MOUNT_LIT := Color("#7b7462")
const MOUNT_SHADE := Color("#46423a")
const SNOW := Color("#e4e6e2")


## 格子坐标的稳定"随机数"：同一格每次重绘结果一样
static func hash2(x: int, y: int, salt: int = 0) -> int:
	return absi(((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff)


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)


static func _ellipse(center: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


## 去掉相邻的重复点，避免多边形退化导致绘制报错
static func _poly(ci: CanvasItem, pts: Array, color: Color) -> void:
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.5:
			clean.append(p)
	if clean.size() > 2 and clean[0].distance_to(clean[clean.size() - 1]) < 0.5:
		clean.remove_at(clean.size() - 1)
	if clean.size() >= 3:
		ci.draw_colored_polygon(clean, color)


static func _box(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s


# =====================================================================
#  地形
# =====================================================================

static func draw_ground(ci: CanvasItem, r: Rect2, x: int, y: int) -> void:
	var h := hash2(x, y)
	var tint := (h % 13 - 6) * 0.006
	var base := Color(0.215 + tint, 0.262 + tint, 0.168 + tint)       # 偏青绿的泥土地
	ci.draw_rect(r, base, true)
	# 地上深一块浅一块的色斑，避免整片一个颜色
	if h % 3 == 1:
		ci.draw_colored_polygon(_ellipse(r.position + Vector2(18 + (h / 3) % 28, 20 + (h / 5) % 26), 14 + h % 8, 9 + h % 5),
			Color(0.0, 0.0, 0.0, 0.07))
	# 草丛
	if h % 5 == 0:
		var o := r.position + Vector2(8 + (h / 5) % 40, 22 + (h / 13) % 30)
		var g := Color("#3f4d36")
		ci.draw_line(o, o + Vector2(-3, -7), g, 1.5)
		ci.draw_line(o, o + Vector2(1, -9), g, 1.5)
		ci.draw_line(o, o + Vector2(4, -6), g, 1.5)
	# 小石子
	if h % 17 == 3:
		ci.draw_circle(r.position + Vector2(14 + (h / 17) % 36, 14 + (h / 7) % 36), 2.0, Color("#55514a"))


## 装饰树（画在地面层，之后会被建筑盖住）。pos 是树根的位置。
static func draw_tree(ci: CanvasItem, pos: Vector2, s: float = 1.0) -> void:
	ci.draw_colored_polygon(_ellipse(pos + Vector2(2, 2), 13 * s, 5 * s), Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(pos + Vector2(-2 * s, -12 * s), Vector2(4 * s, 12 * s)), Color("#4a3322"), true)
	ci.draw_circle(pos + Vector2(0, -22 * s), 13 * s, Color("#2c452b"))
	ci.draw_circle(pos + Vector2(-6 * s, -17 * s), 9 * s, Color("#34513a"))
	ci.draw_circle(pos + Vector2(6 * s, -18 * s), 9 * s, Color("#34513a"))
	ci.draw_circle(pos + Vector2(-2 * s, -26 * s), 7 * s, Color("#47693f"))


## 竹丛
static func draw_bamboo(ci: CanvasItem, pos: Vector2) -> void:
	for i in 4:
		var x := pos.x - 9 + i * 6
		var top := pos.y - 30 - (i % 2) * 6
		ci.draw_line(Vector2(x, pos.y), Vector2(x + (i - 1.5) * 1.5, top), Color("#56794a"), 2.5)
		ci.draw_line(Vector2(x + 1, pos.y - 12), Vector2(x + 6, pos.y - 17), Color("#6f9a5f"), 1.5)
		ci.draw_line(Vector2(x, pos.y - 20), Vector2(x - 6, pos.y - 25), Color("#6f9a5f"), 1.5)


## 一格水面。上下左右是否也是水由调用者算好（n/e/s/w），越界的一侧按"河流延伸出去"处理。
## nw/ne/se/sw 表示斜角方向是不是水，用来补河岸的凹角。t 是动画时间（秒）。
static func draw_water(ci: CanvasItem, r: Rect2, x: int, y: int, n: bool, e: bool, s: bool, w: bool,
		nw: bool, ne: bool, se: bool, sw: bool, t: float) -> void:
	var h := hash2(x, y, 5)
	ci.draw_rect(r, WATER_DEEP if h % 2 == 0 else WATER_MID, true)

	# 流动的水纹：每格 3 条，沿水平方向缓缓漂移
	for k in 3:
		var yy := r.position.y + 14 + k * 20 + (h % 5)
		var shift := fmod(t * (10 + k * 4) + h % 40, 40.0)
		var line := PackedVector2Array()
		for i in 6:
			var xx := r.position.x - 40 + shift + i * 14
			line.append(Vector2(xx, yy + (3.0 if i % 2 == 0 else -3.0)))
		# 只保留落在这一格里的部分，避免画到别的格子上
		var clipped := PackedVector2Array()
		for p in line:
			clipped.append(Vector2(clampf(p.x, r.position.x + 2, r.end.x - 2), p.y))
		ci.draw_polyline(clipped, Color(WATER_LIGHT, 0.35), 1.5, true)

	# 河岸：邻格不是水的那一侧画一条土岸
	var bw := 7.0
	if not n:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, bw)), BANK, true)
		ci.draw_rect(Rect2(r.position + Vector2(0, bw), Vector2(r.size.x, 2)), Color(BANK_LIGHT, 0.7), true)
	if not s:
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bw), Vector2(r.size.x, bw)), BANK, true)
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bw - 2), Vector2(r.size.x, 2)), Color(BANK_LIGHT, 0.7), true)
	if not w:
		ci.draw_rect(Rect2(r.position, Vector2(bw, r.size.y)), BANK, true)
		ci.draw_rect(Rect2(r.position + Vector2(bw, 0), Vector2(2, r.size.y)), Color(BANK_LIGHT, 0.7), true)
	if not e:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - bw, 0), Vector2(bw, r.size.y)), BANK, true)
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - bw - 2, 0), Vector2(2, r.size.y)), Color(BANK_LIGHT, 0.7), true)
	# 凹角：两条相邻边都是水，但斜角是陆地
	if n and w and not nw:
		ci.draw_rect(Rect2(r.position, Vector2(bw, bw)), BANK, true)
	if n and e and not ne:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - bw, 0), Vector2(bw, bw)), BANK, true)
	if s and w and not sw:
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bw), Vector2(bw, bw)), BANK, true)
	if s and e and not se:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - bw, r.size.y - bw), Vector2(bw, bw)), BANK, true)

	# 水面上偶尔一点反光
	if h % 4 == 0:
		var o := r.position + Vector2(14 + (h / 4) % 30, 20 + (h / 9) % 24)
		ci.draw_line(o, o + Vector2(10, 0), Color(1, 1, 1, 0.18), 1.5)


## 一座山峰。r 是所在格；越靠下的格子要后画，这样山脚能盖住后面的山。
static func draw_mountain(ci: CanvasItem, r: Rect2, x: int, y: int) -> void:
	var h := hash2(x, y, 9)
	var cx := r.position.x + r.size.x * 0.5 + (h % 11 - 5)
	var base := r.end.y - 4.0
	var top := base - (60 + h % 26)
	var hw := 38.0 + (h / 3) % 10

	ci.draw_colored_polygon(_ellipse(Vector2(cx, base), hw + 8, 8), Color(0, 0, 0, 0.3))

	# 后面的小山头（偶尔出现，让山脉有层次）
	if h % 3 == 0:
		var cx2 := cx - hw * 0.9
		var top2 := base - 30.0
		_poly(ci, [Vector2(cx2 - 22, base), Vector2(cx2, top2), Vector2(cx2 + 4, base)], MOUNT_LIT.darkened(0.12))
		_poly(ci, [Vector2(cx2 + 4, base), Vector2(cx2, top2), Vector2(cx2 + 24, base)], MOUNT_SHADE.darkened(0.1))

	var peak := Vector2(cx, top)
	var mid := Vector2(cx + 5, base)
	_poly(ci, [Vector2(cx - hw, base), peak, mid], MOUNT_LIT)                     # 向阳面
	_poly(ci, [mid, peak, Vector2(cx + hw, base)], MOUNT_SHADE)                   # 背阴面
	ci.draw_line(peak, mid, Color(0, 0, 0, 0.35), 1.5)                            # 山脊
	ci.draw_line(peak, Vector2(cx - hw * 0.45, base - 14), Color(1, 1, 1, 0.10), 1.5)
	ci.draw_line(peak + Vector2(0, 14), Vector2(cx + hw * 0.5, base - 6), Color(0, 0, 0, 0.22), 1.5)
	# 雪顶
	if top < base - 66:
		_poly(ci, [peak, Vector2(cx - 9, top + 15), Vector2(cx - 2, top + 11), Vector2(cx + 4, top + 17), Vector2(cx + 10, top + 12)], SNOW)
	# 山脚的小松树
	draw_tree(ci, Vector2(cx - hw * 0.55, base + 1), 0.55)
	if h % 2 == 0:
		draw_tree(ci, Vector2(cx + hw * 0.7, base + 2), 0.45)


# =====================================================================
#  房屋
# =====================================================================

## 画一座建筑。box 是它占地的矩形；level 用来画等级牌；alpha 用于摆放预览；t 是动画时间（炊烟）。
static func draw_house(ci: Control, id: StringName, box: Rect2, level: int, alpha: float, t: float) -> void:
	var font := ci.get_theme_default_font()
	var fs := ci.get_theme_default_font_size()
	var accent := Color(Catalog.BUILDINGS[id]["color"])
	var name_text: String = Catalog.BUILDINGS[id]["name"]

	# 地面投影与台基
	ci.draw_style_box(_box(Color(0, 0, 0, 0.32 * alpha), Color(0, 0, 0, 0), 12, 0), Rect2(box.position + Vector2(4, 6), box.size))
	ci.draw_style_box(_box(_a(STONE, alpha), _a(STONE_DARK, alpha), 8, 2), box)

	var inner := box.grow(-7)
	var plaque_at := Vector2.ZERO
	match id:
		&"dojo": plaque_at = _dojo(ci, inner, accent, alpha, t)
		&"library": plaque_at = _library(ci, inner, accent, alpha)
		&"clinic": plaque_at = _clinic(ci, inner, accent, alpha)
		&"kitchen": plaque_at = _kitchen(ci, inner, accent, alpha, t)
		_: plaque_at = _hall(ci, inner, accent, alpha)

	_plaque(ci, font, fs, plaque_at, name_text, alpha)
	_level_chip(ci, font, fs, box, level, alpha)


## 匾额：深红底、金边金字
static func _plaque(ci: CanvasItem, font: Font, fs: int, center: Vector2, text: String, alpha: float) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16
	var rect := Rect2(center - Vector2(w / 2.0, (fs + 8) / 2.0), Vector2(w, fs + 8))
	ci.draw_style_box(_box(_a(PLAQUE, alpha), _a(GOLD, alpha), 3, 2), rect)
	ci.draw_string(font, Vector2(rect.position.x + 8, rect.position.y + fs + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _a(GOLD.lightened(0.15), alpha))


static func _level_chip(ci: CanvasItem, font: Font, fs: int, box: Rect2, level: int, alpha: float) -> void:
	var text := "Lv %d" % level
	var f := maxi(fs - 5, 10)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 10
	var rect := Rect2(box.end - Vector2(w + 4, f + 10), Vector2(w, f + 6))
	ci.draw_style_box(_box(Color(0.08, 0.08, 0.07, 0.82 * alpha), _a(GOLD, alpha * 0.8), 4, 1), rect)
	ci.draw_string(font, Vector2(rect.position.x + 5, rect.position.y + f + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, f, _a(GOLD, alpha))


## 歇山/庑殿式屋顶（俯视）：四个坡面 + 瓦垄 + 正脊 + 脊兽。r 是屋顶的矩形，长边方向就是正脊方向。
static func _roof(ci: CanvasItem, r: Rect2, accent: Color, alpha: float) -> void:
	var horizontal := r.size.x >= r.size.y
	var L := maxf(r.size.x, r.size.y)       # 沿正脊的长度
	var W := minf(r.size.x, r.size.y)       # 垂直于正脊的宽度
	var half := W / 2.0
	# (u, v) → 画布坐标：u 沿正脊，v 垂直于正脊
	var P := func(u: float, v: float) -> Vector2:
		return Vector2(r.position.x + u, r.position.y + v) if horizontal else Vector2(r.position.x + v, r.position.y + u)

	# 屋檐投下的影子
	ci.draw_style_box(_box(Color(0, 0, 0, 0.30 * alpha), Color(0, 0, 0, 0), 6, 0), Rect2(r.position + Vector2(3, 5), r.size))

	var ru0: float = minf(half, L / 2.0)
	var ru1: float = L - ru0
	var c_top := _a(ROOF_LIGHT, alpha)
	var c_bot := _a(ROOF_DARK, alpha)
	var c_end := _a(ROOF, alpha)
	_poly(ci, [P.call(0, 0), P.call(L, 0), P.call(ru1, half), P.call(ru0, half)], c_top)
	_poly(ci, [P.call(0, W), P.call(L, W), P.call(ru1, half), P.call(ru0, half)], c_bot)
	_poly(ci, [P.call(0, 0), P.call(0, W), P.call(ru0, half)], c_end)
	_poly(ci, [P.call(L, 0), P.call(L, W), P.call(ru1, half)], c_end)

	# 瓦垄：平行于正脊的细线，间隔 5 像素
	var tile := Color(0, 0, 0, 0.22 * alpha)
	var d := 4.0
	while d < half - 1.0:
		ci.draw_line(P.call(d, d), P.call(L - d, d), tile, 1.0)
		ci.draw_line(P.call(d, W - d), P.call(L - d, W - d), tile, 1.0)
		d += 5.0

	# 四条戗脊（屋角斜线）和正脊
	var edge := Color(0, 0, 0, 0.45 * alpha)
	ci.draw_line(P.call(0, 0), P.call(ru0, half), edge, 1.5)
	ci.draw_line(P.call(0, W), P.call(ru0, half), edge, 1.5)
	ci.draw_line(P.call(L, 0), P.call(ru1, half), edge, 1.5)
	ci.draw_line(P.call(L, W), P.call(ru1, half), edge, 1.5)
	var ridge_col := _a(accent.lightened(0.15), alpha)
	if ru1 - ru0 > 2.0:
		ci.draw_line(P.call(ru0, half), P.call(ru1, half), ridge_col, 4.0)
	ci.draw_circle(P.call(ru0, half), 3.5, ridge_col)       # 脊兽（简化为圆饰）
	ci.draw_circle(P.call(ru1, half), 3.5, ridge_col)
	# 屋檐外缘
	ci.draw_rect(r, Color(0, 0, 0, 0.55 * alpha), false, 2.0)


## 前脸：粉墙、朱红柱、木门、窗格
static func _facade(ci: CanvasItem, r: Rect2, alpha: float) -> void:
	ci.draw_rect(r, _a(WALL, alpha), true)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), _a(ROOF_DARK, alpha), true)             # 檐下阴影
	var n := maxi(3, int(r.size.x / 30.0))
	for i in n + 1:
		var px := r.position.x + r.size.x * i / n
		ci.draw_rect(Rect2(px - 2.5, r.position.y, 5, r.size.y), _a(PILLAR, alpha), true)
	# 中间一扇门，两侧窗格
	var cx := r.position.x + r.size.x / 2.0
	var door := Rect2(cx - 9, r.position.y + 4, 18, r.size.y - 4)
	ci.draw_rect(door, _a(WOOD, alpha), true)
	ci.draw_line(Vector2(cx, door.position.y), Vector2(cx, door.end.y), Color(0, 0, 0, 0.5 * alpha), 1.0)
	ci.draw_circle(Vector2(cx - 3, door.position.y + door.size.y * 0.55), 1.4, _a(GOLD, alpha))
	ci.draw_circle(Vector2(cx + 3, door.position.y + door.size.y * 0.55), 1.4, _a(GOLD, alpha))
	for sx in [r.position.x + r.size.x * 0.22, r.position.x + r.size.x * 0.78]:
		var win := Rect2(sx - 7, r.position.y + 6, 14, r.size.y - 10)
		if win.size.y > 4:
			ci.draw_rect(win, _a(Color("#4a3a2a"), alpha), true)
			ci.draw_line(Vector2(sx, win.position.y), Vector2(sx, win.end.y), _a(WALL, alpha), 1.0)
			ci.draw_line(Vector2(win.position.x, win.position.y + win.size.y / 2.0), Vector2(win.end.x, win.position.y + win.size.y / 2.0), _a(WALL, alpha), 1.0)


## 普通厅堂：上面屋顶、下面前脸。返回匾额的位置。
static func _hall(ci: CanvasItem, r: Rect2, accent: Color, alpha: float) -> Vector2:
	var facade_h := clampf(r.size.y * 0.24, 18.0, 34.0)
	var roof := Rect2(r.position, Vector2(r.size.x, r.size.y - facade_h + 4))
	_facade(ci, Rect2(r.position + Vector2(4, r.size.y - facade_h), Vector2(r.size.x - 8, facade_h)), alpha)
	_roof(ci, roof, accent, alpha)
	return roof.position + Vector2(roof.size.x / 2.0, roof.size.y - 14)


## 药庐：厅堂 + 门前晾药的竹匾
static func _clinic(ci: CanvasItem, r: Rect2, accent: Color, alpha: float) -> Vector2:
	var at := _hall(ci, r, accent, alpha)
	var herbs := [Color("#c9a24a"), Color("#8a4a3a"), Color("#6f8a4a")]
	for i in 3:
		var c := Vector2(r.position.x + 14 + i * 16, r.end.y - 6)
		ci.draw_circle(c, 7, _a(Color("#8a6a3a"), alpha))
		ci.draw_circle(c, 5.2, _a(herbs[i], alpha))
	return at


## 伙房：厅堂 + 烟囱与炊烟
static func _kitchen(ci: CanvasItem, r: Rect2, accent: Color, alpha: float, t: float) -> Vector2:
	var at := _hall(ci, r, accent, alpha)
	var chimney := Rect2(r.end.x - 26, r.position.y + 8, 12, 18)
	ci.draw_rect(chimney, _a(STONE_DARK, alpha), true)
	ci.draw_rect(Rect2(chimney.position - Vector2(2, 3), Vector2(16, 5)), _a(ROOF_DARK, alpha), true)
	for i in 3:
		var phase := fmod(t * 0.5 + i * 0.33, 1.0)
		var p := chimney.position + Vector2(6 + sin(phase * 6.0 + i) * 4.0, -4 - phase * 22.0)
		ci.draw_circle(p, 3.0 + phase * 4.0, Color(0.85, 0.85, 0.85, (1.0 - phase) * 0.45 * alpha))
	return at


## 藏经阁：两层重檐、窗格更多
static func _library(ci: CanvasItem, r: Rect2, accent: Color, alpha: float) -> Vector2:
	var facade_h := clampf(r.size.y * 0.2, 18.0, 34.0)
	_facade(ci, Rect2(r.position + Vector2(4, r.size.y - facade_h), Vector2(r.size.x - 8, facade_h)), alpha)
	var lower := Rect2(r.position + Vector2(0, r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.75 - facade_h + 4))
	_roof(ci, lower, accent, alpha)
	var upper := Rect2(r.position + Vector2(r.size.x * 0.14, 0), Vector2(r.size.x * 0.72, r.size.y * 0.36))
	_roof(ci, upper, accent, alpha)
	# 上层的一排小窗
	var wy := upper.end.y + 2
	for i in 3:
		ci.draw_rect(Rect2(upper.position.x + upper.size.x * (0.2 + i * 0.28), wy, 7, 8), _a(WOOD, alpha), true)
	return lower.position + Vector2(lower.size.x / 2.0, lower.size.y - 14)


## 练武场：北面一间厅堂，南面是青石铺的演武场，有兵器架、木人桩和太极图
static func _dojo(ci: CanvasItem, r: Rect2, accent: Color, alpha: float, _t: float) -> Vector2:
	var hall_h := r.size.y * 0.40
	var hall := Rect2(r.position + Vector2(10, 0), Vector2(r.size.x - 20, hall_h))
	var yard := Rect2(r.position + Vector2(0, hall_h + 4), Vector2(r.size.x, r.size.y - hall_h - 4))

	# 演武场地面：青石板
	ci.draw_rect(yard, _a(PAVING, alpha), true)
	var step := 24.0
	var gx := yard.position.x + step
	while gx < yard.end.x:
		ci.draw_line(Vector2(gx, yard.position.y), Vector2(gx, yard.end.y), Color(0, 0, 0, 0.22 * alpha), 1.0)
		gx += step
	var gy := yard.position.y + step
	while gy < yard.end.y:
		ci.draw_line(Vector2(yard.position.x, gy), Vector2(yard.end.x, gy), Color(0, 0, 0, 0.22 * alpha), 1.0)
		gy += step
	ci.draw_rect(yard, _a(STONE_DARK, alpha), false, 2.0)

	# 太极图
	var c := yard.get_center()
	var rad := minf(yard.size.x, yard.size.y) * 0.28
	ci.draw_circle(c, rad + 3, _a(STONE_DARK, alpha))
	ci.draw_circle(c, rad, _a(Color("#d8d2c0"), alpha))
	var half_disc: Array = []
	for i in 17:
		var ang := -PI / 2.0 + PI * i / 16.0
		half_disc.append(c + Vector2(cos(ang), sin(ang)) * rad)
	_poly(ci, half_disc, _a(Color("#2a2724"), alpha))                  # 右半边是黑
	ci.draw_circle(c + Vector2(0, -rad / 2.0), rad / 2.0, _a(Color("#2a2724"), alpha))
	ci.draw_circle(c + Vector2(0, rad / 2.0), rad / 2.0, _a(Color("#d8d2c0"), alpha))
	ci.draw_circle(c + Vector2(0, -rad / 2.0), rad / 7.0, _a(Color("#d8d2c0"), alpha))
	ci.draw_circle(c + Vector2(0, rad / 2.0), rad / 7.0, _a(Color("#2a2724"), alpha))

	# 兵器架（左右各一）
	for side in [0, 1]:
		var rx := yard.position.x + 6 if side == 0 else yard.end.x - 16
		ci.draw_rect(Rect2(rx, yard.position.y + 10, 10, yard.size.y * 0.5), _a(WOOD, alpha), true)
		for k in 4:
			ci.draw_line(Vector2(rx + 2 + k * 2, yard.position.y + 6), Vector2(rx + 2 + k * 2, yard.position.y + 10 + yard.size.y * 0.5), _a(Color("#b9b3a0"), alpha), 1.2)
	# 木人桩
	for k in 2:
		var p := Vector2(yard.position.x + yard.size.x * (0.3 + k * 0.4), yard.end.y - 14)
		ci.draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 16)), _a(Color("#7a5a38"), alpha), true)
		ci.draw_line(p + Vector2(-8, -5), p + Vector2(8, -5), _a(Color("#7a5a38"), alpha), 3.0)

	# 北面厅堂
	var facade_h := clampf(hall.size.y * 0.26, 16.0, 30.0)
	_facade(ci, Rect2(hall.position + Vector2(4, hall.size.y - facade_h), Vector2(hall.size.x - 8, facade_h)), alpha)
	var roof := Rect2(hall.position, Vector2(hall.size.x, hall.size.y - facade_h + 4))
	_roof(ci, roof, accent, alpha)
	return roof.position + Vector2(roof.size.x / 2.0, roof.size.y - 12)
