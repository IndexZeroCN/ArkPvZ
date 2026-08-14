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

## 干员 id（素材文件夹名, 与 data/operator_calibration.json 的键一致, 供校准数据查询）
@export var operator_id: String = ""

## 阻挡数（能同时阻挡的僵尸数量; 超过该数量的僵尸会穿过不停止啃食）
## 方舟高台干员(速射手/投掷手)与执旗手均为 1; 近卫/重装等为 2~3(后续干员覆盖)
@export var block_count: int = 1

@onready var skill_component: SkillComponent = %SkillComponent
@onready var anim_operator: AnimComponentOperator = %AnimComponent
## 攻击组件(召唤物等无 AttackComponent 节点时为 null, 使用前判空)
@onready var attack_component: AttackComponentOperator = get_node_or_null(^"AttackComponent") as AttackComponentOperator

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
	## 应用干员校准数据(JSON), 在 super 分发 ready_norm 之前应用, 确保入场动画使用校准位置/缩放
	OperatorCalibration.apply_to(self)
	super()

#region 干员通用音效(无专属音效的干员用默认键; 子类可覆盖返回专属键或空=静音)
## 部署音效键(默认部署音效)
func get_deploy_sfx() -> StringName:
	return &"OperatorDeploy"
## 死亡音效键(默认干员死亡音效)
func get_death_sfx() -> StringName:
	return &"OperatorDeath"
## 技能发动音效键(默认技能发动音效)
func get_skill_use_sfx() -> StringName:
	return &"OperatorSkill"
#endregion

## 是否可被友方治疗(收割者等特性"无法被友方角色治疗"的干员覆盖为 false)
func can_be_healed_by_ally() -> bool:
	return true

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
	## 部署音效(无专属部署音效的干员用默认)
	SoundManager.play_character_SFX(get_deploy_sfx())

## 展示模式(选关封面等): 基类 ready_show 不播动画, 这里只播 Spine 待机循环,
## 不播入场动画、不播部署音效(避免进主界面听到部署音/看到入场动画);
## 并隐藏脚下阴影(否则封面干员下方显示一条黑色椭圆"黑条")
func ready_show():
	super()
	var shadow_node: Node = get_node_or_null("Shadow")
	if is_instance_valid(shadow_node):
		shadow_node.visible = false
	var spine: SpineSprite = get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).play_spine((spine as OperatorSpineSprite).get_anim_name("idle"), true)

## 入场动画: 有 Spine 形象时直接播放 Spine 入场动画(Start), 播完自动接待机(Idle)
## (入场表演完全由 Spine 动画承担, 不使用 tween 淡入升起等旧占位动画)
func play_enter_animation() -> void:
	var spine: SpineSprite = get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).play_spine_sequence(
			(spine as OperatorSpineSprite).get_anim_name("enter"),
			(spine as OperatorSpineSprite).get_anim_name("idle"))

## 获取干员战斗形象容器(Body/BodyCorrect/OperatorSprite)
func get_operator_sprite() -> Node2D:
	var operator_sprite: Node2D = get_node_or_null("Body/BodyCorrect/OperatorSprite")
	return operator_sprite

## 获取干员 Spine 形象节点(OperatorSprite 下第一个 SpineSprite; 无则返回 null)
func get_operator_spine() -> SpineSprite:
	var operator_sprite: Node2D = get_operator_sprite()
	if not is_instance_valid(operator_sprite):
		return null
	for child in operator_sprite.get_children():
		if child is SpineSprite:
			return child as SpineSprite
	return null

## 设置部署方向(更新形象朝向与检测范围)
## 部署方向 Up/Down(朝上/下, 背对镜头)时默认素材为背面(入场也显示背面)
func set_attack_direction(new_direction: E_AttackDirection):
	var old_dir: E_AttackDirection = attack_direction
	attack_direction = new_direction
	## 默认素材按方向切换(部署时直接切换, 不走转身动画)
	var want_back: bool = is_default_back_direction()
	if is_back_visual != want_back:
		is_back_visual = want_back
		var spine: SpineSprite = get_operator_spine()
		if is_instance_valid(spine):
			(spine as OperatorSpineSprite).switch_data(want_back)
		## 部署后才设置方向且素材切换: 重播入场动画, 让入场显示目标素材(背面方向入场)
		if old_dir != new_direction and is_instance_valid(spine):
			play_enter_animation()
	## 朝向 scale 按部署方向
	var operator_sprite: Node2D = get_operator_sprite()
	if is_instance_valid(operator_sprite):
		operator_sprite.scale.x = get_default_scale_x()
	## 同步期望视觉状态(与部署后实际一致, 避免首次检测误触发转身动画)
	_target_back = is_back_visual
	_target_scale = get_default_scale_x()
	## 更新检测组件方向
	var detect_component: Node = get_node_or_null("AttackComponent/DetectComponent")
	if detect_component is DetectComponentOperator:
		(detect_component as DetectComponentOperator).update_attack_direction(attack_direction)

## 默认朝向的 scale.x(面朝攻击方向; 朝左镜像)
func get_default_scale_x() -> float:
	return -1.0 if attack_direction == E_AttackDirection.Left else 1.0

## 部署方向是否默认显示背面素材(子类可覆盖; 只有朝上(后)时背对镜头)
func is_default_back_direction() -> bool:
	return attack_direction == E_AttackDirection.Up

#region 转身/正背面切换(检测组件按目标驱动)
## 当前是否显示背面素材(BattleBack)
var is_back_visual := false
## 转身动画 tween
var _turn_tween: Tween
## 转身动画时长(scale 归零/恢复各一段)
const TURN_ANIM_TIME := 0.08
## 左右朝向判定滞回带(px): 僵尸 x 在干员 x ± 此范围内保持上次朝向, 避免临界抖动抽搐
const TURN_FLIP_HYSTERESIS := 12.0
## 上一次判定的"目标在右侧"
var _last_target_right := true
## 期望的最终视觉状态(防重用: 转身动画进行中或已到位都视为"已请求", 避免 0.1s 检测反复 kill 动画)
var _target_back := false
var _target_scale := 1.0

## 根据攻击目标更新干员视觉(素材 + scale, 带转身动画)
## 素材: 目标在干员上方行 → 背面; 下方行 → 正面(背面反之); 同排 → 保持当前素材
## scale: 只由目标左右决定(正面/背面素材原始都面朝右) —— 目标在右侧 → +1, 左侧 → -1
func update_visual_for_target(target: Zombie000Base) -> void:
	if not is_instance_valid(target) or not is_instance_valid(plant_cell):
		reset_visual()
		return
	## 素材: 上方行 → 背面; 下方行 → 正面; 同排 → 保持当前素材(不因僵尸左右移动而切换)
	var lane_diff: int = target.lane - plant_cell.row_col.x
	var want_back: bool
	if lane_diff < 0:
		want_back = true
	elif lane_diff > 0:
		want_back = false
	else:
		want_back = is_back_visual
	## scale 只由目标左右位置决定: 目标在右侧 → +1, 左侧 → -1
	## (正面/背面素材原始都面朝右, 素材只决定"视角"; 实测背面+右侧应 +1, 之前把背面误当面朝左导致正负反了)
	var diff_x: float = target.global_position.x - global_position.x
	var target_right: bool
	if diff_x >= TURN_FLIP_HYSTERESIS:
		target_right = true
	elif diff_x <= -TURN_FLIP_HYSTERESIS:
		target_right = false
	else:
		target_right = _last_target_right
	_last_target_right = target_right
	var want_scale: float = 1.0 if target_right else -1.0
	_apply_visual(want_back, want_scale)

## 应用素材 + scale(素材变化或 scale 变化时播转身动画)
func _apply_visual(want_back: bool, want_scale: float):
	var operator_sprite: Node2D = get_operator_sprite()
	if not is_instance_valid(operator_sprite):
		return
	## 期望状态未变化(动画进行中或已到位) → 跳过
	## 注意: 不能用"当前 scale == 目标"判断——转身动画 0.16s 长, 检测每 0.1s 调用,
	##       动画中当前 scale 是中间值, 用当前值判断会反复 kill 重播, 动画永远到不了目标
	if _target_back == want_back and is_equal_approx(_target_scale, want_scale):
		return
	_target_back = want_back
	_target_scale = want_scale
	is_back_visual = want_back
	_play_turn_animation(want_scale)

## 恢复默认视觉(默认素材 + 部署朝向), 带转身动画
## 默认素材按部署方向: 朝上(后)部署 → 背面, 入场后不攻击也一直保持背面
func reset_visual():
	_apply_visual(is_default_back_direction(), get_default_scale_x())

## 转身动画: scale.x 归零 → 切换素材(如需) → 恢复到目标 scale
func _play_turn_animation(target_scale_x: float):
	var operator_sprite: Node2D = get_operator_sprite()
	if not is_instance_valid(operator_sprite):
		return
	if is_instance_valid(_turn_tween):
		_turn_tween.kill()
	var spine: SpineSprite = get_operator_spine()
	_turn_tween = create_tween()
	_turn_tween.tween_property(operator_sprite, "scale:x", 0.0, TURN_ANIM_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_turn_tween.tween_callback(func():
		## 归零(不可见)时切换正/背面素材, 重播缓存动画
		if is_instance_valid(spine):
			(spine as OperatorSpineSprite).switch_data(is_back_visual)
	)
	_turn_tween.tween_property(operator_sprite, "scale:x", target_scale_x, TURN_ANIM_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
#endregion

## 攻击范围形状(子类可覆盖): (行偏移, 列偏移), 以干员所在格为基准
## 默认 = 克洛丝速射手 3行x4列(见 DetectComponentOperator.ATTACK_RANGE_SHAPE)
func get_attack_range_shape() -> Array[Vector2i]:
	return DetectComponentOperator.ATTACK_RANGE_SHAPE

## 获取攻击范围(按方向旋转): 返回以干员所在格中心为基准的世界坐标格子中心列表
## 有植物格时直接取真实植物格节点(与部署预览完全一致); 无则退化为像素偏移方式
func get_attack_range_cells() -> Array[Vector2]:
	if is_instance_valid(plant_cell):
		return DetectComponentOperator.get_range_cells_on_grid(attack_direction, plant_cell, get_attack_range_shape())
	return DetectComponentOperator.get_range_cells_by_direction(attack_direction, global_position, DetectComponentOperator.GRID_CELL_SIZE, get_attack_range_shape())

## 获取指定方向的攻击范围格子中心(世界坐标)
func get_attack_range_cells_by_direction(direction: E_AttackDirection) -> Array[Vector2]:
	if is_instance_valid(plant_cell):
		return DetectComponentOperator.get_range_cells_on_grid(direction, plant_cell, get_attack_range_shape())
	return DetectComponentOperator.get_range_cells_by_direction(direction, global_position, DetectComponentOperator.GRID_CELL_SIZE, get_attack_range_shape())

## 获取攻击范围内所有可攻击僵尸(以自己 plant_cell 为基准 + get_attack_range_shape(), 格子级菱形判定)
## 维什戴尔(普通攻击/技能多目标)与魂灵之影(技能)共用;
## 魂灵之影以自己所在格为基准 + 继承主人形状(get_attack_range_shape 返回主人形状)
func get_targets_in_range() -> Array[Zombie000Base]:
	var result: Array[Zombie000Base] = []
	if not is_instance_valid(plant_cell) or not is_instance_valid(Global.main_game):
		return result
	## 检测组件: 干员在 AttackComponent 下, 召唤物(魂灵之影)在根节点下
	var detect: DetectComponentOperator = get_node_or_null("AttackComponent/DetectComponent") as DetectComponentOperator
	if detect == null:
		detect = get_node_or_null("DetectComponent") as DetectComponentOperator
	if not is_instance_valid(detect):
		return result
	## 格子级判定(与 judge_have_enemy 一致): 菱形范围格子集合
	var rc_set: Dictionary = {}
	for target_rc: Vector2i in DetectComponentOperator.get_range_rcs_on_grid(attack_direction, plant_cell, get_attack_range_shape()):
		rc_set[target_rc] = true
	var spacing_x: float = DetectComponentOperator.get_grid_spacing(plant_cell).x
	var lane_offsets: Array = detect._get_lane_offsets(attack_direction)
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		if not zombie.curr_be_attack_status & detect.can_attack_zombie_status:
			continue
		if not (zombie.lane - plant_cell.row_col.x) in lane_offsets:
			continue
		if not DetectComponentOperator.is_zombie_in_range_rcs(zombie, rc_set, spacing_x):
			continue
		result.append(zombie)
	return result

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 攻击回复技能点
	if is_instance_valid(attack_component):
		attack_component.signal_operator_shoot.connect(_on_operator_shoot)
	## 技能触发统一走 _on_skill_component_use: 手动(use_skill)/组件自动触发都经过 signal_skill_use
	skill_component.signal_skill_use.connect(_on_skill_component_use)

## 技能被触发(手动 use_skill 或组件自动触发): 播技能动画 + 音效 + 子类技能效果
func _on_skill_component_use():
	anim_operator.play_skill()
	## 仅手动触发的技能播放技能发动音效; 自动回复/自动触发的技能(克洛丝二连射/维什戴尔一技能/魂灵技能)静默发动
	if not skill_component.is_auto_trigger:
		SoundManager.play_character_SFX(get_skill_use_sfx())
	_on_skill_use()

## 每次攻击发射完一轮后的回调(攻击回复技能点)
func _on_operator_shoot():
	if skill_component.sp_recovery_type == SkillComponent.E_SpRecoveryType.Attack:
		skill_component.add_sp(skill_component.sp_gain_per_attack)

## 技能激活期间的攻击动画(子类覆盖, 如维什戴尔二/三技能播 Skill_2/3_Loop); 空=普通攻击动画
func get_skill_attack_anim() -> String:
	return ""

## 技能攻击后的待机动画(技能持续期间的待机动作); 空=普通待机
func get_skill_idle_anim() -> String:
	return ""

## 干员技能图标(干员菜单技能按钮显示, 子类按所选技能覆盖; 默认克洛丝图标兼容单技能干员)
func get_skill_icon() -> Texture2D:
	return preload("res://assets/image/operator/kroos/skill_icon.png")

## 使用技能(手动或自动触发), 成功返回true
## 技能效果经 signal_skill_use -> _on_skill_component_use 统一触发
func use_skill() -> bool:
	return skill_component.use_skill()

## 当前攻击动画时长(秒): 多连发技能条橙色倒计时用; 无 Spine 时退化为攻击间隔
func get_current_attack_anim_duration() -> float:
	var spine := get_operator_spine()
	if is_instance_valid(spine):
		var d := (spine as OperatorSpineSprite).get_current_anim_duration()
		if d > 0.0:
			return d
	return attack_component.attack_cd if is_instance_valid(attack_component) else 1.0

## 本次攻击开始时尝试消耗已就绪的技能并启动橙色技能条倒计时(多连发技能用)
## 返回是否本次攻击消耗了技能(子类据此设置连发/连击标记)
func try_start_skill_burst() -> bool:
	if not is_instance_valid(skill_component) or not skill_component.is_skill_ready:
		return false
	skill_component.is_skill_ready = false
	skill_component.curr_sp = 0.0
	skill_component.start_burst_bar(get_current_attack_anim_duration())
	return true

## 技能释放时的回调(子类重写)
func _on_skill_use():
	pass

## 本次攻击参数钩子(子类重写): 返回本次攻击的发射数与伤害倍率
## 例: 克洛丝技能连射 -> {"count": 2, "multiplier": 1.0}; 暴击 -> {"count": 1, "multiplier": 1.5}
func get_attack_paras() -> Dictionary:
	return {"count": 1, "multiplier": 1.0}

## 返回当前攻击应使用的子弹类型(子类覆盖, 默认使用攻击组件配置的子弹类型)
func get_attack_bullet_type(default_type: BulletRegistry.BulletType) -> BulletRegistry.BulletType:
	return default_type

## 撤退: 返还部署点数并移除干员(与铲子一致, 不触发亡语)
## 撤退/死亡后开始再部署冷却(部署时不冷却, 见 card_slot_battle.card_use_end)
## 撤退直接消失(不播死亡/退场动画, 死亡才播 Die)
func retreat():
	if not is_summon and is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
		var refund: int = int(get_deploy_point_cost() * Global.main_game.game_para.operator_retreat_refund_ratio)
		Global.main_game.operator_manager.add_deploy_point(refund)
	set_selected(false)
	EventBus.push_event("operator_retreat", [self])
	_remove_from_battle()

## 取消部署(两段部署方向选择阶段右键): 静默移除
## 不触发死亡事件/再部署冷却/撤退返还(部署点数未扣, 卡片不受影响)
func cancel_placement():
	set_selected(false)
	_remove_from_battle()

## 从战场移除(撤退/取消部署共用): 从干员管理器登记与植物格释放后释放自身
func _remove_from_battle():
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
		Global.main_game.operator_manager.all_operators.erase(self)
	var cell: Node = plant_cell
	if is_instance_valid(cell) and cell.has_method("one_plant_free"):
		cell.call("one_plant_free", self)
	queue_free()

## 选中/取消选中(弹出/关闭干员菜单)
func set_selected(new_is_selected:bool):
	is_selected = new_is_selected
	signal_operator_selected.emit(is_selected)

## 干员死亡: 播放死亡动画后移除(死亡期间不再攻击, 带变黑→透明死亡特效)
func character_death():
	## 死亡音效(无专属死亡音效的干员用默认)
	SoundManager.play_character_SFX(get_death_sfx())
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
	## 禁用攻击组件, 死亡后不再攻击/索敌, 只播放死亡动画
	var attack_component_node: Node = get_node_or_null("AttackComponent")
	if is_instance_valid(attack_component_node) and attack_component_node.has_method("disable_component"):
		attack_component_node.call("disable_component", ComponentNormBase.E_IsEnableFactor.Death)
	## 播放死亡动画后移除
	anim_operator.play_die()
	## 有 Spine 形象时等待 Die 动画播完(按素材实际时长, 不再硬编码); 无 Spine 时直接移除(占位动画已移除)
	var wait_time: float = 0.1
	var spine: SpineSprite = get_operator_spine()
	if is_instance_valid(spine):
		wait_time = (spine as OperatorSpineSprite).get_current_anim_duration() + 0.1
	if wait_time > 0.4:
		## 死亡特效: 0.4s 后人物开始逐渐变黑, 变黑后逐渐变透明, 动画结束正好透明消失
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(self):
			return
		var dark_time := 0.35
		var fade_time: float = maxf(wait_time - 0.4 - dark_time, 0.05)
		var death_tween := create_tween()
		death_tween.tween_property(self, "modulate", Color(0.04, 0.04, 0.04, 1.0), dark_time)
		death_tween.tween_property(self, "modulate:a", 0.0, fade_time)
		await death_tween.finished
	else:
		await get_tree().create_timer(wait_time).timeout
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

#region 攻击速度(通用变速机制, 所有干员可复用)
## 理论攻击间隔 T0(秒): 场景 AttackComponent.attack_cd 的初始值, 首次应用攻速时缓存
var base_attack_interval := 0.0
## 当前攻击速度 S(默认 100): 攻击间隔 = T0 × 100/S, Spine 动画速度 = S/100
var attack_speed := 100.0

## 设置攻击速度(100 为基准, 与攻击间隔成反比): 统一更新攻击间隔与 Spine 动画播放速度
## 后续所有干员的变速(天赋/技能/减速 buff)都走这里, 不要直接改 attack_component.attack_cd
func set_attack_speed(speed: float) -> void:
	attack_speed = clampf(speed, 10.0, 600.0)
	_apply_attack_speed()

## 应用攻击速度: 攻击间隔 = T0 × 100/S; Spine 动画 timeScale = S/100(攻速加快动画同步加快)
func _apply_attack_speed() -> void:
	if base_attack_interval <= 0.0 and is_instance_valid(attack_component):
		base_attack_interval = attack_component.attack_cd
	if is_instance_valid(attack_component):
		attack_component.attack_cd = base_attack_interval * 100.0 / maxf(attack_speed, 0.0001)
	var spine := get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).set_anim_time_scale(attack_speed / 100.0)
#endregion

#region 阻挡数
## 当前正在阻挡(啃食)本干员的僵尸数量
func get_blocked_zombie_count() -> int:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.zombie_manager):
		return 0
	var count := 0
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death or not zombie.is_attack:
			continue
		if not is_instance_valid(zombie.attack_component) or not is_instance_valid(zombie.attack_component.detect_component):
			continue
		if zombie.attack_component.detect_component.enemy_can_be_attacked == self:
			count += 1
	return count

## 阻挡数是否已满(已满则新僵尸穿过, 不停止啃食)
func is_block_full() -> bool:
	return get_blocked_zombie_count() >= block_count
#endregion
