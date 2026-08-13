extends Bullet102WisdelShell
class_name Bullet103WisdelSkill2Shell
## 维什戴尔二技能炮弹：从天而降，命中后触发与普通炮弹相同的溅射/余震/残影爆炸

## 目标敌人（用于主目标直击）
var target_enemy: Zombie000Base = null
## 目标落点（敌人发射时的位置，敌人消失时仍落在此处）
var target_pos: Vector2 = Vector2.ZERO
## 下落起点（目标正上方）
var fall_start_pos: Vector2 = Vector2.ZERO
## 下落总时长（比玉米加农炮快很多）
@export var fall_duration: float = 0.35
var _fall_time: float = 0.0

func init_bullet(bullet_paras: Dictionary):
	super(bullet_paras)
	target_enemy = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.Enemy, null)
	target_pos = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.EnemyGloPos, position)
	if target_enemy is Zombie000Base and is_instance_valid(target_enemy.hurt_box_component):
		target_pos = target_enemy.hurt_box_component.global_position

func _ready() -> void:
	super()
	## 关闭直线移动组件，改由本脚本控制下落
	if is_instance_valid(movement_component):
		movement_component.set_physics_process(false)
	## 炮弹起始位置：目标正上方高处
	fall_start_pos = Vector2(target_pos.x, target_pos.y - 700.0)
	global_position = fall_start_pos
	## 弹体朝向下
	body.rotation = PI * 0.5
	## 影子隐藏（高空坠落不需要豌豆影子）
	bullet_shadow.visible = false

func _physics_process(delta: float) -> void:
	_fall_time += delta
	var t: float = clampf(_fall_time / fall_duration, 0.0, 1.0)
	## 加速下落（先慢后快）
	var eased_t := t * t
	global_position = fall_start_pos.lerp(target_pos + Vector2(0, -20), eased_t)
	if t >= 1.0:
		## 落地命中：优先直击原目标，否则对落点溅射
		var hit_enemy: Character000Base = target_enemy
		if not is_instance_valid(hit_enemy) or hit_enemy.is_death:
			hit_enemy = null
		if hit_enemy != null:
			attack_once(hit_enemy)
		else:
			attack_once(null)
