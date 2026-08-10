extends MainGameSubManager
## 管理手持角色（植物、僵尸）、道具（铲子）
## 类似状态机
class_name HandManager

@onready var hm_character: HM_Character = $HM_Character
@onready var hm_item: HM_Item = $HM_Item
@onready var hm_null: HM_NUll = $HM_Null

## 手持管理器状态
enum E_HandManagerStatus{
	Null, 		## 手上什么都没拿
	Character,	## 手持角色 植物、僵尸
	Item,		## 手持道具 铲子 （TODO: 锤子手套）
}

## 当前手持管理器状态
var curr_hm_status := E_HandManagerStatus.Null:
	set(value):
		hm_status_change(curr_hm_status, value)
		curr_hm_status = value
## 当前植物格子
var curr_plant_cell:PlantCell = null

func _ready() -> void:
	EventBus.subscribe("main_game_click_card", _click_card)
	EventBus.subscribe("main_game_click_shovel", _click_shovel)

func _process(_delta: float) -> void:
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.null_process()
		E_HandManagerStatus.Character:
			hm_character.character_process()
		E_HandManagerStatus.Item:
			hm_item.item_process()

## 手持管理器状态改变
func hm_status_change(ori_status:E_HandManagerStatus, _new_status:E_HandManagerStatus):
	match ori_status:
		E_HandManagerStatus.Null:
			hm_null.exit_status()
		E_HandManagerStatus.Character:
			hm_character.exit_status()
		E_HandManagerStatus.Item:
			hm_item.exit_status()

func init_manager() -> void:
	hm_character.init_hm_character()

## 点击卡片
func _click_card(card:Card) -> void:
	SoundManager.play_other_SFX("seedlift")
	curr_hm_status = E_HandManagerStatus.Character
	hm_character.click_card(card)
	## 如果当前在植物格子中
	if curr_plant_cell:
		_on_cell_mouse_enter(curr_plant_cell)

## 点击ui铲子
func _click_shovel() -> void:
	SoundManager.play_other_SFX("shovel")
	curr_hm_status = E_HandManagerStatus.Item
	hm_item.click_shovel()
	## 如果当前在植物格子中
	if curr_plant_cell:
		_on_cell_mouse_enter(curr_plant_cell)

## 鼠标点击cell
func _on_click_cell(plant_cell:PlantCell):
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.click_cell(plant_cell)
		E_HandManagerStatus.Character:
			## 干员两段部署: 第一段(放置)不结束手持, 第二段(确认方向)结束
			var hand_done: bool = hm_character.click_cell(plant_cell)
			if hand_done:
				curr_hm_status = E_HandManagerStatus.Null
		E_HandManagerStatus.Item:
			hm_item.click_cell(plant_cell)
			curr_hm_status = E_HandManagerStatus.Null

## 鼠标进入cell
func _on_cell_mouse_enter(plant_cell:PlantCell):
	curr_plant_cell = plant_cell
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.mouse_enter(plant_cell)
		E_HandManagerStatus.Character:
			hm_character.mouse_enter(plant_cell)
		E_HandManagerStatus.Item:
			hm_item.mouse_enter(plant_cell)

## 鼠标移出cell
func _on_cell_mouse_exit(plant_cell:PlantCell):
	curr_plant_cell = null
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.mouse_exit(plant_cell)
		E_HandManagerStatus.Character:
			hm_character.mouse_exit(plant_cell)
		E_HandManagerStatus.Item:
			hm_item.mouse_exit(plant_cell)

## 取消角色和道具
func _input(event):
	## 当前手持状态不为空且鼠标点击事件
	if curr_hm_status != E_HandManagerStatus.Null and event is InputEventMouseButton:
		## 干员方向选择阶段: 左键点击任意处=确认方向, 右键=取消部署
		if curr_hm_status == E_HandManagerStatus.Character and hm_character.is_operator_dir_selecting:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				## 若点在格子上, 由 _on_click_cell 走 click_cell 确认; 点空白处在此确认
				if not curr_plant_cell:
					hm_character.confirm_operator_direction()
					curr_hm_status = E_HandManagerStatus.Null
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				hm_character.cancel_operator_direction()
				curr_hm_status = E_HandManagerStatus.Null
			return
		## 右键点击 或左鍵点击空白
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed or\
		event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not curr_plant_cell:
			SoundManager.play_other_SFX("tap2")
			curr_hm_status = E_HandManagerStatus.Null
