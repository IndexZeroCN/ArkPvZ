extends Node
## 旧启动主要开销测量（用于对比优化前后）：AllCards 场景、旧主菜单、注册表场景
## 运行方式：headless 游戏模式运行 res://tools/time_old_boot.tscn

func _ready() -> void:
	var t_all_cards: Array = []
	var cards: PackedScene = load("res://scenes/autoload/all_cards.tscn")
	var t1 := Time.get_ticks_msec()
	var cards_inst: Node = cards.instantiate()
	add_child(cards_inst)
	var t2 := Time.get_ticks_msec()
	print("[time] AllCards 加载=", t1, " 实例化(含卡片 _ready)=", t2 - t1, " ms")
	remove_child(cards_inst)
	cards_inst.free()

	var t3 := Time.get_ticks_msec()
	var menu: PackedScene = load("res://scenes/main/backup/01StartMenu_Backup.tscn")
	var t4 := Time.get_ticks_msec()
	print("[time] 旧主菜单 01StartMenu 加载=", t4 - t3, " ms")

	var t5 := Time.get_ticks_msec()
	var pea: PackedScene = load("res://scenes/character/plant/plant_001_pea_shooter_single.tscn")
	var t6 := Time.get_ticks_msec()
	var operator: PackedScene = load("res://scenes/character/operator/operator_001_kroos.tscn")
	var t7 := Time.get_ticks_msec()
	print("[time] 单个植物场景=", t6 - t5, " ms，单个干员场景(Spine)=", t7 - t6, " ms")

	get_tree().quit(0)
