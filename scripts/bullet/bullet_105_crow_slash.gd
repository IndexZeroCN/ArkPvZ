extends BulletLinear000Base
class_name Bullet105CrowSlash
## 羽毛笔近战斩击子弹(收割者风格: 无视屋顶斜坡, 直线飞行不撞坡, 无弹体贴图)
## 攻击方式: 攻击组件每次攻击只发射一发本子弹(朝最近目标), 命中后由干员 on_crow_slash_hit()
##           一次性结算攻击范围内所有敌人(群体伤害在干员侧, 非多发子弹)。
## 技能1 二连击: hit_times=2, 命中时对范围内每个敌人一次性施加两次攻击(近卫多连击)。
## 二技能 收割 生效时: 对生命值低于 50% 的敌人额外增伤(低血增伤由本子弹按目标当前血量判定)。
## 击杀上报: 命中后若目标死亡, 回调干员 on_crow_kill() 叠加天赋 渐入佳境(攻速)。

## 干员本体(发射方), 由 init_splash_paras 传入; 用于击杀上报
var owner_operator: Operator000Base = null
## 二技能 收割: 低血量额外增伤倍率(0=不生效; 专三 0.5 = +50%)
var low_hp_bonus := 0.0
## 低血量阈值(生命比例低于该值触发增伤)
var low_hp_threshold := 0.5
## 技能1 二连击次数(对每个敌人一次性施加 hit_times 次攻击)
var hit_times := 1

func _ready() -> void:
	ignore_slope = true
	super()

## 发射前由干员通过 attack_paras.splash_paras 传入(复用干员子弹自定义参数通道)
func init_splash_paras(paras: Dictionary):
	owner_operator = paras.get("owner", null)
	low_hp_bonus = paras.get("low_hp_bonus", 0.0)
	low_hp_threshold = paras.get("low_hp_threshold", 0.5)
	hit_times = maxi(1, int(paras.get("hit_times", 1)))

## 对僵尸敌人造成伤害: 群攻由干员一次性结算攻击范围内所有敌人(低血增伤/回血/击杀上报在干员侧)
func _attack_zombie(zombie: Zombie000Base):
	if is_instance_valid(owner_operator) and owner_operator.has_method("on_crow_slash_hit"):
		owner_operator.on_crow_slash_hit(attack_value, low_hp_bonus, low_hp_threshold, hit_times)
		return
	## 兜底: 未绑定干员时退化为单目标伤害(与直线基类一致, 保留"背面攻击转真实伤害")
	var mode: BulletRegistry.AttackMode = bullet_mode
	if direction.x < 0 and bullet_mode == BulletRegistry.AttackMode.Norm:
		mode = BulletRegistry.AttackMode.Real
	zombie.be_attacked_bullet(attack_value, mode, true, trigger_be_attack_sfx)
