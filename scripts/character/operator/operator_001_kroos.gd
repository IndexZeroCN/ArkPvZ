extends Operator000Base
class_name Operator001Kroos
## 克洛丝 - 速射手
## 特性: 优先攻击空中单位(当前版本沿行攻击所有僵尸)
## 天赋 要害瞄准·初级: 攻击时10%几率当次攻击的攻击力提升至150%
## 技能 二连射·自动(攻击回复·自动触发): 攻击回复技能点, 5点就绪后下次攻击连续射击2次

@onready var attack_component: AttackComponentOperator = $AttackComponent

## 暴击几率(天赋 要害瞄准·初级 满级: 20%)
@export var crit_chance: float = 0.2
## 暴击伤害倍率(天赋)
@export var crit_multiplier: float = 1.5
## 技能连射数(二连射)
@export var double_shot_count: int = 2

## 技能触发后下次攻击是否连射
var double_shot_pending := false

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()

## 技能释放(二连射): 标记下次攻击连射
func _on_skill_use():
	double_shot_pending = true

## 攻击参数钩子: 连射(技能)与暴击(天赋)
func get_attack_paras() -> Dictionary:
	var count: int = 1
	if double_shot_pending:
		count = double_shot_count
		double_shot_pending = false
	var multiplier: float = 1.0
	## 天赋 要害瞄准: 10%几率攻击力提升至150%
	if randf() < crit_chance:
		multiplier = crit_multiplier
	return {"count": count, "multiplier": multiplier}
