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

	var game = root.get_node("Game")
	game.new_game(7)
	# 不要写成 `var main: Main`：-s 脚本编译时 Game 自动加载尚未注册，静态引用会编译失败
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if page == 1 and steps > 0:
		# 给前几名弟子安排修炼，让截图里有内容
		for i in 5:
			game.set_plan(i, Balance.MARTIAL[i % Balance.MARTIAL.size()])
	for i in steps:
		game.end_xun()
	main.show_page(page)
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
