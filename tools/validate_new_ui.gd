extends Node
## 新 UI 流程验证：开始界面 → 加载界面 → AllCards 懒加载 → 主菜单
## 运行方式：headless 游戏模式运行 res://tools/validate_new_ui.tscn

func _ready() -> void:
	print("=== 开始验证新 UI ===")

	# 1. 开始界面
	var start_scene: PackedScene = load("res://scenes/main/00StartScreen.tscn")
	if start_scene == null:
		printerr("FAIL: 00StartScreen 无法加载")
		get_tree().quit(1)
		return
	var start_root: Node = start_scene.instantiate()
	add_child(start_root)
	await get_tree().process_frame
	await get_tree().process_frame
	remove_child(start_root)
	start_root.free()
	print("OK: 00StartScreen 实例化成功")

	# 2. 加载界面（会发起线程加载，不等待完成以免触发场景切换）
	var loading_scene: PackedScene = load("res://scenes/main/00LoadingScreen.tscn")
	if loading_scene == null:
		printerr("FAIL: 00LoadingScreen 无法加载")
		get_tree().quit(1)
		return
	var loading_root: Node = loading_scene.instantiate()
	add_child(loading_root)
	await get_tree().process_frame
	await get_tree().process_frame
	remove_child(loading_root)
	loading_root.free()
	print("OK: 00LoadingScreen 实例化成功")

	# 3. AllCards 懒加载（首次访问触发实例化）
	var plant_num: int = AllCards.all_plant_card_prefabs.size()
	var zombie_num: int = AllCards.all_zombie_card_prefabs.size()
	print("OK: AllCards 懒加载 plant_cards=", plant_num, " zombie_cards=", zombie_num)
	if plant_num <= 0:
		printerr("FAIL: AllCards 懒加载失败")
		get_tree().quit(1)
		return

	# 4. 主菜单
	var menu_scene: PackedScene = load("res://scenes/main/01MainMenu.tscn")
	if menu_scene == null:
		printerr("FAIL: 01MainMenu 无法加载")
		get_tree().quit(1)
		return
	var menu_root: Node = menu_scene.instantiate()
	add_child(menu_root)
	await get_tree().process_frame
	await get_tree().process_frame
	remove_child(menu_root)
	menu_root.free()
	print("OK: 01MainMenu 实例化成功")

	print("=== 验证完成 ===")
	get_tree().quit()
