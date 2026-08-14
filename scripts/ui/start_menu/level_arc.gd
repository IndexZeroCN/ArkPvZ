extends Control
class_name LevelArc

## 明日方舟等级圆环进度弧（替代 sprite 缺失的 chart_pr）

var fill := 0.62
var arc_color := Color(1.0, 0.62, 0.05)

func _draw() -> void:
	var center := size * 0.5
	var radius: float = 53
	var from := -PI / 2.0
	var to := from + TAU * fill
	draw_arc(center, radius, from, to, 48, arc_color, 3.5, true)
