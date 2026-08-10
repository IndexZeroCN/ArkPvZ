extends BulletLinear000Base
class_name Bullet101KroosArrow
## 克洛丝箭矢子弹(干员风格: 无视屋顶斜坡, 直线飞行不撞坡)
## TODO: 将占位贴图替换为明日方舟风格箭矢(见 docs/明日方舟干员系统.md 素材管线)
## 后续可扩展: 箭矢旋转(发射角度)、穿透箭等

func _ready() -> void:
	ignore_slope = true
	super()
