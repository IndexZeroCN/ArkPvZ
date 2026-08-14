extends AttackComponentBulletBase
class_name AttackComponentOperator
## 干员攻击组件: 范围检测(DetectComponentOperator)索敌后, 朝目标发射直线子弹(跨行)
##
## 攻击周期(每轮, 由 _run_attack_cycle 执行):
##   1. 索敌: 优先用检测组件当前目标; 目标过期则立即重新索敌一次(不整轮跳过)
##   2. 播攻击动画(Spine)并记录动画时长, 同时以 max(攻击间隔, 动画时长) 武装下一轮计时器
##   3. 等待发射延迟(bullet_spawn_delay, 与动画"松手"时刻对齐)
##   4. 获取攻击参数(连射数/伤害倍率/目标列表, owner.get_attack_paras())
##   5. 依次发射(连射间有 burst_interval 间隔, 二连射/多连发肉眼可辨)
##   6. 广播 signal_operator_shoot(技能点回复)
##
## 设计保证:
## - 索敌后立即攻击(无随机初始延迟): 僵尸进入范围后反应迅速且一致
## - 攻击动画一定播完才开始下一轮(攻击间隔小于动画时长也不会打断动画)
## - 计时器为 one-shot, 每轮开始即武装下一轮; 无目标时快速重试(RETRY_INTERVAL)
## - 连射多发间有固定间隔(修复: 克洛斯技能二连发两箭同帧重叠, 视觉上只有一箭)

## 干员攻击发射信号(每轮攻击发射完一轮后发出, 连接技能组件回复技能点)
signal signal_operator_shoot

## 子弹发射点(相对干员本体的偏移)
@export var bullet_spawn_offset: Vector2 = Vector2(30, -50)

## 箭矢发射延迟(秒): 攻击动画开始后多久发射, 与动画中"松手"时刻对齐
## 校准工具: res://test/operator_debug_tool.tscn, 运行时由 data/operator_calibration.json 覆盖
@export var bullet_spawn_delay: float = 0.55

## 连射发间隔(秒): count > 1 时两发之间间隔(克洛丝二连射/维什戴尔过载四连发依次发射)
@export var burst_interval: float = 0.12

## 无目标时计时器快速重试间隔(秒): 目标随时进入范围都能快速接战, 不干等一整轮攻击间隔
const RETRY_INTERVAL := 0.25

## 攻击周期进行中标记(防止计时器在周期中途到点导致重入)
var _cycle_running := false
## 最近一轮攻击动画时长(秒): 下一轮间隔 = max(攻击间隔, 动画时长), 保证动画播完
var _last_attack_anim_duration := 0.0
## 游戏速度系数(owner_update_speed 更新, 缩放攻击间隔)
var _speed_product := 1.0

## 开始攻击(索敌到目标/组件启用): 立即开始一轮攻击
## 干员为狙击式攻击, 不沿用基类"随机 0~攻击间隔/3 初始延迟"(那是给原版植物错峰用的,
## 会导致僵尸进入范围后反应时快时慢)
func attack_start():
	signal_change_is_attack.emit(true)
	_run_attack_cycle()

## 结束攻击沿用基类(停止计时器 + 广播状态变化, 眨眼等恢复)

## 游戏速度修改(与基类语义一致: 暂停计时器/按剩余时间缩放)
func owner_update_speed(speed_product: float):
	_speed_product = speed_product
	if not bullet_attack_cd_timer.is_stopped():
		if speed_product <= 0.0:
			bullet_attack_cd_timer.paused = true
		else:
			bullet_attack_cd_timer.paused = false
			bullet_attack_cd_timer.start(bullet_attack_cd_timer.time_left / speed_product)

## 攻击间隔计时器到点(one-shot): 执行一轮攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	_run_attack_cycle()

## 下一轮攻击间隔 = max(攻击间隔, 最近攻击动画时长) / 速度系数(攻击动画必须播完)
func _next_interval() -> float:
	return maxf(attack_cd, _last_attack_anim_duration) / maxf(_speed_product, 0.0001)

## 攻击周期有效性(每次 await 恢复后检查): 干员仍有效且组件未禁用
func _is_cycle_valid() -> bool:
	return is_instance_valid(owner) and is_enabling and not owner.is_death

## 攻击中途被取消(目标丢失/组件禁用等): 立即把干员动画切回待机
## (Spine 攻击动画需要播完才会自动接待机, 中途取消若不干预, 干员会一直摆攻击姿势到动画播完)
func _cancel_attack_to_idle() -> void:
	if is_instance_valid(owner) and not owner.is_death and owner is Operator000Base:
		(owner as Operator000Base).anim_operator.play_idle()

## 执行一轮攻击周期
func _run_attack_cycle() -> void:
	if not is_enabling or not is_attack_res:
		return
	if _cycle_running:
		## 周期进行中(如技能释放改攻击间隔重启了计时器): 快速重试, 当前周期结束后自然衔接
		bullet_attack_cd_timer.start(minf(attack_cd, RETRY_INTERVAL))
		return
	_cycle_running = true

	## 1) 索敌: 优先用检测组件当前目标; 目标过期则立即重新索敌一次
	##    (修复: 计时器到点时检测目标恰好过期会整轮跳过, 有敌人在范围却干等一整轮攻击间隔)
	var target_zombie: Zombie000Base = null
	if detect_component is DetectComponentOperator:
		var detect_op := detect_component as DetectComponentOperator
		target_zombie = detect_op.curr_target_zombie
		if not is_instance_valid(target_zombie) or target_zombie.is_death:
			detect_op.judge_have_enemy()
			target_zombie = detect_op.curr_target_zombie
	if not is_instance_valid(target_zombie) or target_zombie.is_death:
		_finish_cycle_no_target()
		return

	## 2) 播攻击动画并记录动画时长; 同时武装下一轮计时器(间隔含动画时长, 动画播完才开始下一轮)
	var anim_duration := 0.0
	if owner is Operator000Base:
		(owner as Operator000Base).anim_operator.play_attack()
		var spine: SpineSprite = (owner as Operator000Base).get_operator_spine()
		if is_instance_valid(spine):
			anim_duration = (spine as OperatorSpineSprite).get_current_anim_duration()
		## 攻击动画开始时回调(干员播"瞄准"等动画开始音效, 先于发射音)
		if owner.has_method("on_attack_anim_start"):
			owner.call("on_attack_anim_start")
	_last_attack_anim_duration = maxf(anim_duration, 0.0)
	bullet_attack_cd_timer.start(_next_interval())

	## 3) 等发射延迟(对齐动画"松手"时刻); 期间干员可能死亡/撤退/被禁用
	if bullet_spawn_delay > 0.0:
		await get_tree().create_timer(bullet_spawn_delay).timeout
		if not _is_cycle_valid():
			_cycle_running = false
			_cancel_attack_to_idle()
			return

	## 目标可能在发射延迟期间被其他干员/召唤物击杀: 重新索敌一次;
	## 若已无目标则直接结束本轮(get_attack_paras 与 signal_operator_shoot 均不触发, 不浪费技能弹药)
	if not is_instance_valid(target_zombie) or target_zombie.is_death:
		if detect_component is DetectComponentOperator:
			var detect_op_retry := detect_component as DetectComponentOperator
			detect_op_retry.judge_have_enemy()
			target_zombie = detect_op_retry.curr_target_zombie
		if not is_instance_valid(target_zombie) or target_zombie.is_death:
			_finish_cycle_no_target()
			return

	## 4) 从干员本体获取本次攻击参数(连射数/伤害倍率/目标列表)
	var attack_paras: Dictionary = {}
	if owner is Operator000Base:
		attack_paras = owner.get_attack_paras()
	var count: int = maxi(1, int(attack_paras.get("count", 1)))
	var multiplier: float = float(attack_paras.get("multiplier", 1.0))
	## 目标列表(多目标/随机目标, 见维什戴尔技能2 饱和复仇); 为空时默认当前索敌目标
	var targets: Array = attack_paras.get("targets", [])
	if targets.is_empty():
		targets = [target_zombie]

	## 5) 依次发射(连射间有间隔)
	var fired_any := false
	for t in targets:
		## 不带类型的循环变量: 目标可能已释放, 带类型遍历会报 "Trying to assign invalid previously freed instance"
		## 先判有效再转型, 避免对已释放实例做类型检查
		if not is_instance_valid(t):
			continue
		var tz: Zombie000Base = t as Zombie000Base
		if tz == null or tz.is_death:
			continue
		for i in count:
			if not _is_cycle_valid():
				if fired_any:
					signal_operator_shoot.emit()
				_cycle_running = false
				_cancel_attack_to_idle()
				return
			if tz.is_death:
				break
			shoot_arrow_at_target(tz, multiplier, attack_paras)
			fired_any = true
			## 下一发前间隔(最后一发不用等)
			if i < count - 1 and burst_interval > 0.0:
				await get_tree().create_timer(burst_interval).timeout

	## 6) 广播一轮攻击完成(攻击回复技能点等): 仅实际发射了子弹才结算,
	##    避免目标全部无效(被队友/召唤物抢先击杀)时仍空耗技能弹药
	if fired_any:
		signal_operator_shoot.emit()
	_cycle_running = false
	## 目标在连射期间死亡(攻击中途取消): 动画立即切回待机, 不等攻击动画自然播完
	if not is_instance_valid(target_zombie) or target_zombie.is_death:
		_cancel_attack_to_idle()

## 本轮无目标: 周期结束; 仍在攻击状态(检测组件尚未上报目标丢失)则快速重试, 否则等 attack_start
## 若中途已播过攻击动画, 立即切回待机
func _finish_cycle_no_target() -> void:
	_cycle_running = false
	_cancel_attack_to_idle()
	if is_enabling and is_attack_res:
		bullet_attack_cd_timer.start(RETRY_INTERVAL)

## 朝目标僵尸发射一发子弹(直线, 跨行)
## attack_paras 可携带子弹定制参数(见维什戴尔炮弹的 splash_paras: 溅射半径/余震倍率/天赋爆炸)
func shoot_arrow_at_target(target_zombie: Zombie000Base, multiplier: float, attack_paras: Dictionary = {}):
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

	var used_bullet_type: BulletRegistry.BulletType = attack_bullet_type
	if owner is Operator000Base and owner.has_method("get_attack_bullet_type"):
		used_bullet_type = owner.get_attack_bullet_type(attack_bullet_type)
	var bullet_scene: PackedScene = Global.bullet_registry.get_bullet_scenes(used_bullet_type)
	if bullet_scene == null:
		push_error("未找到子弹类型场景: " + str(used_bullet_type) + "，回退到默认子弹")
		bullet_scene = Global.bullet_registry.get_bullet_scenes(attack_bullet_type)
	var bullet: Bullet000Base = bullet_scene.instantiate()
	var bullet_paras: Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: -1,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(spawn_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: dir,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.Enemy: target_zombie,
		Bullet000NormBase.E_InitParasAttr.EnemyGloPos: target_zombie.hurt_box_component.global_position,
	}
	bullet.init_bullet(bullet_paras)
	## 伤害倍率(暴击等)
	if bullet is Bullet000NormBase and multiplier != 1.0:
		(bullet as Bullet000NormBase).attack_value = maxi(1, int(round((bullet as Bullet000NormBase).attack_value * multiplier)))
	## 子弹定制参数(溅射/余震/天赋爆炸, 见维什戴尔炮弹): 有该方法才传, 兼容普通箭矢
	var splash_paras: Dictionary = attack_paras.get("splash_paras", {})
	if not splash_paras.is_empty() and bullet.has_method("init_splash_paras"):
		bullet.init_splash_paras(splash_paras)
	bullets.add_child(bullet)
	## 应用子弹视觉校准(拖尾长度/颜色/样式, 子弹大小; JSON 无该干员则跳过)
	if owner is Operator000Base:
		OperatorCalibration.apply_to_bullet(bullet, str(owner.get("operator_id")))
	## 发射音效
	play_throw_sfx()
