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
## 干员攻击范围预览节点(格子连续多边形+45度条纹, 部署方向选择阶段显示)
var operator_range_preview:OperatorRangePreview
## OperatorSprite 相对干员根的偏移(Body/BodyCorrect 链, 虚影放格子时补上, 保证与真实干员 y 对齐)
var operator_sprite_offset := Vector2.ZERO

## 干员两段部署: 第一段仅确定位置(只放预览虚影, 不创建), 第二段按鼠标朝向确定方向(显示范围), 确认后才真正创建干员并播放上场动画
var is_operator_dir_selecting := false
## 方向选择阶段的目标格(第一段点击的格子)
var placing_cell: PlantCell = null

func init_hm_character():
	self.is_mode_column = hand_manager.game_para.is_mode_column

func character_process() -> void:
	## CanvasItem方法获取位置
	characte_static.global_position = temporary_character.get_global_mouse_position()
	## 干员: 格子上已显示地面预览虚影时, 隐藏鼠标上的干员形象(避免重叠; 只针对干员, 植物不变)
	if curr_card != null and CharacterRegistry.is_operator_type(curr_card.card_plant_type) and not is_operator_dir_selecting:
		characte_static.visible = not is_shadow_in_cell
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
	## 应用干员校准数据(JSON), 让部署预览与部署后一致(位置/缩放/发射点)
	OperatorCalibration.apply_to(operator_temp)
	## OperatorSprite 相对干员根的偏移(Body/BodyCorrect 链): 虚影(OperatorSprite 副本)放在格子时要补上,
	## 否则与真实干员的 OperatorSprite 位置差 Body+BodyCorrect+OperatorSprite 的偏移, y 没对齐
	operator_sprite_offset = (operator_temp.get_node("Body/BodyCorrect/OperatorSprite") as Node2D).global_position
	## 取战斗形象容器复制(含内部精灵, 尺寸与部署后一致)
	characte_static = operator_temp.get_node("Body/BodyCorrect/OperatorSprite").duplicate()
	operator_temp.free()
	characte_static_shadow = characte_static.duplicate()
	characte_static_shadow.modulate.a = 0
	characte_static.z_index = 1

	temporary_character.add_child(characte_static)
	temporary_character.add_child(characte_static_shadow)
	## 预览虚影(含手持)播放 Spine 待机动画, 不再是静态帧
	_play_operator_shadow_spine("Idle")

## 在虚影/手持节点内查找 OperatorSpineSprite 并播放动画
func _play_operator_shadow_spine(anim_name: String) -> void:
	for shadow in [characte_static, characte_static_shadow]:
		if not is_instance_valid(shadow):
			continue
		for child in shadow.get_children():
			if child is OperatorSpineSprite:
				(child as OperatorSpineSprite).play_spine(anim_name, true)
				break

## 预览虚影按部署方向切换正/背面素材: 朝上(后)方向 → 背面素材(显示后背), 其余 → 正面素材
func _update_shadow_back_visual() -> void:
	if not is_instance_valid(characte_static_shadow):
		return
	for child in characte_static_shadow.get_children():
		if child is OperatorSpineSprite:
			(child as OperatorSpineSprite).switch_data(curr_operator_dir == Operator000Base.E_AttackDirection.Up)
			break

## 创建干员攻击范围预览节点(格子连续多边形+45度条纹, 部署阶段显示; 已存在则复用)
func _create_operator_range_preview():
	if not is_instance_valid(operator_range_preview):
		operator_range_preview = OperatorRangePreview.new()
		operator_range_preview.z_index = -1
		temporary_character.add_child(operator_range_preview)
	operator_range_preview.visible = true

## 更新干员范围预览(基于真实草坪格子节点生成范围, 与草坪完全对齐; 矩形边长=网格间距补上空隙)
## 范围含干员所在格(ATTACK_RANGE_SHAPE 含 (0,0) 即画; 特殊干员在形状中不含 (0,0))
## cell 为空时用 placing_cell(第二段); 传入时用指定格(第一段虚影所在格)
func _update_operator_range_preview(cell: PlantCell = null):
	if not is_instance_valid(operator_range_preview):
		return
	if not is_instance_valid(cell):
		cell = placing_cell
	if not is_instance_valid(cell):
		return
	var operator_cell: PlantCell = cell
	var base_pos: Vector2 = operator_cell.global_position + operator_cell.size * 0.5
	## 网格间距(相邻格子中心距离, 用作矩形边长 = 自动补上格间空隙)
	var spacing: Vector2 = DetectComponentOperator.get_grid_spacing(operator_cell)
	## 范围格子中心: 与检测共用真实网格生成逻辑(与草坪完全对齐; 越界格跳过)
	var range_cells: Array[Vector2] = DetectComponentOperator.get_range_cells_on_grid(curr_operator_dir, operator_cell)
	operator_range_preview.set_range_cells(range_cells, spacing, base_pos)

## 隐藏干员范围预览
func _hide_operator_range_preview():
	if is_instance_valid(operator_range_preview):
		operator_range_preview.visible = false

## 更新干员部署方向:
## 第一段(定位): 方向固定为右, 虚影所在格可种植时显示朝右的攻击范围预览
## 第二段(选方向): 按鼠标相对目标格的方位实时更新方向与范围预览, 预览虚影朝向跟随
func _update_operator_dir_if_operator():
	if curr_card == null or not CharacterRegistry.is_operator_type(curr_card.card_plant_type):
		return
	if is_operator_dir_selecting:
		## 第二段: 以鼠标相对目标格的方位确定方向, 实时应用
		if not is_instance_valid(placing_cell):
			return
		var cell_center: Vector2 = placing_cell.global_position + placing_cell.size * 0.5
		curr_operator_dir = _dir_from_offset(cell_center, temporary_character.get_global_mouse_position())
		## 预览虚影朝向跟随方向(左右翻转)
		characte_static_shadow.scale.x = abs(characte_static_shadow.scale.x) * (1.0 if curr_operator_dir != Operator000Base.E_AttackDirection.Left else -1.0)
		## 预览虚影素材按方向: 朝上(后) → 背面素材显示后背
		_update_shadow_back_visual()
		_update_operator_range_preview()
		return
	## 第一段: 方向固定为右, 显示朝右的攻击范围(锚点 = 虚影所在格)
	curr_operator_dir = Operator000Base.E_AttackDirection.Right
	if not is_shadow_in_cell or not is_instance_valid(curr_plant_cell):
		_hide_operator_range_preview()
		return
	if not is_instance_valid(operator_range_preview):
		_create_operator_range_preview()
	operator_range_preview.visible = true
	operator_range_preview.show_hint = false
	_update_operator_range_preview(curr_plant_cell)

## 按鼠标相对格心的方位(象限)确定部署方向
func _dir_from_offset(cell_center: Vector2, mouse_pos: Vector2) -> Operator000Base.E_AttackDirection:
	var offset: Vector2 = mouse_pos - cell_center
	if abs(offset.x) >= abs(offset.y):
		return Operator000Base.E_AttackDirection.Right if offset.x >= 0 else Operator000Base.E_AttackDirection.Left
	return Operator000Base.E_AttackDirection.Down if offset.y >= 0 else Operator000Base.E_AttackDirection.Up

## 进入干员方向选择阶段(第一段点击后): 不创建干员, 只把预览虚影固定到目标格并显示范围
## 方向固定为右(与第一段一致), 鼠标移动后进入第二段动态方向
func _enter_operator_dir_select(plant_cell: PlantCell):
	is_operator_dir_selecting = true
	placing_cell = plant_cell
	curr_operator_dir = Operator000Base.E_AttackDirection.Right
	## 隐藏手持实体, 预览虚影固定到目标格(不透明, 朝向为右)
	characte_static.visible = false
	var place_plant_in_cell: CharacterRegistry.PlacePlantInCell = plant_condition.place_plant_in_cell
	characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(place_plant_in_cell) + operator_sprite_offset
	characte_static_shadow.modulate.a = 1.0
	characte_static_shadow.scale.x = abs(characte_static_shadow.scale.x)
	## 进入方向选择: 虚影素材重置为正面(方向初始为右)
	_update_shadow_back_visual()
	_create_operator_range_preview()
	operator_range_preview.show_hint = true
	_update_operator_range_preview()

## 确认方向(第二段点击): 在目标格真正创建干员(播放上场动画), 结束手持并扣部署点
func confirm_operator_direction():
	var created: Operator000Base = null
	if is_instance_valid(placing_cell) and is_instance_valid(curr_card):
		var plant: Plant000Base = placing_cell.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
		if plant is Operator000Base:
			created = plant as Operator000Base
			created.set_attack_direction(curr_operator_dir)
			## 上场动画由 ready_norm 自动播放(Spine Start → Idle)
	_clean_operator_dir_select()
	## 创建成功才扣部署点; 失败(格子被占等)不扣费不冷却, 由手持状态切换统一清理
	if is_instance_valid(created) and is_instance_valid(curr_card):
		curr_card.signal_card_use_end.emit()

## 取消部署(第二段右键): 未创建干员, 直接清理(不扣部署点/不触发冷却)
func cancel_operator_direction():
	_clean_operator_dir_select()

func _clean_operator_dir_select():
	is_operator_dir_selecting = false
	placing_cell = null
	if is_instance_valid(operator_range_preview):
		operator_range_preview.queue_free()
		operator_range_preview = null

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
	## 清理干员方向选择阶段
	_clean_operator_dir_select()
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
	## 干员方向选择阶段: 预览虚影已固定到目标格, 不随鼠标所在格更新
	if is_operator_dir_selecting:
		return
	is_shadow_in_cell = _update_cell_shadow(plant_cell, characte_static_shadow)
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
			curr_characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell) + operator_sprite_offset
			## 干员预览虚影不透明(100), 植物/僵尸保持半透明
			curr_characte_static_shadow.modulate.a = 1.0 if CharacterRegistry.is_operator_type(curr_card.card_plant_type) else 0.5
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
	curr_plant_cell = null
	## 干员方向选择阶段: 预览虚影/范围保持, 不随鼠标隐显
	if is_operator_dir_selecting:
		return
	characte_static_shadow.modulate.a = 0
	_hide_operator_range_preview()
	if is_mode_column:
		_mouse_exit_column()

## 点击种植植物\僵尸; 返回是否结束手持(true=结束)
func click_cell(plant_cell:PlantCell) -> bool:
	## 干员方向选择阶段: 第二次点击 = 确认方向
	if is_operator_dir_selecting:
		confirm_operator_direction()
		return true
	if is_shadow_in_cell:
		if curr_card.card_plant_type != 0:
			## 干员: 两段部署 - 第一段仅确定位置(只放预览虚影, 不创建干员), 进入方向选择阶段
			if CharacterRegistry.is_operator_type(curr_card.card_plant_type):
				_enter_operator_dir_select(plant_cell)
				return false
			plant_cell.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
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
	return true

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
