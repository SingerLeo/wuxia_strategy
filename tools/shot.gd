extends SceneTree
## 界面截图（需要窗口，不能用 --headless）。用于开发时目测界面。
## 用法：
##   godot_console --path . --resolution 1600x900 -s tools/shot.gd -- --page=1 --out=shot.png [--steps=2]
## --page 页面序号；--steps 先点几次"结束本旬"；--out 输出文件路径。


func _initialize() -> void:
	var page := 0
	var steps := 0
	var out := "shot.png"
	var destroy := false
	var menu := false
	var saves := false
	var demo_map := false  # 给山门地图摆几座建筑，用来截建筑页
	var ghost := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			page = int(a.get_slice("=", 1))
		elif a.begins_with("--steps="):
			steps = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a == "--destroy":
			destroy = true
		elif a == "--menu":
			menu = true
		elif a == "--saves":
			saves = true
		elif a == "--demo-map":
			demo_map = true
		elif a.begins_with("--demo-ghost="):
			ghost = a.get_slice("=", 1)  # 形如 --demo-ghost=6,0 ：移动药庐时鼠标悬停的格子

	var game = root.get_node("Game")
	game.new_game(7)
	# 不要写成 `var main: Main`：-s 脚本编译时 Game 自动加载尚未注册，静态引用会编译失败
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if page == 1 and steps > 0:
		# 给前几名弟子指派日程，让截图里有内容
		for i in 5:
			game.assign(i, i % game.schedules.size())
	for i in steps:
		game.end_xun()
	if demo_map:
		game.sect.silver = 10000
		game.build_at(&"dojo", Vector2i(3, 3), 0)
		game.build_at(&"clinic", Vector2i(6, 3), 0)
		game.build_at(&"kitchen", Vector2i(8, 3), 0)
		game.build_at(&"library", Vector2i(10, 4), 0)
		game.upgrade_building(&"dojo")
	main.show_page(page)
	if demo_map:
		# 选中练武场，并给"药庐"预览一个摆放位置，看右侧详情与地图预览
		var bp = main.get_page(page)
		bp.select(&"dojo")
		if ghost != "":
			var xy := ghost.split(",")
			bp.begin_place(&"clinic")
			# 参数是药庐想落的左上角格子；换算成鼠标所在格再悬停
			bp.hover_cell(bp.cursor_for(Vector2i(int(xy[0]), int(xy[1]))))
	if destroy:
		game.debug_disband_all()
	if menu:
		main._unhandled_key_input(_esc())
	if saves:
		main._saveload.refresh()
		main._saveload.visible = true
	for i in 4:
		await process_frame
	var err := root.get_texture().get_image().save_png(out)
	print("saved %s (err=%d)" % [out, err])
	quit()


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	return ev
