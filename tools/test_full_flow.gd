extends Node
## 完整启动流程集成测试：开始界面 → 模拟点击开始 → 加载界面 → 自动进入主菜单
## 轮询器挂在 root 上，场景切换后仍存活（注意：lambda 内通过捕获的 tree 访问，避免使用已释放的 self）。
## 运行方式：headless 游戏模式运行 res://tools/test_full_flow.tscn

func _ready() -> void:
	var tree := get_tree()
	var start_scene: PackedScene = load("res://scenes/main/00StartScreen.tscn")
	if start_scene == null:
		printerr("FAIL: 00StartScreen 无法加载")
		tree.quit(1)
		return
	var root_node: Node = start_scene.instantiate()
	add_child(root_node)
	await tree.process_frame
	await tree.process_frame

	if Global.user_manager.curr_user_name.is_empty():
		printerr("FAIL: 无当前用户，无法自动进入加载界面")
		tree.quit(1)
		return

	print("test: 模拟点击开始游戏按钮")
	root_node.call("_on_start_button_pressed")

	var start_t := Time.get_ticks_msec()
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		var cs := tree.current_scene
		if cs != null and cs.name == "MainMenu":
			print("OK: 完整流程 开始界面→加载界面→主菜单 完成，耗时 ", Time.get_ticks_msec() - start_t, " ms")
			tree.quit(0)
			return
		if (Time.get_ticks_msec() - start_t) / 1000.0 > 30.0:
			printerr("FAIL: 完整流程超时，current_scene=", cs)
			tree.quit(1)
	)
	tree.root.add_child.call_deferred(timer)
