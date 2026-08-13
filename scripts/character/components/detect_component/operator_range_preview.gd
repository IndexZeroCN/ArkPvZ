extends Node2D
class_name OperatorRangePreview
## 干员攻击范围预览: 按草坪格子网格生成连续多边形 + shader 45° 橙/透明斜纹
## 由 HM_Character(部署方向选择阶段)与 OperatorMenu(选中干员菜单)创建;
## 统一挂主游戏场景根(世界画布, 变换 identity), 多边形世界坐标直接对应草坪,
## 条纹与草坪随分辨率同步缩放; 调用 set_range_cells 传入格子中心列表后自动绘制
## - 范围格子中心来自真实植物格节点(与草坪完全对齐), 每格矩形边长 = 网格间距 spacing
##   (相邻格子间若有空隙, 各向对方延伸半个空隙 = 矩形边长取间距, 天然无缝)
## - 角相邻的格子(斜对角)在共享角点处插入直角桥接方块(BRIDGE): 缺口被补上, 且轮廓全部为
##   90° 直角(无 45° 斜边、无圆角)
## - 无边框; 条纹由 shader 绘制(见 shaders/operator_range_stripes.gdshader), 45° 橙/透明斜纹
## - 干员所在格是否显示由范围形状(ATTACK_RANGE_SHAPE 是否含 (0,0))决定, 与检测一致

const STRIPES_SHADER := preload("res://shaders/operator_range_stripes.gdshader")

## 攻击范围格子中心(世界坐标)列表
var range_cell_centers: Array[Vector2] = []
## 网格间距(相邻格子中心距离, 世界坐标)
var grid_spacing := Vector2(76, 95)
## 干员位置(世界坐标, 用于提示箭头指向脚下)
var base_pos := Vector2.ZERO
## 是否显示提示(白色小箭头 + 文字, 指向干员脚下)
var show_hint := false

## 角相邻桥接方块边长: 补上斜对角缺口(直角连接, 无 45° 斜边)
const BRIDGE := 6.0

var _fill_polygons: Array[Polygon2D] = []
## 上一次的格子列表(用于跳过未变化的重建)
var _cached_cells: Array[Vector2] = []

func set_range_cells(cell_centers: Array[Vector2], spacing: Vector2, base: Vector2) -> void:
	## 格子列表与间距都没变则跳过(方向/位置未变时每帧都会调用)
	if grid_spacing == spacing and _cached_cells.size() == cell_centers.size():
		var same := true
		for i in cell_centers.size():
			if _cached_cells[i].distance_squared_to(cell_centers[i]) > 0.01:
				same = false
				break
		if same:
			return
	_cached_cells = cell_centers.duplicate()
	range_cell_centers = cell_centers
	grid_spacing = spacing
	base_pos = base
	_rebuild()

## 生成连续多边形并重建显示节点
func _rebuild() -> void:
	_clear_nodes()
	if range_cell_centers.is_empty():
		return
	## 1. 每个格子一个矩形(边长 = 网格间距 + 3px 重叠, 无缝覆盖草坪格+格间空隙, 并覆盖光栅化细缝)
	var overlap := 3.0
	var polys: Array[PackedVector2Array] = []
	for center: Vector2 in range_cell_centers:
		polys.append(_rect_poly(center, grid_spacing + Vector2.ONE * overlap))
	## 2. 角相邻(斜对角)的格子对: 在共享角点插入直角桥接方块(补缺口, 轮廓保持 90° 直角)
	var n: int = range_cell_centers.size()
	for i in range(n):
		for j in range(i + 1, n):
			var d: Vector2 = range_cell_centers[j] - range_cell_centers[i]
			if not is_equal_approx(absf(d.x), grid_spacing.x):
				continue
			if not is_equal_approx(absf(d.y), grid_spacing.y):
				continue
			## 共享角点 = 两格角接触处
			var corner: Vector2 = range_cell_centers[i] + Vector2(
				signf(d.x) * grid_spacing.x * 0.5,
				signf(d.y) * grid_spacing.y * 0.5)
			polys.append(_rect_poly(corner, Vector2.ONE * BRIDGE))
	## 3. 两两合并为连续多边形
	var merged := _merge_all(polys)
	## 4. 条纹填充(45° 橙/透明斜纹 shader)
	for poly: PackedVector2Array in merged:
		var fill_node := Polygon2D.new()
		fill_node.polygon = _clean_polygon(poly)
		var mat := ShaderMaterial.new()
		mat.shader = STRIPES_SHADER
		fill_node.material = mat
		add_child(fill_node)
		_fill_polygons.append(fill_node)

## 清理多边形: 顶点对齐到 0.5px 网格 + 删除共线中间点
## Polygon2D 三角剖分在共线点/小数坐标处会产生细长三角形, 光栅化在格子连接处漏出竖直细缝
func _clean_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 4:
		return poly
	var cleaned: PackedVector2Array = []
	var n: int = poly.size()
	for i in range(n):
		var prev: Vector2 = poly[(i - 1 + n) % n]
		var curr: Vector2 = poly[i]
		var next: Vector2 = poly[(i + 1) % n]
		## 共线中间点删除(叉积≈0)
		if absf((curr - prev).cross(next - curr)) < 0.01:
			continue
		cleaned.append(Vector2(round(curr.x * 2.0) * 0.5, round(curr.y * 2.0) * 0.5))
	if cleaned.size() < 3:
		return poly
	return cleaned

## 以中心和尺寸构造矩形多边形(顶点逆时针)
func _rect_poly(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + half,
		center + Vector2(-half.x, half.y),
	])

## 两两合并多边形直到无法再合并(返回连续多边形列表)
func _merge_all(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var current: Array[PackedVector2Array] = []
	for p: PackedVector2Array in polys:
		current.append(p)
	var changed := true
	while changed:
		changed = false
		var i := 0
		while i < current.size():
			var merged_any := false
			var j := i + 1
			while j < current.size():
				var merged := Geometry2D.merge_polygons(current[i], current[j])
				if merged.size() == 1:
					current[i] = merged[0]
					current.remove_at(j)
					changed = true
					merged_any = true
					break
				j += 1
			if merged_any:
				continue
			i += 1
	return current

## 清除旧的显示节点(先移出树避免同帧重复绘制, 再延迟释放)
func _clear_nodes() -> void:
	for p: Polygon2D in _fill_polygons:
		if is_instance_valid(p):
			remove_child(p)
			p.queue_free()
	_fill_polygons.clear()

func _draw() -> void:
	## 提示: 白色小箭头 + "移动鼠标选方向, 点击确认" 文字(指向干员脚下)
	if show_hint:
		var arrow_tip := base_pos + Vector2(0, 6)
		draw_line(arrow_tip + Vector2(0, 10), arrow_tip, Color(1, 1, 1, 0.9), 1.5)
		draw_line(arrow_tip + Vector2(0, 10), arrow_tip + Vector2(-4, 6), Color(1, 1, 1, 0.9), 1.5)
		draw_line(arrow_tip + Vector2(0, 10), arrow_tip + Vector2(4, 6), Color(1, 1, 1, 0.9), 1.5)
		## 提示文字(在干员上方)
		var font := ThemeDB.fallback_font
		var text := "移动鼠标选方向, 点击确认"
		var text_pos := base_pos + Vector2(-60, -100)
		draw_rect(Rect2(text_pos, Vector2(120, 16)), Color(0, 0, 0, 0.45))
		draw_string(font, text_pos + Vector2(2, 12), text, HORIZONTAL_ALIGNMENT_CENTER, 116, 10, Color(1, 1, 1, 0.9))
