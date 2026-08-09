extends MainGameSubManager
class_name OperatorManager
## 干员管理器
## 职责:
## - 部署点数: 持有/自动回复/广播(EventBus "update_deploy_point"), 部署扣除与撤退返还
## - 点击选择干员: 弹出/关闭干员菜单, 处理撤退/技能按钮
## - 登记部署中的干员(为后续维什戴尔等需要干员交互的技能做准备)

## 当前部署点数(广播更新, 卡片/UI 订阅)
var deploy_point := 0:
	set(value):
		## game_para 在 _enter_tree 后才有值, 此处做空值保护
		var max_dp: int = 99
		if is_instance_valid(game_para):
			max_dp = game_para.operator_max_deploy_point
		deploy_point = clampi(value, 0, max_dp)
		EventBus.push_event("update_deploy_point", [deploy_point])

## 部署中的干员列表
var all_operators: Array[Operator000Base] = []
## 当前选中的干员
var curr_selected_operator: Operator000Base

## 干员菜单
var menu: OperatorMenu

## 部署点数回复计时
var deploy_point_regen_timer: float = 0.0

func init_manager() -> void:
	## 初始化部署点数(测试模式直接满额方便调试)
	if main_game.is_test:
		deploy_point = game_para.operator_max_deploy_point
	else:
		deploy_point = game_para.operator_start_deploy_point

	## 创建干员菜单
	menu = load("res://scenes/operator/operator_menu.tscn").instantiate()
	add_child(menu)
	menu.signal_use_skill.connect(_on_menu_use_skill)
	menu.signal_retreat.connect(_on_menu_retreat)
	menu.signal_close.connect(_on_menu_close)

	## 登记干员部署/死亡
	EventBus.subscribe("operator_deployed", _on_operator_deployed)
	EventBus.subscribe("operator_death", _on_operator_death)
	## 阶段切换时关闭菜单
	EventBus.subscribe("main_game_progress_update", _on_main_game_progress_update)

func _process(delta: float) -> void:
	## 只在游戏阶段回复部署点数
	if main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return
	if game_para.operator_regen_interval > 0 and deploy_point < game_para.operator_max_deploy_point:
		deploy_point_regen_timer += delta
		if deploy_point_regen_timer >= game_para.operator_regen_interval:
			deploy_point_regen_timer = 0.0
			add_deploy_point(1)

## 增加部署点数(撤退返还等)
func add_deploy_point(value: int):
	deploy_point += value

## 减少部署点数(部署干员时)
func use_deploy_point(value: int):
	deploy_point -= value

#region 干员登记
func _on_operator_deployed(operator: Operator000Base):
	all_operators.append(operator)

func _on_operator_death(operator: Operator000Base):
	all_operators.erase(operator)
	## 若选中的干员死亡, 关闭菜单
	if curr_selected_operator == operator:
		deselect_operator()

## 获取指定类型干员的在场数量(干员唯一性: 每类型场上最多1个)
func get_operator_count_by_type(plant_type: CharacterRegistry.PlantType) -> int:
	var count: int = 0
	for operator: Operator000Base in all_operators:
		if is_instance_valid(operator) and operator.plant_type == plant_type:
			count += 1
	return count
#endregion

#region 点击选择干员
func _unhandled_input(event: InputEvent) -> void:
	## 仅游戏阶段左键点击
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
			return
		## 手持卡片/铲子时交由手持系统处理, 不响应
		if main_game.hand_manager.curr_hm_status != HandManager.E_HandManagerStatus.Null:
			return
		var clicked_operator: Operator000Base = get_operator_under_mouse()
		if is_instance_valid(clicked_operator):
			## 点击已选中干员则取消选中, 否则选中
			if clicked_operator == curr_selected_operator:
				deselect_operator()
			else:
				select_operator(clicked_operator)
		else:
			## 点击空白处关闭菜单
			deselect_operator()

## 获取鼠标位置命中的干员
func get_operator_under_mouse() -> Operator000Base:
	var mouse_pos: Vector2 = main_game.get_global_mouse_position()
	## 物理点查询优先(正确按层级取最上层)
	var operator_found: Operator000Base = _get_operator_by_physics_query(mouse_pos)
	if is_instance_valid(operator_found):
		return operator_found
	## 回退: 遍历已部署干员做矩形判定(防止受击盒不可点查询时漏选)
	for operator in all_operators:
		if not is_instance_valid(operator) or operator.is_death:
			continue
		## 点击判定盒略大于受击盒(角色根部地面为准)
		var click_rect := Rect2(operator.global_position + Vector2(-35, -100), Vector2(70, 110))
		if click_rect.has_point(mouse_pos):
			return operator
	return null

## 物理点查询(植物受击检测层 layer 2)
func _get_operator_by_physics_query(mouse_pos:Vector2) -> Operator000Base:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2
	var results: Array = main_game.get_world_2d().direct_space_state.intersect_point(query)
	for result in results:
		var area: Area2D = result.get("collider")
		if not (area is Area2D):
			continue
		## 沿父节点链找到干员本体(HurtBoxDetection -> HurtBoxComponent -> 角色根)
		var node: Node = area
		while is_instance_valid(node):
			if node is Operator000Base:
				return node as Operator000Base
			node = node.get_parent()
	return null
#endregion

#region 选中/取消选中
func select_operator(operator: Operator000Base):
	deselect_operator()
	curr_selected_operator = operator
	operator.set_selected(true)
	menu.open_menu(operator)

func deselect_operator():
	if is_instance_valid(curr_selected_operator):
		curr_selected_operator.set_selected(false)
	curr_selected_operator = null
	if is_instance_valid(menu):
		menu.close_menu()
#endregion

#region 菜单按钮
func _on_menu_use_skill():
	if is_instance_valid(curr_selected_operator):
		if not curr_selected_operator.use_skill():
			## 技能未就绪
			SoundManager.play_other_SFX("buzzer")

func _on_menu_retreat():
	if is_instance_valid(curr_selected_operator):
		curr_selected_operator.retreat()

func _on_menu_close():
	deselect_operator()
#endregion

## 主游戏阶段切换时关闭菜单
func _on_main_game_progress_update(progress: int):
	if progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		deselect_operator()
