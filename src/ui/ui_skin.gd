class_name UiSkin
extends RefCounted
## 界面皮肤：用代码生成"带渐变、颗粒、金色描边、角饰"的面板与按钮贴图，做成九宫格 StyleBoxTexture。
## 贴图很小、只生成一次并缓存。以后有了美术资源，把 ArtLibrary 里对应的图放进 assets/art/ui/ 即可替换。

const GOLD := Color("#c9a45c")
const GOLD_DIM := Color("#7a6538")

static var _cache: Dictionary = {}


## 面板。ornate 为 true 时带金色内描线和四角的折角、菱形角饰，用于对话框、菜单这类重要面板。
static func panel(ornate: bool) -> StyleBoxTexture:
	var key := "panel_ornate" if ornate else "panel_plain"
	if not _cache.has(key):
		var tex: Texture2D = ArtLibrary.ui_texture(key)
		if tex == null:
			if ornate:
				tex = _frame(88, 88, 6.0, Color("#332f27"), Color("#1d1b17"), GOLD_DIM, 2.0, Color(GOLD, 0.7), 6.0, 0.02, true, 11)
			else:
				tex = _frame(64, 64, 5.0, Color("#2e2b25"), Color("#1f1d19"), Color("#4b4435"), 1.5, Color(GOLD, 0.22), 4.0, 0.02, false, 12)
		_cache[key] = tex
	var margin := 24 if ornate else 12
	return _stylebox(_cache[key], margin, 10 if ornate else 8)


## 按钮。variant：normal / nav / primary；state：normal / hover / pressed / disabled
static func button(variant: String, state: String) -> StyleBoxTexture:
	var key := "button_%s_%s" % [variant, state]
	if not _cache.has(key):
		var tex: Texture2D = ArtLibrary.ui_texture(key)
		if tex == null:
			tex = _make_button(variant, state)
		_cache[key] = tex
	var pad_h := 14 if variant == "primary" else 12
	var s := _stylebox(_cache[key], 12, 8)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	return s


static func _make_button(variant: String, state: String) -> ImageTexture:
	var top: Color
	var bottom: Color
	var border: Color
	var bw := 1.5
	match variant:
		"primary":
			bw = 2.0
			match state:
				"hover": top = Color("#a08a52"); bottom = Color("#725d31"); border = Color("#e3c577")
				"pressed": top = Color("#5f4c28"); bottom = Color("#8a7240"); border = GOLD
				"disabled": top = Color("#3a3326"); bottom = Color("#2c271d"); border = Color("#4a4334")
				_: top = Color("#8a7240"); bottom = Color("#5f4c28"); border = GOLD
		"nav":
			match state:
				"hover": top = Color("#3a362e"); bottom = Color("#2c2924"); border = Color(GOLD_DIM, 0.8)
				"pressed": top = Color("#6b5630"); bottom = Color("#4d3f22"); border = GOLD
				"disabled": top = Color("#201e1a", 0.5); bottom = Color("#1b1a16", 0.5); border = Color("#2e2b25", 0.5)
				_: top = Color("#2a2722", 0.55); bottom = Color("#221f1b", 0.55); border = Color("#3a362f", 0.6)
		_:
			match state:
				"hover": top = Color("#554c3a"); bottom = Color("#3a342a"); border = GOLD
				"pressed": top = Color("#4a3d22"); bottom = Color("#6b5630"); border = GOLD
				"disabled": top = Color("#2a2823"); bottom = Color("#23211c"); border = Color("#3a362f")
				_: top = Color("#443f34"); bottom = Color("#2d2a23"); border = Color("#6a5d3f")
	return _frame(48, 36, 5.0, top, bottom, border, bw, Color(1, 1, 1, 0.0), 0.0, 0.015, false, 21)


static func _stylebox(tex: Texture2D, margin: int, pad: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## 生成一张圆角矩形的皮肤图：上下渐变、颗粒、描边、可选内描线与角饰。边缘做了 1 像素抗锯齿。
static func _frame(w: int, h: int, radius: float, top: Color, bottom: Color, border: Color, border_w: float,
		inner: Color, inner_inset: float, grain: float, corners: bool, seed_value: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half := Vector2(w, h) / 2.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var q := p.abs() - (half - Vector2(radius, radius))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var cover := clampf(0.5 - d, 0.0, 1.0)
			if cover <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var t := float(y) / maxf(h - 1, 1)
			var col := top.lerp(bottom, t)
			var alpha := col.a
			var g := (float(MapArt.hash2(x, y, seed_value) % 1000) / 1000.0 - 0.5) * 2.0 * grain
			col = Color(col.r + g, col.g + g, col.b + g, 1.0)

			# 描边：越靠近边缘越接近边框色
			var edge := clampf(d + border_w + 0.5, 0.0, 1.0)
			col = col.lerp(Color(border.r, border.g, border.b, 1.0), edge * border.a)
			alpha = lerpf(alpha, maxf(border.a, alpha), edge)

			# 内描线
			if inner.a > 0.0:
				var ring := clampf(1.0 - absf(d + inner_inset) / 0.9, 0.0, 1.0)
				col = col.lerp(Color(inner.r, inner.g, inner.b, 1.0), ring * inner.a)
				alpha = maxf(alpha, ring * inner.a)

			# 四角的金色折角与菱形
			if corners:
				var lx := minf(x, w - 1 - x)
				var ly := minf(y, h - 1 - y)
				var ins := inner_inset
				var on_h := absf(ly - ins) < 1.0 and lx >= ins and lx <= ins + 14.0
				var on_v := absf(lx - ins) < 1.0 and ly >= ins and ly <= ins + 14.0
				var diamond := absf(lx - (ins + 6.0)) + absf(ly - (ins + 6.0)) < 3.4
				if on_h or on_v or diamond:
					col = col.lerp(GOLD, 0.95)
					alpha = 1.0

			img.set_pixel(x, y, Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1), clampf(col.b, 0, 1), cover * clampf(alpha, 0, 1)))
	return ImageTexture.create_from_image(img)
