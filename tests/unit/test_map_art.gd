extends GutTest
## 地图美术的可测试部分：河流遮罩、瓦片纹理、稳定的伪随机。画面本身靠截图人工看。


func _px(mask: PackedFloat32Array, cell: Vector2i, dx: int = 4, dy: int = 4) -> float:
	var w := SectMap.width() * TerrainLayer.MASK_SCALE
	return mask[(cell.y * TerrainLayer.MASK_SCALE + dy) * w + cell.x * TerrainLayer.MASK_SCALE + dx]


func test_mask_has_one_value_per_pixel() -> void:
	var mask := TerrainLayer.build_mask()
	assert_eq(mask.size(), SectMap.width() * SectMap.height() * TerrainLayer.MASK_SCALE * TerrainLayer.MASK_SCALE)


func test_mask_is_high_in_the_river_and_low_far_from_it() -> void:
	var mask := TerrainLayer.build_mask()
	assert_gt(_px(mask, Vector2i(8, 1)), 0.7, "河中心")
	assert_lt(_px(mask, Vector2i(0, 7)), 0.02, "远离河流的角落")
	assert_lt(_px(mask, Vector2i(3, 3)), 0.02, "练武场所在的空地")


func test_mask_is_soft_across_the_bank() -> void:
	var mask := TerrainLayer.build_mask()
	# 河的左岸在第 8 列的左边缘：越往左越低，且是平滑过渡（不是 0/1 的硬边）
	var inside := _px(mask, Vector2i(8, 1), 1)
	var edge := _px(mask, Vector2i(7, 1), 7)
	var outside := _px(mask, Vector2i(7, 1), 0)
	assert_gt(inside, edge, "岸内比岸边高")
	assert_gt(edge, outside, "岸边比岸外高")
	assert_between(edge, 0.2, 0.8, "紧贴河边的一格应当落在 0~1 之间")


func test_river_keeps_flowing_off_the_map_edge() -> void:
	var mask := TerrainLayer.build_mask()
	# 河从上边缘 (8,0) 流入：最上面一行像素不应因为"边缘没有水"而衰减
	assert_gt(_px(mask, Vector2i(8, 0), 4, 0), 0.7, "上边缘的河面")
	# 河向右边缘 (11,2) 流出；这一段只有一格宽，模糊后中心比河中央低，但仍要高于成水的阈值 0.5
	var w := SectMap.width() * TerrainLayer.MASK_SCALE
	var right_edge := mask[(2 * TerrainLayer.MASK_SCALE + 4) * w + (w - 1)]
	assert_gt(right_edge, 0.5, "右边缘仍是水，没有因为到了地图边缘而收口")


func test_roof_texture_is_a_seamless_grayscale_tile() -> void:
	var tex := MapArt.roof_texture()
	assert_not_null(tex)
	assert_eq(tex.get_width(), MapArt.TILE_COLS * MapArt.TILE_W)
	assert_eq(tex.get_height(), MapArt.TILE_ROWS * MapArt.TILE_H)
	var img := tex.get_image()
	var lo := 1.0
	var hi := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			assert_almost_eq(c.r, c.g, 0.001, "灰度图，便于用颜色染色")
			lo = minf(lo, c.r)
			hi = maxf(hi, c.r)
	assert_gt(hi - lo, 0.3, "要有足够的明暗对比才看得出瓦")
	assert_lt(lo, 0.8)
	assert_same(MapArt.roof_texture(), tex, "纹理只生成一次并缓存")


func test_hash_is_stable_and_non_negative() -> void:
	assert_eq(MapArt.hash2(3, 5, 7), MapArt.hash2(3, 5, 7))
	assert_ne(MapArt.hash2(3, 5, 7), MapArt.hash2(5, 3, 7))
	for i in 50:
		assert_gte(MapArt.hash2(i, -i, i), 0)
