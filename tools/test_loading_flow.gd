extends Node
## 加载界面完整流程测试：启动加载界面 → 线程加载完成 → 预热 AllCards → 自动切换主菜单
## 轮询器挂在 root 上，场景切换后仍存活，可确认切换结果。
## 运行方式：headless 游戏模式运行 res://tools/test_loading_flow.tscn

const ALL_CARDS_SCENE_PATH := "res://scenes/autoload/all_cards.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main/01MainMenu.tscn"

func _ready() -> void:
	var loading: PackedScene = load("res://scenes/main/00LoadingScreen.tscn")
	if loading == null:
		printerr("FAIL: 00LoadingScreen 无法加载")
		get_tree().quit(1)
		return
	add_child(loading.instantiate())
	print("test: 已加载加载界面，等待自动进入主菜单…")

	var start := Time.get_ticks_msec()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		var cs := get_tree().current_scene
		if cs != null and cs.name == "MainMenu":
			print("OK: 已自动进入主菜单（经加载界面）")
			print("OK: AllCards 已预热 plant_cards=", AllCards.all_plant_card_prefabs.size())
			get_tree().quit(0)
			return
		if elapsed > 60.0:
			printerr("FAIL: 60 秒内未进入主菜单，current_scene=", cs)
			get_tree().quit(1)
			return
		var prog1: Array = []
		var prog2: Array = []
		var s1 := ResourceLoader.load_threaded_get_status(ALL_CARDS_SCENE_PATH, prog1)
		var s2 := ResourceLoader.load_threaded_get_status(MAIN_MENU_SCENE_PATH, prog2)
		print("probe t=", int(elapsed), "s s1=", s1, " prog1=", prog1, " | s2=", s2, " prog2=", prog2)
	)
	get_tree().root.add_child.call_deferred(timer)
