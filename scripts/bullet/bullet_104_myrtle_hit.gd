extends BulletLinear000Base
class_name Bullet104MyrtleHit
## 桃金娘近战挥击子弹(干员风格: 无视屋顶斜坡, 直线飞行不撞坡)
## 视觉: 无独立弹体贴图(近战, 攻击动画本身即挥旗动作), 极短程命中所在格僵尸后消失
## 音效: 使用攻击组件默认发射音(play_throw_sfx), 无专属音

func _ready() -> void:
	ignore_slope = true
	super()
