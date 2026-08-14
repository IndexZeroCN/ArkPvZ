extends Operator000Base
class_name Operator003Myrtle
## 桃金娘 - 先锋·执旗手 (★4)
## 特性: 技能发动期间阻挡数变为0(见 is_block_full 覆盖, 技能期间不阻挡新僵尸)
## 天赋 浮光跃金(满潜/潜能5): 在场时所有【先锋】干员每秒回复28点生命
##   (当前仅桃金娘为先锋, 简化为自身回血; 若后续新增先锋需改为遍历所有先锋)
## 技能(选卡时选择, operator_skill_id, 见 CardBase.operator_skill_id):
##   1 支援号令·β型(自动回复·手动触发): 停止攻击, 8秒内回复总共14点部署费用
##   2 治愈之翼(自动回复·手动触发): 停止攻击, 16秒内回复总共16点部署费用,
##     并每秒给周围九宫格(3×3)范围内的友方干员/植物(含自身)回复相当于桃金娘攻击力50%的生命

## 技能枚举(与选卡技能选择面板一致)
enum E_Skill {Skill1 = 1, Skill2 = 2}

## 两个技能图标(干员菜单技能按钮/技能选择面板使用)
const SKILL_ICONS: Dictionary = {
	E_Skill.Skill1: preload("res://assets/image/operator/myrtle/skill_icon_1.png"),
	E_Skill.Skill2: preload("res://assets/image/operator/myrtle/skill_icon_2.png"),
}

## 当前技能(选卡时选择, 默认一技能; 创建后由 hm_character 从卡片写入)
@export var operator_skill_id: int = 1

## 基础攻击力(与子弹场景 attack_value 一致: 精英2满级520)
const BASE_ATTACK := 520

## 天赋 浮光跃金: 满潜 28 点/秒(25 + 潜能5 +3)
const TALENT_HEAL_PER_SEC := 28.0

## 技能1 支援号令·β型
const SKILL1_DP_TOTAL := 14
const SKILL1_DURATION := 8.0
## 技能2 治愈之翼
const SKILL2_DP_TOTAL := 16
const SKILL2_DURATION := 16.0
const SKILL2_HEAL_RATIO := 0.5

## 技能期间临时状态
var _skill_operator_active := false
var _skill_dp_per_sec := 0.0
var _skill_dp_acc := 0.0
var _skill_heal_timer := 0.0
var _skill_heal_amount := 0
## 天赋回血累计(浮点, 满1点结算一次)
var _talent_heal_acc := 0.0

## 干员技能图标(干员菜单技能按钮, 按所选技能显示)
func get_skill_icon() -> Texture2D:
	return SKILL_ICONS.get(operator_skill_id, SKILL_ICONS[E_Skill.Skill1])

## 攻击范围形状(执旗手): 自身格 + 前方一格 (OX, O=自身, X=前方)
## 二技能「治愈之翼」持续期间: 攻击范围预览/检测范围变为九宫格(3×3 治疗范围), 技能结束后恢复
func get_attack_range_shape() -> Array[Vector2i]:
	if _skill_operator_active and operator_skill_id == E_Skill.Skill2:
		var cells: Array[Vector2i] = []
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				cells.append(Vector2i(dr, dc))
		return cells
	return [Vector2i(0, 0), Vector2i(0, 1)]

## 特性: 技能发动期间阻挡数变为0
## 技能期间禁用受击盒, 僵尸检测不到本干员 → 已在啃食的僵尸停止啃食继续移动, 新僵尸直接穿过
func _set_blocking(enable: bool) -> void:
	if not is_instance_valid(hurt_box_component):
		return
	if enable:
		hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	else:
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

## 初始化正常出战角色
func ready_norm():
	super()
	_apply_skill_config()

## 创建后由 hm_character 写入所选技能并重配技能组件(ready_norm 前 operator_skill_id 尚未赋值)
func apply_operator_skill(skill_id: int):
	operator_skill_id = skill_id
	_apply_skill_config()

## 按 operator_skill_id 配置技能组件参数(专三)
func _apply_skill_config():
	match operator_skill_id:
		E_Skill.Skill1:
			skill_component.max_sp = 22
			skill_component.initial_sp = 13
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
			skill_component.sp_regen_per_sec = 1.0
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = true
		E_Skill.Skill2:
			skill_component.max_sp = 24
			skill_component.initial_sp = 10
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
			skill_component.sp_regen_per_sec = 1.0
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = true
	## 重置技能点与技能条(组件 _ready 时使用的是默认配置)
	skill_component.curr_sp = mini(skill_component.initial_sp, skill_component.max_sp)
	skill_component.is_skill_ready = skill_component.curr_sp >= skill_component.max_sp
	skill_component.is_skill_active = false
	skill_component.update_skill_bar()

## 技能释放(经基类 signal_skill_use 统一触发)
func _on_skill_use():
	## 连接技能结束回调(提前关闭/计时结束)
	if not skill_component.signal_skill_ended.is_connected(_on_skill_ended):
		skill_component.signal_skill_ended.connect(_on_skill_ended)
	_skill_operator_active = true
	_skill_dp_acc = 0.0
	_skill_heal_timer = 0.0
	if operator_skill_id == E_Skill.Skill1:
		_skill_dp_per_sec = float(SKILL1_DP_TOTAL) / SKILL1_DURATION
		_skill_heal_amount = 0
		skill_component.start_sustain(SKILL1_DURATION)
		_play_skill_spine("Skill_Begin", "Skill_Loop")
	else:
		_skill_dp_per_sec = float(SKILL2_DP_TOTAL) / SKILL2_DURATION
		_skill_heal_amount = int(round(BASE_ATTACK * SKILL2_HEAL_RATIO))
		skill_component.start_sustain(SKILL2_DURATION)
		_play_skill_spine("Skill_Begin", "Skill_Loop")
	## 技能期间停止攻击(执旗手特性之一: 技能期间不攻击)
	_stop_attack(true)
	## 特性: 技能期间阻挡数变为0(禁用受击盒, 僵尸穿过)
	_set_blocking(false)

## 技能结束(提前关闭/计时结束)
func _on_skill_ended():
	if not _skill_operator_active:
		return
	_skill_operator_active = false
	_skill_dp_per_sec = 0.0
	_skill_dp_acc = 0.0
	_skill_heal_timer = 0.0
	_skill_heal_amount = 0
	_stop_attack(false)
	## 恢复阻挡(启用受击盒)
	_set_blocking(true)
	## 技能结束动画 → 待机
	_play_skill_spine("Skill_End")

## 停止/恢复攻击(技能期间停止攻击)
func _stop_attack(stop: bool):
	if not is_instance_valid(attack_component):
		return
	if stop:
		attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	else:
		attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)

## 播放技能 Spine 动画: 开启动画(一次性) → 循环动画; 不传循环动画时播完自动接待机
func _play_skill_spine(begin_anim: String, loop_anim: String = ""):
	var spine: OperatorSpineSprite = get_operator_spine()
	if not is_instance_valid(spine):
		return
	if loop_anim.is_empty():
		spine.play_spine_sequence(begin_anim, spine.get_anim_name("idle"))
	else:
		spine.play_spine_sequence(begin_anim, loop_anim)

func _process(delta: float) -> void:
	## 天赋 浮光跃金: 每秒回血(自身)
	if not is_death and is_instance_valid(hp_component):
		_talent_heal_acc += TALENT_HEAL_PER_SEC * delta
		var heal := int(_talent_heal_acc)
		if heal > 0:
			_talent_heal_acc -= heal
			hp_component.curr_hp = mini(hp_component.curr_hp + heal, hp_component.max_hp)

	## 技能期间: 部署点数回复 + (技能2)治疗
	if _skill_operator_active:
		_skill_dp_acc += _skill_dp_per_sec * delta
		while _skill_dp_acc >= 1.0:
			_skill_dp_acc -= 1.0
			if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.operator_manager):
				Global.main_game.operator_manager.add_deploy_point(1)
		if _skill_heal_amount > 0:
			_skill_heal_timer += delta
			if _skill_heal_timer >= 1.0:
				_skill_heal_timer -= 1.0
				_heal_allies_in_range(_skill_heal_amount)

## 二技能「治愈之翼」: 每秒给九宫格范围内的友方干员/植物回血(含自身, 自身格在九宫格中心)
## 收割者等"无法被友方治疗"的干员跳过(如羽毛笔)
func _heal_allies_in_range(heal_amount: int) -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	var rows: Array = Global.main_game.plant_cell_manager.all_plant_cells
	var base: Vector2i = plant_cell.row_col
	for cell_offset: Vector2i in get_attack_range_shape():
		var row: int = base.x + cell_offset.x
		var col: int = base.y + cell_offset.y
		if row < 0 or row >= rows.size():
			continue
		var row_cells: Array = rows[row]
		if col < 0 or col >= row_cells.size():
			continue
		var cell: PlantCell = row_cells[col]
		if not is_instance_valid(cell):
			continue
		for key in cell.plant_in_cell:
			var plant: Plant000Base = cell.plant_in_cell[key]
			if not is_instance_valid(plant) or plant.is_death:
				continue
			if not is_instance_valid(plant.hp_component):
				continue
			if plant.has_method("can_be_healed_by_ally") and not plant.can_be_healed_by_ally():
				continue
			var hp: HpComponent = plant.hp_component
			if hp.curr_hp >= hp.max_hp:
				continue
			hp.curr_hp = mini(hp.curr_hp + heal_amount, hp.max_hp)
