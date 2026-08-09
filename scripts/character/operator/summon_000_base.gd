extends Operator000Base
class_name Summon000Base
## 明日方舟召唤物基类
## 与干员类似(血条/技能条/可被僵尸攻击), 区别:
## - 不消耗部署点数(由干员技能部署, 见 init_summon)
## - 默认不可撤退/不可手动放技能(干员菜单中对应按钮禁用)
## - 持有主人干员引用(owner_operator), 主人撤退/死亡时由创建者逻辑处理消失

func _ready() -> void:
	super()

## 初始化正常出战角色
func ready_norm():
	super()
	## 召唤物不需要部署点数(若有plant_type也强制为0)
	pass
