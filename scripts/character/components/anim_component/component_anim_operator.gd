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

## 播放待机动画
func play_idle():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).play_spine("Idle", true)

## 播放攻击动画(Spine 攻击动画播完自动接 Idle)
func play_attack():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).play_spine_sequence("Attack", "Idle")

## 播放技能动画(战斗模型无技能动画)
func play_skill():
	pass

## 播放死亡动画(Spine Die 动画约 1 秒, 由 character_death 等待后移除)
func play_die():
	var spine := _get_operator_spine()
	if is_instance_valid(spine):
		(spine as OperatorSpineSprite).play_spine("Die", false)

## 播放指定动画(占位动画已移除, 保留接口兼容)
func play_anim(anim_name:StringName):
	if is_instance_valid(animation_player) and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
