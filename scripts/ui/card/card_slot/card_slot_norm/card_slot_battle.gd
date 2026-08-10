extends PanelContainer
## 出战卡槽
class_name CardSlotBattle

@onready var curr_sun_value: Label = $SunLabelControl/CurrSunValue
@onready var deploy_point_value: Label = %DeployPointValue
@onready var deploy_point_value_progress_bar: ProgressBar = %DeployPointValueProgressBar
@onready var card_placeholder_ori: TextureRect = $CardUiList/CardPlaceholder_ori
@onready var card_ui_list: HBoxContainer = $CardUiList
@onready var marker_2d_sun_target: Marker2D = %Marker2DSunTarget

## 出战卡槽占位节点
var cards_placeholder:Array = []
## 出战卡片
var curr_cards : Array[Card]
## 阳光值
var sun_value:
	set(value):
		sun_value = value
		curr_sun_value.text = str(value)

		for card in curr_cards:
			## 干员卡片由部署点数管理器更新, 不在此判断
			if not card.is_operator_card:
				card.judge_sun_enough(value)

func _ready() -> void:
	Global.config_service.signal_change_disappear_spare_card_placeholder.connect(judge_disappear_add_card_bar)
	EventBus.subscribe("test_change_sun_value", func(value): sun_value = value)
	EventBus.subscribe("add_sun_value", func(value): sun_value+=value)
	EventBus.subscribe("update_card_purple_sun_cost", update_card_purple_sun_cost)
	## 部署点数更新(干员卡片成本判断与显示)
	EventBus.subscribe("update_deploy_point", update_deploy_point_value)
	## 干员部署后刷新干员卡片(唯一性置灰); 撤退/死亡后开始再部署冷却
	EventBus.subscribe("operator_deployed", _refresh_operator_cards)
	EventBus.subscribe("operator_retreat", _on_operator_retreat_or_death)
	EventBus.subscribe("operator_death", _on_operator_retreat_or_death)

func _process(_delta: float) -> void:
	## 部署点数回复进度条跟进(满 100 时 OperatorManager 会 +1 费, 条随之清零重新涨)
	## 仅在游戏阶段且有干员管理器时更新; 无回复/DP 已满 → 满条
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
		deploy_point_value_progress_bar.value = Global.main_game.operator_manager.get_deploy_point_progress() * 100.0

## 干员撤退/死亡: 刷新卡片状态并开始再部署冷却(部署时不冷却)
func _on_operator_retreat_or_death(operator):
	_refresh_operator_cards(operator)
	if operator is Operator000Base:
		for card in curr_cards:
			if card.is_operator_card and card.card_plant_type == operator.plant_type:
				card.card_cool()
				return

## 干员部署/死亡时刷新干员卡片可点击状态
func _refresh_operator_cards(_operator = null):
	for card in curr_cards:
		if card.is_operator_card:
			card.judge_card_ready()

## 更新部署点数显示与干员卡片可点击状态
func update_deploy_point_value(value:int):
	deploy_point_value.text = str(value)
	for card in curr_cards:
		if card.is_operator_card:
			card.judge_sun_enough(value)


## 初始化出战卡槽，管理器调用
func init_card_slot_battle(max_choosed_card_num:int, sun:int):
	self.sun_value = sun
	for i in range(max_choosed_card_num):
		var cloned_card_placeholder = card_placeholder_ori.duplicate()
		card_ui_list.add_child(cloned_card_placeholder)

	card_placeholder_ori.free()		## 立即删除掉该节点，下面获取卡槽占位节点
	cards_placeholder = card_ui_list.get_children()
	## 更新阳光收集位置
	EventBus.push_event("update_marker_2d_sun_target", marker_2d_sun_target)

	return cards_placeholder

## 主游戏刷新卡片
func main_game_refresh_card():
	update_card_purple_sun_cost()
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		## 干员卡片由部署点数判断(下方统一刷新), 植物卡片用阳光判断
		if not card.is_operator_card:
			card.judge_sun_enough(sun_value)
		card.set_shortcut((i+1)%10)
		if not card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.connect(card_use_end.bind(card))
	## 刷新干员卡片(部署点数)
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
		update_deploy_point_value(Global.main_game.operator_manager.deploy_point)
	judge_disappear_add_card_bar()

## 开始下一轮出战卡槽更新数据
func start_next_game_card_slot_battle_update():
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		## 卡牌冷却结束,可以点击
		card.set_card_cool_end()
		card.card_ready()
		card.set_shortcut_disappear()
		if card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.disconnect(card_use_end.bind(card))

## 卡片种植后信号调用函数
func card_use_end(card:Card):
	## 干员卡片消耗部署点数(部署不开始冷却, 撤退/死亡后才开始计再部署CD); 植物卡片消耗阳光并冷却
	if card.is_operator_card:
		if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
			Global.main_game.operator_manager.use_deploy_point(card.sun_cost)
	else:
		sun_value = sun_value - card.sun_cost
		card.card_cool()

#region 控制台相关
## 是否显示多余卡槽
func judge_disappear_add_card_bar():
	## 在游戏进行阶段
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if Global.config_service.disappear_spare_card_Placeholder:
			if curr_cards.size() < cards_placeholder.size():
				for i in range(curr_cards.size(), cards_placeholder.size()):
					cards_placeholder[i].visible = false
		else:
			for i in range(cards_placeholder.size()):
				cards_placeholder[i].visible = true
	else:
		for i in range(cards_placeholder.size()):
			cards_placeholder[i].visible = true

#endregion

## 等待一帧(阳光减少)后 更新当前卡片的紫卡价格,每次植物种植或死亡时调用
func update_card_purple_sun_cost():
	await get_tree().process_frame
	for card:Card in curr_cards:
		if card.is_purple_card and Global.main_game.plant_cell_manager.curr_plant_num.has(card.card_plant_type):
			card.sun_cost = Global.character_registry.get_plant_info(card.card_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost) + 50 * Global.main_game.plant_cell_manager.curr_plant_num[card.card_plant_type]
			card.judge_sun_enough(sun_value)
