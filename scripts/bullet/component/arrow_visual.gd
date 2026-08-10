extends Node2D
class_name ArrowVisual
## 克洛丝箭矢视觉: 细白光针 + 深色小箭头头部 + 白色拖尾(流星残影)
## 风格: "光之箭"/"能量矢", 极细针状, 无实体箭杆/箭羽
## 自绘生成, 无需贴图资源; 默认朝 +x, 跟随 Body 旋转朝向

## 针体长度(px)
@export var body_length: float = 14.0
## 针体宽度(极细)
@export var body_width: float = 1.0
## 前端深色箭头大小
@export var head_size: float = 3.0
## 拖尾长度(向后渐隐)
@export var trail_length: float = 12.0

func _draw() -> void:
	var half := body_length * 0.5
	var body_start := Vector2(-half, 0)
	var body_end := Vector2(half, 0)

	## 1) 拖尾(流星残影): 针体尾端向后渐隐的白色细线, 分多段做透明度渐变
	var trail_start := Vector2(-half, 0)
	var trail_end := Vector2(-half - trail_length, 0)
	var trail_seg := 6
	for i in range(trail_seg):
		var a := trail_start.lerp(trail_end, float(i) / trail_seg)
		var b := trail_start.lerp(trail_end, float(i + 1) / trail_seg)
		var alpha := 0.5 * (1.0 - float(i) / trail_seg)
		draw_line(a, b, Color(1, 1, 1, alpha), body_width * 0.9)

	## 2) 针体: 外层发光(半透明宽线) + 亮芯(细白线)
	draw_line(body_start, body_end, Color(0.8, 0.95, 1.0, 0.30), body_width * 3.5)
	draw_line(body_start, body_end, Color(1, 1, 1, 0.95), body_width)

	## 3) 前端深色小箭头(三角头部, 略带灰深色调)
	var tip := Vector2(half + head_size * 0.6, 0)
	var head := PackedVector2Array([
		tip,
		Vector2(half - head_size * 0.4, -head_size * 0.55),
		Vector2(half - head_size * 0.4, head_size * 0.55),
	])
	draw_colored_polygon(head, Color(0.32, 0.36, 0.42, 0.92))
	## 箭头前端尖端微光(与针体衔接)
	draw_line(Vector2(half - head_size * 0.4, 0), tip, Color(1, 1, 1, 0.75), body_width * 0.6)
