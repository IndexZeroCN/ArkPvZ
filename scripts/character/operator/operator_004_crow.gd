extends Operator000Base
class_name Operator004Crow
## 羽毛笔 - 近卫·收割者 (★5)
## 特性 无法被友方角色治疗 + 攻击造成群体伤害(一次挥砍命中攻击范围内所有敌人) + 每命中一个敌人回复 50 生命(最大生效数=阻挡数)
## 天赋 渐入佳境(精英2): 每击杀一个敌人 +3 攻速, 最多叠加 12 次
## 技能(选卡时选择, operator_skill_id, 见 CardBase.operator_skill_id):
##   1 高速切割(攻击回复·自动触发): 下次攻击攻击力提升至 165%, 并连续攻击两次
##   2 收割(自动回复·手动触发·持续): 攻击力 +70%, 攻击间隔 -50%, 对生命值低于 50% 的敌人额外 +50% 伤害
## 部署后不转身: 固定部署方向, 攻击时不切换素材/镜像(收割者特性)

## 技能枚举(与选卡技能选择面板一致)
enum E_Skill {Skill1 = 1, Skill2 = 2}

## 两个技能图标(干员菜单技能按钮/技能选择面板使用)
const SKILL_ICONS: Dictionary = {
	E_Skill.Skill1: preload("res://assets/image/operator/crow/skill_icon_1.png"),
	E_Skill.Skill2: preload("res://assets/image/operator/crow/skill_icon_2.png"),
}

## 当前技能(选卡时选择, 默认一技能; 创建后由 hm_character 从卡片写入)
@export var operator_skill_id: int = 1

## 特性: 每命中一个敌人回复自身生命
const HEAL_PER_HIT := 50
## 天赋 渐入佳境: 每击杀 +3 攻速, 最多 12 层
const TALENT_ASPD_PER_STACK := 3.0
const TALENT_MAX_STACKS := 12
## 技能1 高速切割(专三): SP 0/2, 下次攻击 165% 并连续两次
const SKILL1_SP := 2
const SKILL1_MULT := 1.65
const SKILL1_COUNT := 2
## 技能2 收割(专三): 初始 30/消耗 40, 持续 25s
const SKILL2_INITIAL_SP := 30
const SKILL2_MAX_SP := 40
const SKILL2_DURATION := 25.0
const SKILL2_ATK_MULT := 1.7
const SKILL2_ATK_INTERVAL := 0.5
const SKILL2_LOW_HP_BONUS := 0.5
const LOW_HP_THRESHOLD := 0.5

## 技能1 待触发(下次攻击二连击)
var _skill1_pending := false
## 技能2 激活中
var _skill2_active := false
## 天赋 渐入佳境 当前层数(0~12)
var _talent_stacks := 0

## 干员技能图标(干员菜单技能按钮, 按所选技能显示)
func get_skill_icon() -> Texture2D:
	return SKILL_ICONS.get(operator_skill_id, SKILL_ICONS[E_Skill.Skill1])

## 攻击范围形状(收割者): 自身格 + 前方一列 3 格
## 图示(朝右): -X / OX / -X, O=自身(也算攻击范围), X=攻击范围, -=空
func get_attack_range_shape() -> Array[Vector2i]:
	return [Vector2i(-1, 1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]

## 特性: 无法被友方角色治疗(桃金娘二技能等友方治疗跳过本干员)
func can_be_healed_by_ally() -> bool:
	return false

## 收割者部署后不转身: 固定部署方向, 攻击时不切素材/不镜像(基类按目标转身, 此处覆盖为空)
func update_visual_for_target(_target: Zombie000Base) -> void:
	pass

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
			skill_component.max_sp = SKILL1_SP
			skill_component.initial_sp = 0
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Attack
			skill_component.sp_gain_per_attack = 1
			## 攻击回复自动技能: 就绪后不立即消耗SP(绿条保持满), 下次攻击开始时才消耗
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = false
		E_Skill.Skill2:
			skill_component.max_sp = SKILL2_MAX_SP
			skill_component.initial_sp = SKILL2_INITIAL_SP
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
			skill_component.sp_regen_per_sec = 1.0
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = true
	## 重置技能点与技能条(组件 _ready 时使用的是默认配置)
	skill_component.curr_sp = mini(skill_component.initial_sp, skill_component.max_sp)
	skill_component.is_skill_ready = skill_component.curr_sp >= skill_component.max_sp
	skill_component.is_skill_active = false
	skill_component.update_skill_bar()
	## 按当前天赋/技能重算攻击速度
	_update_attack_speed()

## 技能释放(经基类 signal_skill_use 统一触发; 仅技能2 走此路径)
func _on_skill_use():
	if operator_skill_id != E_Skill.Skill2:
		return
	if not skill_component.signal_skill_ended.is_connected(_on_skill_ended):
		skill_component.signal_skill_ended.connect(_on_skill_ended)
	_skill2_active = true
	_update_attack_speed()
	skill_component.start_sustain(SKILL2_DURATION)

## 技能2 结束(提前关闭/计时结束)
func _on_skill_ended():
	if not _skill2_active:
		return
	_skill2_active = false
	_update_attack_speed()

## 使用技能(手动菜单): 技能1仅"武装"(绿条保持满), 下次攻击开始时消耗; 技能2走基类手动触发
func use_skill() -> bool:
	if operator_skill_id == E_Skill.Skill1:
		if not skill_component.is_skill_ready:
			return false
		_skill1_pending = true
		return true
	return super()

## 攻击动画开始回调: 技能1就绪则本次攻击消耗技能, 技能条变橙色并在动画时长内耗尽
func on_attack_anim_start():
	if operator_skill_id == E_Skill.Skill1 and try_start_skill_burst():
		_skill1_pending = true

## 本次攻击参数钩子:
## 群攻由一发近战子弹触发(攻击组件用最近目标), 命中后回调 on_crow_slash_hit 一次性结算范围内所有敌人
## 技能1 二连击: count=1(一次挥砍), hit_times=2(对范围内每个敌人一次性施加两次攻击)
func get_attack_paras() -> Dictionary:
	var count := 1
	var multiplier := 1.0
	var low_hp_bonus := 0.0
	var hit_times := 1

	if _skill1_pending:
		_skill1_pending = false
		multiplier = SKILL1_MULT
		hit_times = SKILL1_COUNT
	elif _skill2_active:
		multiplier = SKILL2_ATK_MULT
		low_hp_bonus = SKILL2_LOW_HP_BONUS

	return {
		"count": count,
		"multiplier": multiplier,
		"splash_paras": {
			"owner": self,
			"low_hp_bonus": low_hp_bonus,
			"low_hp_threshold": LOW_HP_THRESHOLD,
			"hit_times": hit_times,
		},
	}

## 近战挥砍命中(子弹回调): 一次挥砍对攻击范围内所有敌人结算(群攻), 并回血 + 击杀上报
## damage 已含攻击力倍率(攻击组件发射前乘过), 低血增伤在此按每个目标当前血量判定
## hit_times: 技能1 二连击=2, 同一次挥砍对每个敌人一次性施加两次攻击(近卫多连击)
func on_crow_slash_hit(damage: int, low_hp_bonus: float, low_hp_threshold: float, hit_times: int = 1):
	if is_death:
		return
	for _hit in range(maxi(1, hit_times)):
		var targets: Array[Zombie000Base] = get_targets_in_range()
		var hit_count := 0
		for target: Zombie000Base in targets:
			if not is_instance_valid(target) or target.is_death:
				continue
			var dmg := damage
			if low_hp_bonus > 0.0 and is_instance_valid(target.hp_component):
				var ratio := float(target.hp_component.curr_hp) / float(maxi(target.hp_component.max_hp, 1))
				if ratio < low_hp_threshold:
					dmg = maxi(1, int(round(dmg * (1.0 + low_hp_bonus))))
			target.be_attacked_bullet(dmg, BulletRegistry.AttackMode.Norm, true, true)
			hit_count += 1
			if target.is_death:
				on_crow_kill()
		## 特性回血: 每命中一个敌人回复 50 生命, 最大生效数 = 阻挡数(每次连击独立结算)
		_heal_on_attack(hit_count)

## 特性回血: 命中敌人数量上限=阻挡数
func _heal_on_attack(hit_count: int):
	if hit_count <= 0 or is_death:
		return
	if not is_instance_valid(hp_component):
		return
	var heal := mini(hit_count, block_count) * HEAL_PER_HIT
	if heal > 0:
		hp_component.curr_hp = mini(hp_component.curr_hp + heal, hp_component.max_hp)

## 天赋 渐入佳境: 子弹上报击杀时叠加攻速层数并重算攻击速度
func on_crow_kill():
	if _talent_stacks >= TALENT_MAX_STACKS:
		return
	_talent_stacks += 1
	_update_attack_speed()

## 重算攻击速度: S = (100 + 天赋攻速) ÷ 技能2间隔系数, 走基类通用 set_attack_speed
func _update_attack_speed():
	var speed := 100.0 + _talent_stacks * TALENT_ASPD_PER_STACK
	if _skill2_active:
		speed /= SKILL2_ATK_INTERVAL
	set_attack_speed(speed)
