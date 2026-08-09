extends Node
## 手持管理器，角色（植物僵尸）
class_name HM_Character

@onready var hand_manager: HandManager = %HandManager

## 角色临时挂载节点
@onready var temporary_character: Node2D = %TemporaryCharacter

## 当前卡片
var curr_card:Card = null
## 手持静态角色
var characte_static:Node2D
## 格子静态角色虚影
var characte_static_shadow:Node2D
## 植物种植条件
var plant_condition:ResourcePlantCondition
## 僵尸种植行条件
var zombie_row_type:CharacterRegistry.ZombieRowType
## 虚影在格子中，即可以种植
var is_shadow_in_cell:=false

## 柱子模式
var is_mode_column := false
## 柱子模式虚影
var characte_static_shadow_colum : Array[Node2D]

## 紫卡植物可以的预种植植物,点击卡片时明暗交替
var curr_all_preplant_purple:Array[Plant000Base]

## 当前鼠标所在格子(干员方向选择使用)
var curr_plant_cell:PlantCell
## 干员部署方向
var curr_operator_dir:Operator000Base.E_AttackDirection = Operator000Base.E_AttackDirection.Right
## 干员攻击范围预览节点(部署时显示)
var operator_range_preview:Node2D

func init_hm_character():
	self.is_mode_column = hand_manager.game_para.is_mode_column

func character_process() -> void:
	## CanvasItem方法获取位置
	characte_static.global_position = temporary_character.get_global_mouse_position()
	## 干员: 根据鼠标相对格子的位置实时更新部署方向与范围预览
	_update_operator_dir_if_operator()

## 点击卡片
func click_card(card:Card) -> void:
	## 清除之前数据
	if curr_card != null:
		_clear_curr_data()
	## 新植物数据
	curr_card = card
	EventBus.push_event("hm_character_hand_card", [curr_card])
	## 植物
	if curr_card.card_plant_type != CharacterRegistry.PlantType.Null:
		plant_condition = Global.character_registry.get_plant_info(curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		## 干员: 手持/虚影使用战斗形象(OperatorSprite), 而非卡片立绘
		if CharacterRegistry.is_operator_type(curr_card.card_plant_type):
			_create_operator_hand_static()
		else:
			## 静态植物以及植物虚影
			characte_static = card.character_static.duplicate()
			characte_static.get_child(0).scale = Vector2.ONE
			characte_static_shadow = characte_static.get_child(0).duplicate()
			characte_static_shadow.modulate.a = 0
			characte_static.z_index = 1

			temporary_character.add_child(characte_static)
			temporary_character.add_child(characte_static_shadow)

		## 干员: 创建攻击范围预览节点
		if CharacterRegistry.is_operator_type(curr_card.card_plant_type):
			_create_operator_range_preview()

		if click_card_column:
			click_card_column()

		# 如果是紫卡植物
		if plant_condition.is_purple_card:
			start_preplant_purple_light(plant_condition, curr_card.card_plant_type)

	## 僵尸
	else:
		zombie_row_type = Global.character_registry.get_zombie_info(curr_card.card_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		## 静态僵尸以及僵尸虚影
		characte_static = card.character_static.duplicate()
		characte_static.get_child(0).scale = Vector2.ONE
		characte_static_shadow = characte_static.get_child(0).duplicate()
		characte_static_shadow.modulate.a = 0
		characte_static.z_index = 1

		temporary_character.add_child(characte_static)
		temporary_character.add_child(characte_static_shadow)

		if click_card_column:
			click_card_column()

## 创建干员手持形象(战斗形象 OperatorSprite, 非立绘)
func _create_operator_hand_static():
	var operator_scene: PackedScene = Global.character_registry.get_plant_info(curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	var operator_temp: Node = operator_scene.instantiate()
	## 取战斗形象容器复制(含内部精灵, 尺寸与部署后一致)
	characte_static = operator_temp.get_node("Body/BodyCorrect/OperatorSprite").duplicate()
	operator_temp.free()
	characte_static_shadow = characte_static.duplicate()
	characte_static_shadow.modulate.a = 0
	characte_static.z_index = 1

	temporary_character.add_child(characte_static)
	temporary_character.add_child(characte_static_shadow)

## 创建干员攻击范围预览节点(半透明白色格子, 跟随部署方向)
func _create_operator_range_preview():
	operator_range_preview = Node2D.new()
	operator_range_preview.z_index = -1
	temporary_character.add_child(operator_range_preview)
	for i in DetectComponentOperator.ATTACK_RANGE_SHAPE.size():
		var cell_rect := ColorRect.new()
		cell_rect.color = Color(1, 1, 1, 0.22)
		cell_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_rect.visible = false
		operator_range_preview.add_child(cell_rect)

## 更新干员部署方向: 按鼠标相对格子的位置(象限)确定, 并刷新范围预览
func _update_operator_dir_if_operator():
	if curr_card == null or not CharacterRegistry.is_operator_type(curr_card.card_plant_type):
		return
	## 虚影不在可种植格子中时不计算方向
	if not is_shadow_in_cell or not is_instance_valid(curr_plant_cell):
		_hide_operator_range_preview()
		return
	var cell_center: Vector2 = characte_static_shadow.global_position
	var mouse_pos: Vector2 = temporary_character.get_global_mouse_position()
	var offset: Vector2 = mouse_pos - cell_center
	var new_dir: Operator000Base.E_AttackDirection
	if abs(offset.x) >= abs(offset.y):
		new_dir = Operator000Base.E_AttackDirection.Right if offset.x >= 0 else Operator000Base.E_AttackDirection.Left
	else:
		new_dir = Operator000Base.E_AttackDirection.Down if offset.y >= 0 else Operator000Base.E_AttackDirection.Up
	if new_dir != curr_operator_dir:
		curr_operator_dir = new_dir
	_update_operator_range_preview()

## 更新干员范围预览(按当前方向与虚影位置)
func _update_operator_range_preview():
	if not is_instance_valid(operator_range_preview):
		return
	var cell_size: Vector2 = Vector2(76, 95)
	if is_instance_valid(curr_plant_cell):
		cell_size = curr_plant_cell.size
	var base_pos: Vector2 = characte_static_shadow.global_position
	var cells: Array[Vector2] = DetectComponentOperator.get_range_cells_by_direction(curr_operator_dir, base_pos, cell_size)
	for i in range(operator_range_preview.get_child_count()):
		var cell_rect: ColorRect = operator_range_preview.get_child(i)
		if i < cells.size():
			cell_rect.visible = true
			cell_rect.position = cells[i] - cell_size / 2.0
			cell_rect.size = cell_size
		else:
			cell_rect.visible = false

## 隐藏干员范围预览
func _hide_operator_range_preview():
	if is_instance_valid(operator_range_preview):
		for cell_rect in operator_range_preview.get_children():
			cell_rect.visible = false

## 紫卡预种植植物身体明暗发光开始
func start_preplant_purple_light(curr_plant_condition:ResourcePlantCondition, plant_type:CharacterRegistry.PlantType):
	curr_all_preplant_purple = curr_plant_condition.get_all_preplant_purple(Global.main_game.plant_cell_manager.all_plant_cells, plant_type)
	for preplant_purple in curr_all_preplant_purple:
		preplant_purple.preplant_purple_body_light_and_dark()
#
## 紫卡预种植植物身体明暗发光结束
func end_preplant_purple_light():
	for preplant_purple in curr_all_preplant_purple:
		if is_instance_valid(preplant_purple):
			preplant_purple.preplant_purple_body_light_and_dark_end()

## 清除数据
func _clear_curr_data():
	# 如果是紫卡植物
	if plant_condition != null and plant_condition.is_purple_card:
		end_preplant_purple_light()

	is_shadow_in_cell = false
	curr_plant_cell = null
	curr_operator_dir = Operator000Base.E_AttackDirection.Right
	## 清除干员范围预览
	if is_instance_valid(operator_range_preview):
		operator_range_preview.queue_free()
		operator_range_preview = null
	## 若当前存在卡片,事件总线推清除当前卡片数据,种子雨卡槽接受判断
	if is_instance_valid(curr_card):
		EventBus.push_event("hm_character_clear_card", [curr_card])

	curr_card = null
	characte_static.queue_free()
	characte_static_shadow.queue_free()
	plant_condition = null
	zombie_row_type = CharacterRegistry.ZombieRowType.Land
	if is_mode_column:
		_clear_curr_data_column()

## 鼠标进入cell
func mouse_enter(plant_cell:PlantCell):
	curr_plant_cell = plant_cell
	is_shadow_in_cell = _update_cell_shadow(plant_cell, characte_static_shadow)
	## 干员: 显示范围预览
	if is_instance_valid(curr_card) and CharacterRegistry.is_operator_type(curr_card.card_plant_type):
		if is_shadow_in_cell:
			_update_operator_range_preview()
		else:
			_hide_operator_range_preview()
	if is_shadow_in_cell and is_mode_column:
		_mouse_enter_column(plant_cell)

## 更新植物格子虚影,返回是否能种植
func _update_cell_shadow(plant_cell:PlantCell, curr_characte_static_shadow:Node2D) -> bool:
	## 植物
	if curr_card.card_plant_type != 0:
		## 干员唯一性: 场上已有同类型干员则不可再种植
		if CharacterRegistry.is_operator_type(curr_card.card_plant_type)\
			and is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager)\
			and Global.main_game.operator_manager.get_operator_count_by_type(curr_card.card_plant_type) > 0:
			curr_characte_static_shadow.modulate.a = 0
			return false
		## 如果是判定是否可以种植植物
		if plant_condition.judge_is_can_plant(plant_cell, curr_card.card_plant_type):
			curr_characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true
		else:
			curr_characte_static_shadow.modulate.a = 0
			return false

	## 僵尸
	else:
		## 如果当前格子不能种植僵尸(蹦极除外)
		if not plant_cell.can_common_zombie and curr_card.card_zombie_type != CharacterRegistry.ZombieType.Z021Bungi:
			return false
		## 如果不是双地形
		if zombie_row_type != CharacterRegistry.ZombieRowType.Both:
			if zombie_row_type == Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_row_type:
				curr_characte_static_shadow.global_position =  get_zombie_static_shadow_global_position(plant_cell)
				curr_characte_static_shadow.modulate.a = 0.5
				return true
			else:
				curr_characte_static_shadow.modulate.a = 0
				return false
		else:
			curr_characte_static_shadow.global_position = get_zombie_static_shadow_global_position(plant_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true

## 获取种植僵尸的虚影位置
func get_zombie_static_shadow_global_position(plant_cell)->Vector2:
	var global_pos =  Vector2(
		plant_cell.global_position.x + plant_cell.size.x/2,
		Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
	)

	## 如果有斜面
	if is_instance_valid(Global.main_game.main_game_slope):
		global_pos += Vector2(0, Global.main_game.main_game_slope.get_all_slope_y(global_pos.x))


	return global_pos

## 鼠标移出cell
func mouse_exit(_plant_cell:PlantCell):
	characte_static_shadow.modulate.a = 0
	curr_plant_cell = null
	_hide_operator_range_preview()
	if is_mode_column:
		_mouse_exit_column()

## 点击种植植物\僵尸
func click_cell(plant_cell:PlantCell):
	if is_shadow_in_cell:
		if curr_card.card_plant_type != 0:
			plant_cell.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
			## 干员: 种植后设置部署方向
			if CharacterRegistry.is_operator_type(curr_card.card_plant_type):
				var operator_plant: Operator000Base = plant_cell.plant_in_cell.get(CharacterRegistry.PlacePlantInCell.Norm, null)
				if operator_plant is Operator000Base:
					operator_plant.set_attack_direction(curr_operator_dir)
		else:
			var zombie_init_para:Dictionary = {
				Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
				Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x,
			}

			Global.main_game.zombie_manager.create_norm_zombie(
				curr_card.card_zombie_type,
				Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x],
				zombie_init_para,
				Vector2(
					plant_cell.global_position.x + plant_cell.size.x/2,
					Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
				),
				GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, plant_cell)
			)

		## 卡片种植完成发射信号
		curr_card.signal_card_use_end.emit()
		if is_mode_column:
			_click_cell_column(plant_cell)

## 退出当前状态
func exit_status():
	_clear_curr_data()


#region 柱子模式额外操作函数
## 柱子模式 点击卡片产生多余植物虚影
func click_card_column() -> void:
	if curr_card.card_plant_type != 0:
		for plant_cell_i in range(Global.main_game.plant_cell_manager.row_col.x):
			var column_characte_static_shadow = characte_static_shadow.duplicate()
			column_characte_static_shadow.modulate.a = 0
			temporary_character.add_child(column_characte_static_shadow)
			characte_static_shadow_colum.append(column_characte_static_shadow)
	else:
		for zombie_rows_i in range(Global.main_game.zombie_manager.all_zombie_rows.size()):
			var column_characte_static_shadow = characte_static_shadow.duplicate()
			column_characte_static_shadow.modulate.a = 0
			temporary_character.add_child(column_characte_static_shadow)
			characte_static_shadow_colum.append(column_characte_static_shadow)

## 柱子模式 鼠标进入判断其他格子是否可以种植，产生虚影
func _mouse_enter_column(plant_cell:PlantCell):
	for plant_cell_i in range(Global.main_game.plant_cell_manager.row_col.x):
		if plant_cell_i == plant_cell.row_col.x:
			continue

		## 判断是否产生虚影
		_update_cell_shadow(
			Global.main_game.plant_cell_manager.all_plant_cells[plant_cell_i][plant_cell.row_col.y],\
			characte_static_shadow_colum[plant_cell_i]
		)

## 柱子模式 鼠标移出cell
func _mouse_exit_column():
	for _characte_static_shadow in characte_static_shadow_colum:
		_characte_static_shadow.modulate.a = 0

## 柱子模式 点击种植或铲掉植物
func _click_cell_column(plant_cell:PlantCell):
	if curr_card.card_plant_type != 0:
		for i in range(characte_static_shadow_colum.size()):
			## 当前格子的图像透明
			var _characte_static_shadow = characte_static_shadow_colum[i]
			if _characte_static_shadow.modulate.a != 0:
				var _plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[i][plant_cell.row_col.y]
				_plant_cell.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
	else:
		for i in range(characte_static_shadow_colum.size()):
			## 当前格子的图像透明
			var _characte_static_shadow = characte_static_shadow_colum[i]
			if _characte_static_shadow.modulate.a != 0:
				var _plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[i][plant_cell.row_col.y]

				var zombie_init_para:Dictionary = {
					Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
					Zombie000Base.E_ZInitAttr.Lane:_plant_cell.row_col.x,
				}

				Global.main_game.zombie_manager.create_norm_zombie(
					curr_card.card_zombie_type,
					Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x],
					zombie_init_para,

					Vector2(_characte_static_shadow.global_position.x,
						Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x].zombie_create_position.global_position.y
					),
					GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, _plant_cell)
				)

## 柱子模式 清除数据
func _clear_curr_data_column():
	for _characte_static_shadow in characte_static_shadow_colum:
		_characte_static_shadow.queue_free()
	characte_static_shadow_colum.clear()

#endregion
