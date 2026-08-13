extends Operator000Base
class_name Operator001Kroos
## 克洛丝 - 速射手
## 特性: 优先攻击空中单位(当前版本沿行攻击所有僵尸)
## 天赋 要害瞄准·初级(满潜/潜能5强化): 攻击时20%几率当次攻击的攻击力提升至150%
## 技能 二连射·自动(攻击回复·自动触发): 攻击回复技能点, 5点就绪后下次攻击连续射击2次
## 技能条: 绿条满后保持满, 下次攻击开始时变橙色满条, 并在本次攻击动画内逐渐耗尽为0

## 暴击几率(天赋 要害瞄准·初级 满潜/潜能5强化: 20%)
@export var crit_chance: float = 0.2
## 暴击伤害倍率(天赋: 攻击力提升至150%)
@export var crit_multiplier: float = 1.5
## 技能连射数(二连射)
@export var double_shot_count: int = 2

## 技能触发后下次攻击是否连射
var double_shot_pending := false

## 初始化正常出战角色
func ready_norm():
	super()
	## 攻击回复自动技能: 就绪后不立即消耗SP(绿条保持满), 下次攻击开始时才消耗
	skill_component.is_auto_trigger = false

## 使用技能(手动菜单): 仅"武装"技能, 绿条保持满; 下次攻击开始时消耗并变橙色技能条
func use_skill() -> bool:
	if not skill_component.is_skill_ready:
		return false
	double_shot_pending = true
	return true

## 攻击动画开始回调: 技能就绪则本次攻击消耗技能, 技能条变橙色并在动画时长内耗尽
func on_attack_anim_start():
	if try_start_skill_burst():
		double_shot_pending = true

## 攻击参数钩子: 连射(技能)与暴击(天赋)
func get_attack_paras() -> Dictionary:
	var count: int = 1
	if double_shot_pending:
		count = double_shot_count
		double_shot_pending = false
	var multiplier: float = 1.0
	## 天赋 要害瞄准: 20%几率攻击力提升至150%
	if randf() < crit_chance:
		multiplier = crit_multiplier
	return {"count": count, "multiplier": multiplier}
