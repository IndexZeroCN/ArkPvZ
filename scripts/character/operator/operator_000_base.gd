extends Plant000Base
class_name Operator000Base
## 明日方舟干员基类
## 干员与植物友方, 复用植物种植/格子/被僵尸啃食/行渲染等完整管线(注册为 PlantType);
## 额外提供:
## - 技能条(SkillComponent)与技能系统(攻击回复/时间回复, 自动/手动触发)
## - 点击选择(OperatorManager 处理), 撤退返还部署点数, 手动释放技能
## - 部署消耗部署点数(非阳光, 见 card_base.is_operator_card)
## - 部署方向与有限攻击范围(见 DetectComponentOperator / get_attack_range_cells)
## - 入场/死亡动画

## 攻击方向
enum E_AttackDirection{
	Right,	## 朝右(默认, 面向僵尸)
	Left,	## 朝左
	Up,		## 朝上
	Down,	## 朝下
}

@onready var skill_component: SkillComponent = %SkillComponent
@onready var anim_operator: AnimComponentOperator = %AnimComponent

## 是否为召唤物(见 Summon000Base)
var is_summon := false
## 召唤物主人干员
var owner_operator: Operator000Base
## 是否可以撤退(召唤物默认不可以)
var is_can_retreat := true
## 是否可以手动释放技能(召唤物默认不可以)
var is_can_manual_skill := true

## 是否被选中(弹出了干员菜单)
var is_selected := false

## 部署方向
var attack_direction: E_AttackDirection = E_AttackDirection.Right

## 干员选中/取消选中信号
signal signal_operator_selected(is_selected:bool)

## 部署费用(消耗部署点数, 取注册表 SunCost; 召唤物无类型时返回0)
func get_deploy_point_cost() -> int:
	if plant_type == CharacterRegistry.PlantType.Null:
		return 0
	return Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)

func _ready() -> void:
	super()

## 初始化正常出战角色
func ready_norm():
	super()
	## 干员血条常显(不受控制台"显示植物血量"开关影响)
	hp_component.is_can_look_hp = false
	hp_component.visible = true
	## 技能条常显
	skill_component.visible = true
	## 入场动画(从下方升起淡入)
	play_enter_animation()
	## 通知干员管理器登记
	EventBus.push_event("operator_deployed", [self])

## 入场动画: 从下方升起 + 淡入(完成后播放待机动画)
func play_enter_animation() -> void:
	var operator_sprite: Node2D = get_operator_sprite()
	if not is_instance_valid(operator_sprite):
		return
	operator_sprite.modulate.a = 0.0
	var target_pos: Vector2 = operator_sprite.position
	operator_sprite.position.y = target_pos.y + 40.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(operator_sprite, "modulate:a", 1.0, 0.35)
	tween.tween_property(operator_sprite, "position:y", target_pos.y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(anim_operator):
		anim_operator.play_idle()

## 获取干员战斗形象容器(Body/BodyCorrect/OperatorSprite)
func get_operator_sprite() -> Node2D:
	var operator_sprite: Node2D = get_node_or_null("Body/BodyCorrect/OperatorSprite")
	return operator_sprite

## 设置部署方向(更新形象朝向与检测范围)
func set_attack_direction(new_direction: E_AttackDirection):
	attack_direction = new_direction
	## 左右朝向翻转形象
	var operator_sprite: Node2D = get_operator_sprite()
	if is_instance_valid(operator_sprite):
		var dir_x: float = 1.0 if attack_direction != E_AttackDirection.Left else -1.0
		operator_sprite.scale.x = abs(operator_sprite.scale.x) * dir_x
	## 更新检测组件方向
	var detect_component: Node = get_node_or_null("AttackComponent/DetectComponent")
	if detect_component is DetectComponentOperator:
		(detect_component as DetectComponentOperator).update_attack_direction(attack_direction)

## 获取攻击范围(按方向旋转): 返回以干员位置为基准的世界坐标格子中心列表
func get_attack_range_cells() -> Array[Vector2]:
	var cell_size: Vector2 = Vector2(76, 95)
	if is_instance_valid(plant_cell):
		cell_size = plant_cell.size
	return DetectComponentOperator.get_range_cells_by_direction(attack_direction, global_position, cell_size)

## 获取指定方向的攻击范围格子中心(世界坐标)
func get_attack_range_cells_by_direction(direction: E_AttackDirection) -> Array[Vector2]:
	var cell_size: Vector2 = Vector2(76, 95)
	if is_instance_valid(plant_cell):
		cell_size = plant_cell.size
	return DetectComponentOperator.get_range_cells_by_direction(direction, global_position, cell_size)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 攻击回复技能点
	var attack_component: AttackComponentOperator = get_node_or_null(^"AttackComponent")
	if attack_component:
		attack_component.signal_operator_shoot.connect(_on_operator_shoot)

## 每次攻击发射完一轮后的回调(攻击回复技能点)
func _on_operator_shoot():
	if skill_component.sp_recovery_type == SkillComponent.E_SpRecoveryType.Attack:
		skill_component.add_sp(skill_component.sp_gain_per_attack)

## 使用技能(手动或自动触发), 成功返回true
func use_skill() -> bool:
	if skill_component.use_skill():
		anim_operator.play_skill()
		_on_skill_use()
		return true
	return false

## 技能释放时的回调(子类重写)
func _on_skill_use():
	pass

## 本次攻击参数钩子(子类重写): 返回本次攻击的发射数与伤害倍率
## 例: 克洛丝技能连射 -> {"count": 2, "multiplier": 1.0}; 暴击 -> {"count": 1, "multiplier": 1.5}
func get_attack_paras() -> Dictionary:
	return {"count": 1, "multiplier": 1.0}

## 撤退: 返还部署点数并移除干员(与铲子一致, 不触发亡语)
func retreat():
	if not is_summon and is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
		var refund: int = int(get_deploy_point_cost() * Global.main_game.game_para.operator_retreat_refund_ratio)
		Global.main_game.operator_manager.add_deploy_point(refund)
	set_selected(false)
	be_shovel_kill()

## 选中/取消选中(弹出/关闭干员菜单)
func set_selected(new_is_selected:bool):
	is_selected = new_is_selected
	signal_operator_selected.emit(is_selected)

## 干员死亡: 播放死亡动画后移除
func character_death():
	## 死亡时取消选中并通知管理器
	set_selected(false)
	EventBus.push_event("operator_death", [self])

	is_death = true
	signal_character_death.emit()
	## 有亡语则触发
	if is_can_death_language:
		death_language()
	## 禁用受击盒, 防止死亡动画期间继续被攻击
	if is_instance_valid(hurt_box_component):
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	## 播放死亡动画(淡出)后移除
	anim_operator.play_die()
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		queue_free()

## 召唤物初始化(创建召唤物时在 add_child 前调用)
func init_summon(init_para:Dictionary):
	character_init_type = E_CharacterInitType.IsNorm
	is_summon = true
	owner_operator = init_para.get("owner_operator", null)
	is_can_retreat = init_para.get("is_can_retreat", false)
	is_can_manual_skill = init_para.get("is_can_manual_skill", false)
	plant_cell = init_para["plant_cell"]
	row_col = plant_cell.row_col
	lane = plant_cell.row_col.x
