class_name TerrainLayer
extends ColorRect
## 山门地面与河流：一块铺满地图的矩形，用着色器（terrain.gdshader）画出草地、河岸和流动的河水。
## 河流形状来自 Catalog.MAP 里的 '~'：先生成一张水的遮罩图并模糊，着色器据此画出圆润的河岸。
## 它是 SectMapView 的子节点并设置了 show_behind_parent，所以画在地图其余内容的下面。

const MASK_SCALE := 8      ## 遮罩图每格占多少像素
const BLUR_RADIUS := 5     ## 模糊半径（遮罩像素）
const BLUR_PASSES := 2

var _material: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	color = Color.WHITE
	position = Vector2(SectMapView.PAD, SectMapView.PAD)
	size = Vector2(SectMap.width() * SectMapView.CELL, SectMap.height() * SectMapView.CELL)

	_material = ShaderMaterial.new()
	_material.shader = load("res://src/ui/shaders/terrain.gdshader")
	_material.set_shader_parameter("mask", build_mask_texture())
	_material.set_shader_parameter("map_cells", Vector2(SectMap.width(), SectMap.height()))
	material = _material


func set_time(t: float) -> void:
	_material.set_shader_parameter("time", t)


## 水的遮罩：河流格子为 1，其余为 0，然后做几次盒式模糊（边缘按"向外延伸"处理，所以河流流出地图边缘时不会收口）
static func build_mask_texture() -> ImageTexture:
	var data := build_mask()
	var w := SectMap.width() * MASK_SCALE
	var h := SectMap.height() * MASK_SCALE
	var img := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(data[y * w + x], 0, 0, 1))
	return ImageTexture.create_from_image(img)


## 返回 w*h 的浮点数组（行优先），范围 0~1。单独拿出来是为了能被测试。
static func build_mask() -> PackedFloat32Array:
	var w := SectMap.width() * MASK_SCALE
	var h := SectMap.height() * MASK_SCALE
	var data := PackedFloat32Array()
	data.resize(w * h)
	for y in h:
		for x in w:
			var cell := Vector2i(x / MASK_SCALE, y / MASK_SCALE)
			data[y * w + x] = 1.0 if SectMap.terrain(cell) == "~" else 0.0
	for _i in BLUR_PASSES:
		data = _box_blur(data, w, h, BLUR_RADIUS, true)
		data = _box_blur(data, w, h, BLUR_RADIUS, false)
	return data


static func _box_blur(src: PackedFloat32Array, w: int, h: int, radius: int, horizontal: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var span := radius * 2 + 1
	for y in h:
		for x in w:
			var total := 0.0
			for k in range(-radius, radius + 1):
				var sx := x
				var sy := y
				if horizontal:
					sx = clampi(x + k, 0, w - 1)
				else:
					sy = clampi(y + k, 0, h - 1)
				total += src[sy * w + sx]
			out[y * w + x] = total / span
	return out
