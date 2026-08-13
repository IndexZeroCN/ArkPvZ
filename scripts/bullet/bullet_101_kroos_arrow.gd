extends BulletLinear000Base
class_name Bullet101KroosArrow
## 克洛丝箭矢子弹(干员风格: 无视屋顶斜坡, 直线飞行不撞坡)
## 视觉: 真实箭矢贴图 projectile_arrow.png(114x27, 箭头朝 +X) + TrailComet 拖尾(参数由校准 JSON 应用)
## 音效: 攻击发射播 KroosAttack(用户选定 p_atk_crossbow_n); 命中无专属音(用户未指定)
## 后续可扩展: 箭矢旋转(发射角度)、穿透箭等

func _ready() -> void:
	ignore_slope = true
	super()
	## 攻击音效(子弹创建即发射延迟后, 出生点播放)
	SoundManager.play_character_SFX(&"KroosAttack")
