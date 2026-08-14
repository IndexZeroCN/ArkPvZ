extends AnimComponentPlayer
class_name AnimComponentOperator
## 干员动画组件: 固定动画名 idle/attack/skill/die 接口
## 全部由 Spine 骨骼动画驱动(Spine Runtime 3.8 直接加载原始 3.8.99 数据)
## Spine 动画名: Idle(循环待机)/ Attack(单次攻击, 播完自动接 Idle) / Start(入场) / Die(死亡)
## 注意: 战斗模型无技能骨骼动画, play_skill 为空实现(技能表现由连射子弹承担)

## 获取干员 Spine 形象(owner 为干员本体时)
func _get_operator_spine() -> SpineSprite:
	if owner is Operator000Base:
		return (owner as Operator000Base).get_operator_spine()
	return null

## 播放待机动画(技能激活期间播技能待机动画, 如维什戴尔二/三技能持续中的待机动作)
func play_idle():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		var osp := spine as OperatorSpineSprite
		var idle_anim := osp.get_anim_name("idle")
		if owner is Operator000Base and (owner as Operator000Base).skill_component.is_skill_active:
			var skill_idle: String = (owner as Operator000Base).get_skill_idle_anim()
			if not skill_idle.is_empty():
				idle_anim = skill_idle
		osp.play_spine(idle_anim, true)

## 播放攻击动画(Spine 攻击动画播完自动接 Idle; 技能激活期间播技能攻击/待机动画)
func play_attack():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		var osp := spine as OperatorSpineSprite
		var attack_anim := osp.get_anim_name("attack")
		var idle_anim := osp.get_anim_name("idle")
		## 技能激活期间: 攻击播技能循环动作(如维什戴尔二/三技能), 攻击后回技能待机
		if owner is Operator000Base:
			var skill_attack: String = (owner as Operator000Base).get_skill_attack_anim()
			if not skill_attack.is_empty():
				attack_anim = skill_attack
				var skill_idle: String = (owner as Operator000Base).get_skill_idle_anim()
				if not skill_idle.is_empty():
					idle_anim = skill_idle
		osp.play_spine_sequence(attack_anim, idle_anim)

## 播放技能动画(战斗模型无通用技能动画, 由各干员脚本自行播放专属技能动画)
func play_skill():
	pass

## 播放死亡动画(Spine Die 动画约 1 秒, 由 character_death 等待后移除)
## 死亡动画恢复 1.0 速度(攻速加快的干员死亡时不加速)
func play_die():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).set_anim_time_scale(1.0)
		(spine as OperatorSpineSprite).play_spine((spine as OperatorSpineSprite).get_anim_name("die"), false)

## 播放指定动画(占位动画已移除, 保留接口兼容)
func play_anim(anim_name:StringName):
	if is_instance_valid(animation_player) and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
