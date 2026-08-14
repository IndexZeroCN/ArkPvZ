extends Summon000Base
class_name Summon002WisdelShadow
## 魂灵之影(维什戴尔召唤物, Shadow of Revenant)
## 特性: 可攻击维什戴尔攻击范围内的敌人(范围/方向继承主人); 不进行普通攻击(技能即攻击)
## 数值(精英2满级): HP3500/攻击777/防御650/法抗50/部署费用0/再部署5s/攻击间隔1.0s
## 技能(自动回复·自动触发, SP5): 对一名在维什戴尔攻击范围内的敌人造成100%攻击力的法术伤害,
##   对其造成1秒停顿并附着残影, 之后获得0-2点技力
## 初始技力: 由维什戴尔第二天赋召唤为0sp; 由三技能召唤的两个分别3sp(优先召唤)与0sp

## 基础攻击力(精英2满级, 与 wiki 一致)
const BASE_ATTACK := 777
## 技能法术伤害倍率(100%)
const SKILL_DAMAGE_MULT := 1.0
## 停顿时长(秒)
const SKILL_STUN_TIME := 1.0
## 技能后获得技力范围(0-2点)
const SP_GAIN_MIN := 0
const SP_GAIN_MAX := 2

## 检测组件(目标选取, 范围=维什戴尔攻击范围; 挂根节点下, 无发射类 AttackComponent)
@onready var detect_component: DetectComponentOperator = $DetectComponent

## 魂灵之影技能图标(用户提供, 干员菜单技能按钮显示; 技能为自动触发, 按钮禁用态也显示该图标)
func get_skill_icon() -> Texture2D:
	return preload("res://assets/image/operator/wward/skill_icon.png")

func _ready() -> void:
	super()

## 初始化正常出战角色
func ready_norm():
	## 攻击范围/方向继承主人干员(必须在检测组件工作前设置)
	if is_instance_valid(owner_operator):
		attack_direction = owner_operator.attack_direction
	super()
	## 技能组件配置(自动回复·自动触发, SP5, 时间回复1点/秒)
	skill_component.max_sp = 5
	skill_component.initial_sp = 0
	skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
	skill_component.sp_regen_per_sec = 1.0
	skill_component.is_auto_trigger = true
	## 技能满后攒着: 范围内无敌人时自动触发检查不通过(SP 不消耗), 等有目标再释放
	skill_component.auto_trigger_check = func() -> bool:
		return is_instance_valid(_find_target())
	skill_component.curr_sp = 0
	skill_component.is_skill_ready = false
	skill_component.update_skill_bar()

## 攻击范围形状 = 主人维什戴尔的攻击范围
func get_attack_range_shape() -> Array[Vector2i]:
	if is_instance_valid(owner_operator):
		return owner_operator.get_attack_range_shape()
	return DetectComponentOperator.ATTACK_RANGE_SHAPE

## 攻击范围格子中心 = 主人维什戴尔的(位置以维什戴尔为基准, 用户确认)
## 修复: 之前以魂灵自己为基准导致菜单范围预览显示异常(1x1)
func get_attack_range_cells() -> Array[Vector2]:
	if is_instance_valid(owner_operator):
		return owner_operator.get_attack_range_cells()
	return super()

## 召唤物不转身: 保持部署时朝向, 不切换正背面/左右翻转(召唤物一般不转身)
func update_visual_for_target(_target: Zombie000Base):
	pass

## 撤退: 播放专属撤退音效后移除(魂灵之影可撤退, 对应 ShadowRetreat)
func retreat():
	SoundManager.play_character_SFX(&"ShadowRetreat")
	## 从维什戴尔的魂灵列表移除(避免残留引用影响后续召唤数量上限判断, 与死亡回调一致)
	if is_instance_valid(owner_operator) and owner_operator.has_method("_on_shadow_death"):
		owner_operator.call("_on_shadow_death", self)
	super()

## 技能触发(自动): 向范围内一名敌人发射攻击射线, 命中帧结算法术伤害+停顿+附着残影
func _on_skill_use():
	if not is_instance_valid(owner_operator) or not is_instance_valid(Global.main_game):
		return
	var target: Zombie000Base = _find_target()
	if not is_instance_valid(target) or target.is_death:
		return
	## 之后获得0-2点技力(加速下次触发)
	skill_component.add_sp(randi_range(SP_GAIN_MIN, SP_GAIN_MAX))
	## 技能表现: 攻击音效(ShadowAttack, 魂灵无普通攻击, 技能即攻击, 基类自动触发不播技能发动音) + Spine 攻击动画 + 攻击射线特效
	SoundManager.play_character_SFX(&"ShadowAttack")
	_play_attack_visual()
	_fire_beam(target)

## 发射攻击射线: 从魂灵之影到目标的红色射线, 命中帧回调结算伤害(仿方舟游戏内过程)
func _fire_beam(target: Zombie000Base):
	var beam_fx: WisdelShadowBeam = SceneRegistry.WISDEL_SHADOW_BEAM.instantiate()
	Global.main_game.add_child(beam_fx)
	var from_pos: Vector2 = get_operator_sprite().global_position
	var to_pos: Vector2 = target.hurt_box_component.global_position
	beam_fx.fire(from_pos, to_pos, target.lane * 50 + 40)
	beam_fx.signal_beam_hit.connect(_on_beam_hit.bind(target), CONNECT_ONE_SHOT)

## 射线命中帧: 结算100%攻击力法术伤害 + 1秒停顿 + 附着残影
## 参数不带类型: 目标可能在射线飞行期(0.09s)内被其他干员/召唤物击杀并释放,
## 带类型 bind 在调用时对已释放实例报 "Cannot convert argument 1 from Object to Object"
func _on_beam_hit(target):
	if not is_instance_valid(target) or target.is_death:
		return
	## 命中音效(敌人被攻击时发出, 用户选定)
	SoundManager.play_character_SFX(&"ShadowHit")
	## 造成100%攻击力法术伤害(PVZ 无法抗, 直接伤害)
	var damage: int = maxi(1, int(round(BASE_ATTACK * SKILL_DAMAGE_MULT)))
	target.be_attacked_bullet(damage, BulletRegistry.AttackMode.Norm, true, true)
	## 1秒停顿(静默, 不显示黄油)
	if not target.is_death:
		target.be_butter(SKILL_STUN_TIME, false)
	## 附着残影(供维什戴尔的余震触发残影爆炸)
	target.set_meta("wisdel_residue", true)

## 找目标: 优先攻击未携带残影的敌人(PRTS 备注), 否则范围内最近的敌人
## 范围 = 维什戴尔的攻击范围(位置以维什戴尔为基准, 用户确认)
func _find_target() -> Zombie000Base:
	if not is_instance_valid(owner_operator):
		return null
	var candidates: Array = owner_operator.get_targets_in_range()
	if candidates.is_empty():
		return null
	for z: Zombie000Base in candidates:
		if not z.has_meta("wisdel_residue"):
			return z
	return candidates[0] as Zombie000Base

## 技能表现: 播放 Spine 攻击动画(Attack→待机, 魂灵之影素材 wward 有 Attack); 无 Spine(占位)时脉冲缩放
func _play_attack_visual():
	var spine: OperatorSpineSprite = get_operator_spine()
	if is_instance_valid(spine):
		spine.play_spine_sequence(spine.get_anim_name("attack"), spine.get_anim_name("idle"))
		return
	var sprite: Node2D = get_operator_sprite()
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
