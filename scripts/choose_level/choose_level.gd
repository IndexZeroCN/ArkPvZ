extends Control
class_name ChooseLevel

## 用于生成关卡 ID 的计数
var next_level_number: int = 1

@onready var all_page: Control = $AllPage
@onready var label_page: Label = get_node_or_null("LabelPage")

## 游戏模式,用于管理关卡存档
@export var game_mode:MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 开放关卡数量，冒险默认为1，其余模式为3，若打开控制台开放所有关卡为-1
var open_level_num:int = -1
var all_pages_array : Array[GridContainer]
@export var curr_page := 0

## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_card.mp3")

func _ready() -> void:
	## 如果没有开放所有关卡
	if not Global.config_service.open_all_level:
		if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
			open_level_num = 1
		## 自定义关卡全开放
		elif game_mode == MainSceneRegistry.MainScenes.ChooseLevelCustom:
			open_level_num = -1
		else:
			open_level_num = 3
	else:
		open_level_num = -1

	for page_i in all_page.get_child_count():
		var page = all_page.get_child(page_i)
		all_pages_array.append(page)
		page.visible = false
		for node in page.get_children():
			## 如果是选关按钮
			if node is ChooseLevelButton:
				var level_id:String = generate_level_id()
				if node.curr_level_data_game_para == null:
					continue
				node.signal_choose_level_button.connect(_on_choose_level_button)
				## 初始化游戏数据的选关数据
				node.curr_level_data_game_para.set_choose_level(game_mode, page_i, level_id)
				var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(node.curr_level_data_game_para.save_game_name, {})
				node.update_curr_level_button_state(curr_level_state_data)
				update_lock_level(node, curr_level_state_data)

	print("当前模式关卡数量:", next_level_number - 1)

	_apply_wisdel_cover_options()
	_ready_update_page()

## 应用封面干员的开发者选项(选关界面按钮上的干员立绘/Spine 预览):
## - wisdel_cover_scale: 角色缩放(开发者选项面板调整)
## - 隐藏干员的血条/技能条 UI(展示用, 避免空条飘在角色上方)
func _apply_wisdel_cover_options() -> void:
	var cover_scale: float = Global.config_service.get_developer_option("wisdel_cover_scale", 0.8)
	for page in all_page.get_children():
		for node in page.get_children():
			if not node is ChooseLevelButton:
				continue
			var spine := node.get_node_or_null("WisadelSpine")
			if spine == null:
				continue
			if cover_scale > 0.0:
				spine.scale = Vector2(cover_scale, cover_scale)
			var hp_control := spine.get_node_or_null("HpComponent/HpControl")
			if hp_control:
				hp_control.visible = false
			var skill_control := spine.get_node_or_null("SkillComponent/SkillControl")
			if skill_control:
				skill_control.visible = false

## 更新关卡是否锁住 无尽模式默认开放，不占用开放名额
func update_lock_level(choose_level_button:ChooseLevelButton, curr_level_state_data:Dictionary):
	## 如果开放名额为-1，即所有关卡都开发
	if open_level_num == -1:
		return
	## 无尽模式
	if choose_level_button.curr_level_data_game_para.game_round == -1:
		return
	## 如果当前关卡通关
	if curr_level_state_data.get("IsSuccess", false):
		return
	## 还有开发关卡名额
	if open_level_num > 0:
		open_level_num -= 1
		return
	else:
		choose_level_button.lock_choose_level_button()

func _ready_update_page():
	## 如果从游戏中退出
	if Global.game_para != null and Global.game_para.game_mode == game_mode:
		curr_page = Global.game_para.level_page

	if curr_page > all_pages_array.size():
		curr_page = 0
	if not all_pages_array.is_empty():
		all_pages_array[curr_page].visible = true
		if is_instance_valid(label_page):
			_update_page(curr_page)

	SoundManager.play_bgm(bgm_choose_card)

## 获取关卡id
func generate_level_id() -> String:
	# 用格式化字符串，让数字变成 4 位，前面补 0
	# GDScript 支持类似 C 风格字符串格式化
	var id_str = "%04d" % next_level_number  # 例如 0 -> "0000", 12 -> "0012"
	next_level_number += 1
	return id_str

func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	## 危机合约关卡: 先弹词条选择面板, 应用词条后再进入
	if choose_level_button.curr_level_data_game_para.is_contract_level:
		_show_contract_term_select(choose_level_button)
		return
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)

## 危机合约: 弹出词条选择面板(同组互斥), 确认后 clone 关卡参数应用词条再开战
func _show_contract_term_select(choose_level_button:ChooseLevelButton) -> void:
	var panel: ContractTermSelect = load("res://scenes/choose_level/contract_term_select.tscn").instantiate()
	add_child(panel)
	panel.z_index = 100
	panel.signal_confirm.connect(func(selected_terms: Array) -> void:
		## clone 关卡参数再应用词条, 避免污染 .tres 资源(词条会持久化在下次进入)
		var ori_para: ResourceLevelData = choose_level_button.curr_level_data_game_para
		var para: ResourceLevelData = ori_para.duplicate()
		## duplicate 不复制非 @export 字段(game_mode/level_page/level_id/save_game_name 均非 @export), 需从原参数重新 set_choose_level
		para.set_choose_level(ori_para.game_mode, ori_para.level_page, ori_para.level_id)
		ContractTerms.apply_terms(para, selected_terms)
		Global.game_para = para
		choose_level_start_game(para.game_sences)
	)
	panel.signal_cancel.connect(panel.queue_free)

## 进入游戏关卡
func choose_level_start_game(game_scense:MainSceneRegistry.MainScenes):
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[game_scense])

## 返回开始菜单
func back_start_menu():
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])


func _on_last_pressed() -> void:
	_update_page(curr_page - 1)

func _on_next_pressed() -> void:
	_update_page(curr_page + 1)


func _update_page(new_page:int):
	new_page = posmod(new_page, all_pages_array.size())
	all_pages_array[curr_page].visible = false
	curr_page = new_page
	all_pages_array[curr_page].visible = true
	label_page.text = "当前页数:" + str(curr_page + 1) + "/" + str(all_pages_array.size())
