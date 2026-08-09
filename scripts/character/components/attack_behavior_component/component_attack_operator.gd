extends AttackComponentBulletBase
class_name AttackComponentOperator
## 干员攻击组件: 范围检测(DetectComponentOperator)到目标后, 朝目标发射直线子弹(跨行)
## 支持: 连射次数/伤害倍率(通过 owner.get_attack_paras()), 发射信号(技能点回复)

## 干员攻击发射信号(每轮攻击发射完后发出, 连接技能组件回复技能点)
signal signal_operator_shoot

## 子弹发射点(相对干员本体的偏移)
@export var bullet_spawn_offset: Vector2 = Vector2(30, -50)

## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	var target_zombie: Zombie000Base = null
	if detect_component is DetectComponentOperator:
		target_zombie = (detect_component as DetectComponentOperator).curr_target_zombie
	## 目标已消失则本次不攻击
	if not is_instance_valid(target_zombie):
		return

	## 从干员本体获取本次攻击参数(连射数/伤害倍率)
	var attack_paras: Dictionary = {}
	if owner is Operator000Base:
		attack_paras = owner.get_attack_paras()
	var count: int = attack_paras.get("count", 1)
	var multiplier: float = attack_paras.get("multiplier", 1.0)

	for i in count:
		shoot_arrow_at_target(target_zombie, multiplier)
	## 发射完一轮子弹, 广播(连接技能组件回复技能点)
	signal_operator_shoot.emit()
	## 播放攻击动画
	if owner is Operator000Base:
		(owner as Operator000Base).anim_operator.play_attack()

## 朝目标僵尸发射一发子弹(直线, 跨行)
func shoot_arrow_at_target(target_zombie: Zombie000Base, multiplier: float):
	var spawn_pos: Vector2 = owner.global_position + bullet_spawn_offset
	var dir: Vector2 = (target_zombie.hurt_box_component.global_position - spawn_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
	var bullet_paras: Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: -1,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(spawn_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: dir,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: can_attack_zombie_status,
	}
	bullet.init_bullet(bullet_paras)
	## 伤害倍率(暴击等)
	if bullet is Bullet000NormBase and multiplier != 1.0:
		(bullet as Bullet000NormBase).attack_value = maxi(1, int(round((bullet as Bullet000NormBase).attack_value * multiplier)))
	bullets.add_child(bullet)
	## 发射音效
	play_throw_sfx()
