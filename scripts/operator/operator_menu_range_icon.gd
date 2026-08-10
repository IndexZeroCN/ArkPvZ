extends Control
class_name OperatorMenuRangeIcon
## 干员菜单中的攻击范围小图标: 网格图, 点亮范围内的格(橙黄), 干员格用白色圆点标记
## 数据来自 DetectComponentOperator.ATTACK_RANGE_SHAPE(行偏移, 列偏移)

var shape: Array[Vector2i] = []
var rows := 3
var cols := 4
var _min_r := -1
var _min_c := 0

## 设置范围形状并重绘
func set_range_shape(range_shape: Array[Vector2i]):
	shape = range_shape
	_min_r = 9999
	var max_r := -9999
	_min_c = 9999
	var max_c := -9999
	for offset: Vector2i in range_shape:
		_min_r = mini(_min_r, offset.x)
		max_r = maxi(max_r, offset.x)
		_min_c = mini(_min_c, offset.y)
		max_c = maxi(max_c, offset.y)
	rows = max_r - _min_r + 1
	cols = max_c - _min_c + 1
	queue_redraw()

func _draw() -> void:
	if shape.is_empty() or size.x <= 0 or size.y <= 0:
		return
	var cell := Vector2(size.x / float(cols), size.y / float(rows))
	## 网格线
	for c in range(cols + 1):
		draw_line(Vector2(c * cell.x, 0), Vector2(c * cell.x, size.y), Color(1, 1, 1, 0.18), 1.0)
	for r in range(rows + 1):
		draw_line(Vector2(0, r * cell.y), Vector2(size.x, r * cell.y), Color(1, 1, 1, 0.18), 1.0)
	## 点亮范围格(橙黄)
	for offset: Vector2i in shape:
		var rect := Rect2(Vector2((offset.y - _min_c) * cell.x, (offset.x - _min_r) * cell.y), cell)
		draw_rect(rect, Color(1.0, 0.72, 0.15, 0.4))
		draw_rect(rect, Color(1.0, 0.8, 0.3, 0.9), false, 1.0)
	## 干员格标记(白色圆点, 偏移(0,0))
	var op_rect := Rect2(Vector2((0 - _min_c) * cell.x, (0 - _min_r) * cell.y), cell)
	draw_circle(op_rect.get_center(), 2.5, Color(1, 1, 1, 0.95))
