extends Node2D
class_name ArrowVisual
## 箭矢视觉: 杏仁状(长8px 最宽2px) + 微弱发光
## 自绘生成, 无需贴图资源; 跟随 Body 旋转朝向

## 主箭体半长(总长 = half_length * 2)
@export var half_length: float = 4.0
## 主箭体半宽(最宽处 = half_width * 2)
@export var half_width: float = 1.0
## 发光范围倍率
@export var glow_scale: float = 1.7

func _draw() -> void:
	## 微弱发光(大一圈的半透明杏仁)
	draw_colored_polygon(_ellipse_points(half_length * glow_scale, half_width * glow_scale), Color(0.55, 0.85, 1.0, 0.18))
	## 主箭体(杏仁状)
	draw_colored_polygon(_ellipse_points(half_length, half_width), Color(0.85, 0.96, 1.0, 0.95))
	## 中心亮芯(微光)
	draw_colored_polygon(_ellipse_points(half_length * 0.5, half_width * 0.4), Color(1.0, 1.0, 1.0, 0.85))

## 生成椭圆/杏仁形点集(两端自然尖端过渡)
func _ellipse_points(radius_x: float, radius_y: float, segments: int = 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var t := TAU * i / segments
		points.append(Vector2(cos(t) * radius_x, sin(t) * radius_y))
	return points
