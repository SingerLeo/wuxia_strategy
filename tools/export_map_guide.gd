extends SceneTree
## 导出山门地图的"参考图"，交给画师或 AI 绘图工具，让他们画的底图和游戏里的格子对得上。
## 用法（可以无界面）：
##   godot_console --headless -s tools/export_map_guide.gd -- --out=docs/art/map_guide.png --cell=128
## 参考图里：绿色 = 可建空地，灰褐 = 山峰（不可建），蓝 = 河流（不可建），白线 = 格子边界，角上有格子坐标。

const GROUND := Color("#4f6b3a")
const MOUNTAIN := Color("#7b7466")
const RIVER := Color("#3c7fa3")


func _initialize() -> void:
	var out := "docs/art/map_guide.png"
	var cell := 128
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--cell="):
			cell = maxi(16, int(a.get_slice("=", 1)))

	var w := SectMap.width()
	var h := SectMap.height()
	var img := Image.create(w * cell, h * cell, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var col := GROUND
			match SectMap.terrain(Vector2i(x, y)):
				"#": col = MOUNTAIN
				"~": col = RIVER
			img.fill_rect(Rect2i(x * cell, y * cell, cell, cell), col)
			# 格子边界：每格右边和下边各画一条白线
			img.fill_rect(Rect2i(x * cell + cell - 1, y * cell, 1, cell), Color(1, 1, 1, 0.8))
			img.fill_rect(Rect2i(x * cell, y * cell + cell - 1, cell, 1), Color(1, 1, 1, 0.8))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(out.get_base_dir()))
	var err := img.save_png(ProjectSettings.globalize_path("res://").path_join(out))
	print("saved %s (%dx%d, err=%d)" % [out, img.get_width(), img.get_height(), err])
	quit()
