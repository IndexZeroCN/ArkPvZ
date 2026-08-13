extends BulletLinear000Base
class_name Bullet102WisdelShell
## 维什戴尔炮弹(投掷手): 直线飞行, 命中主目标造成直击伤害并溅射
## 投掷手特性: 攻击对小范围地面敌人造成两次物理伤害(第二次为余震, 伤害=攻击力一半)
## 天赋1 好礼: 主目标伤害提升至125%并附残影; 带残影目标被余震影响时概率爆炸(175%攻击+眩晕)
## 技能可定制(init_splash_paras): 溅射半径/余震倍率/爆炸概率/爆炸伤害/主目标倍率/对空

## 溅射检测节点(半径由 init_splash_paras 动态设置)
@onready var area_2d_spatter: Area2D = $SpatterArea/Area2DSpatter
@onready var spatter_shape: CollisionShape2D = $SpatterArea/Area2DSpatter/CollisionShape2D

## 溅射半径(px): 1 格 ≈ 76px(普通攻击 1.1 格 ≈ 84px; 一技能略微扩大; 三技能 2.5 格 = 190px)
var splash_radius_px := 84.0
## 余震伤害倍率(投掷手特性: 第二次伤害=攻击力一半)
var after_shock_mult := 0.5
## 主目标伤害倍率(天赋1 好礼: 提升至125%)
var main_target_mult := 1.25
## 天赋爆炸概率(普通15%, 三技能期间100%)
var talent_explode_chance := 0.15
## 天赋爆炸伤害(攻击力175%, 由干员计算传入)
var talent_explode_damage := 0
## 天赋爆炸眩晕时长(秒)
var talent_explode_stun := 1.0
## 本次攻击命中目标眩晕时长(秒, 技能1定点清算: 1.5秒; 普通0)
var stun_time := 0.0
## 是否为三技能(爆裂黎明)期间攻击: 命中敌人时播放樱桃炸弹爆炸特效
var is_skill3 := false

func _ready() -> void:
	ignore_slope = true
	super()
	_apply_splash_shape()
	## 炮弹发射音效(用户选定 wisdel_attack_shot.wav)
	SoundManager.play_character_SFX(&"WisdelAttackShot")

## 发射前由干员传入溅射/天赋参数(维什戴尔 get_attack_paras 的 splash_paras)
func init_splash_paras(paras: Dictionary):
	splash_radius_px = paras.get("splash_radius_px", splash_radius_px)
	after_shock_mult = paras.get("after_shock_mult", after_shock_mult)
	main_target_mult = paras.get("main_target_mult", main_target_mult)
	talent_explode_chance = paras.get("talent_explode_chance", talent_explode_chance)
	talent_explode_damage = paras.get("talent_explode_damage", talent_explode_damage)
	talent_explode_stun = paras.get("talent_explode_stun", talent_explode_stun)
	stun_time = paras.get("stun_time", stun_time)
	is_skill3 = paras.get("is_skill3", is_skill3)
	## 发射后(add_child 前)调用时节点未就绪, _ready 中会再次应用
	_apply_splash_shape()

## 应用溅射形状半径(init_splash_paras 在 add_child 前调用, 需在 _ready 后再应用)
func _apply_splash_shape():
	if is_instance_valid(spatter_shape) and spatter_shape.shape is CircleShape2D:
		(spatter_shape.shape as CircleShape2D).radius = splash_radius_px

## 攻击一次: 主目标直击(×天赋倍率+附残影) + 溅射余震 + 残影爆炸
func attack_once(enemy: Character000Base):
	curr_attack_num += 1
	if max_attack_num != -1 and curr_attack_num > max_attack_num:
		return
	## 主目标直击(含天赋1 主目标倍率) + 附残影(天赋1)
	if enemy is Zombie000Base:
		if is_skill3:
			## 三技能爆炸伤害: 樱桃炸弹方式(穿透+死亡变灰烬)
			enemy.be_bomb(maxi(1, int(round(attack_value * main_target_mult))), true)
		else:
			enemy.be_attacked_bullet(maxi(1, int(round(attack_value * main_target_mult))), bullet_mode, true, trigger_be_attack_sfx)
		enemy.set_meta("wisdel_residue", true)
	## 三技能(爆裂黎明)期间: 命中敌人时播放樱桃炸弹爆炸特效
	## 注意: 必须在伤害结算后仍播放(敌已死也播, 特效与死亡灰烬同时)
	if is_skill3 and is_instance_valid(enemy):
		_play_cherry_bomb_effect(enemy)
	## 溅射: 范围内所有敌人(含主目标)受余震伤害
	_splash_all()
	## 残影爆炸: 带残影目标被余震影响时独立判定(天赋1)
	_check_residue_explode()
	## 命中音效: 三技能=樱桃炸弹爆炸音, 普通=受击音(用户选定 wisdel_hit.wav)
	if is_skill3:
		SoundManager.play_character_SFX(&"CherryBomb")
	else:
		SoundManager.play_character_SFX(&"WisdelHit")
	## 子弹音效/特效/销毁(照抄基类 attack_once 后半段)
	if type_bullet_SFX != SoundManagerClass.TypeBulletSFX.Null:
		SoundManager.play_bullet_attack_SFX(type_bullet_SFX)
	if bullet_effect.is_bullet_effect:
		if is_instance_valid(enemy) and enemy is Character000Base:
			bullet_effect.global_position.x = enemy.hurt_box_component.global_position.x
		bullet_effect.activate_bullet_effect()
	if max_attack_num != -1 and curr_attack_num >= max_attack_num:
		_detach_trail()
		queue_free()

## 销毁前让拖尾亮带留在原地淡出(避免拖尾瞬间消失)
func _detach_trail():
	var trail: Node = get_node_or_null("Trail")
	if is_instance_valid(trail) and trail.has_method("detach_and_fade"):
		trail.detach_and_fade()

## 三技能命中: 在敌人位置播放樱桃炸弹爆炸特效(自绘场景, activate 后自动销毁)
func _play_cherry_bomb_effect(enemy: Zombie000Base) -> void:
	var fx: Node2D = SceneRegistry.CHERRY_BOMB_EFFECT.instantiate()
	Global.main_game.add_child(fx)
	fx.global_position = enemy.global_position + Vector2(0, -40)
	fx.z_index = enemy.lane * 50 + 30
	if fx.has_method("activate_bomb_effect"):
		fx.call("activate_bomb_effect")
		## activate 内部会把特效 reparent 到 bombs 节点(不保留全局变换), 位置会被重置, 重新设回命中点
		fx.global_position = enemy.global_position + Vector2(0, -40)

## 溅射: 溅射范围内所有可攻击敌人受余震伤害(技能1时附带眩晕)
func _splash_all():
	var enemies: Array = _get_enemies_in_splash()
	for enemy: Character000Base in enemies:
		if enemy is Zombie000Base and not enemy.curr_be_attack_status & can_attack_zombie_status:
			continue
		if enemy is Plant000Base and not enemy.curr_be_attack_status & can_attack_plant_status:
			continue
		if is_skill3:
			## 三技能爆炸: 溅射也用樱桃炸弹方式(死亡变灰烬)
			enemy.be_bomb(maxi(1, int(round(attack_value * after_shock_mult))), true)
		else:
			enemy.be_attacked_bullet(maxi(1, int(round(attack_value * after_shock_mult))), bullet_mode, true, false)
		## 技能1定点清算: 使所有目标晕眩
		if stun_time > 0.0 and enemy is Zombie000Base and not enemy.is_death:
			enemy.be_butter(stun_time)

## 残影爆炸: 范围内带残影的僵尸被余震影响时 roll 概率, 爆炸对周围所有敌人造成天赋伤害+眩晕
func _check_residue_explode():
	var enemies: Array = _get_enemies_in_splash()
	for enemy: Character000Base in enemies:
		if not (enemy is Zombie000Base) or enemy.is_death:
			continue
		if not enemy.has_meta("wisdel_residue"):
			continue
		if randf() >= talent_explode_chance:
			continue
		## 残影消耗, 爆炸伤害范围=当前溅射范围
		enemy.remove_meta("wisdel_residue")
		for e: Character000Base in _get_enemies_in_splash():
			if not is_instance_valid(e):
				continue
			if e is Zombie000Base and not e.curr_be_attack_status & can_attack_zombie_status:
				continue
			if e is Plant000Base and not e.curr_be_attack_status & can_attack_plant_status:
				continue
			e.be_attacked_bullet(talent_explode_damage, bullet_mode, true, false)
			if e is Zombie000Base and not e.is_death:
				e.be_butter(talent_explode_stun)

## 获取溅射范围内所有角色(Area2D 相交)
func _get_enemies_in_splash() -> Array:
	var enemies: Array = []
	if not is_instance_valid(area_2d_spatter):
		return enemies
	var areas: Array = area_2d_spatter.get_overlapping_areas()
	for area in areas:
		var enemy: Node = area.owner
		if enemy is Character000Base:
			enemies.append(enemy)
	return enemies
