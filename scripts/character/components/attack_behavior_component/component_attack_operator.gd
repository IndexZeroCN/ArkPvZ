extends AttackComponentBulletBase
class_name AttackComponentOperator
## 干员攻击组件: 范围检测(DetectComponentOperator)到目标后, 朝目标发射直线子弹(跨行)
## 支持: 连射次数/伤害倍率(通过 owner.get_attack_paras()), 发射信号(技能点回复)

## 干员攻击发射信号(每轮攻击发射完后发出, 连接技能组件回复技能点)
signal signal_operator_shoot

## 子弹发射点(相对干员本体的偏移)
@export var bullet_spawn_offset: Vector2 = Vector2(30, -50)

## 箭矢发射延迟(秒): 攻击动画开始后多久发射, 与动画中"松手"时刻对齐
## 校准工具: res://test/kroos_attack_calibrate.tscn
@export var bullet_spawn_delay: float = 0.55

## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	var target_zombie: Zombie000Base = null
	if detect_component is DetectComponentOperator:
		target_zombie = (detect_component as DetectComponentOperator).curr_target_zombie
	## 目标已消失则本次不攻击
	if not is_instance_valid(target_zombie):
		return
	## 先播放攻击动画(Spine Attack), 动画与射击的时序分离
	if owner is Operator000Base:
		(owner as Operator000Base).anim_operator.play_attack()
	## 延迟到动画中"松手"时刻再发射箭矢(对齐动画时序, 可在校准场景调整)
	if bullet_spawn_delay > 0.0:
		await get_tree().create_timer(bullet_spawn_delay).timeout
		## 等待期间干员可能已死亡/撤退, 目标可能已消失
		if not is_instance_valid(owner) or not is_instance_valid(target_zombie):
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

## 朝目标僵尸发射一发子弹(直线, 跨行)
func shoot_arrow_at_target(target_zombie: Zombie000Base, multiplier: float):
	## 干员转身/朝左(OperatorSprite.scale.x 为负)时, 发射点 x 镜像(与形象一起转)
	var offset: Vector2 = bullet_spawn_offset
	if owner is Operator000Base:
		var operator_sprite: Node2D = (owner as Operator000Base).get_operator_sprite()
		if is_instance_valid(operator_sprite):
			offset.x = abs(offset.x) if operator_sprite.scale.x >= 0.0 else -abs(offset.x)
	var spawn_pos: Vector2 = owner.global_position + offset
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
