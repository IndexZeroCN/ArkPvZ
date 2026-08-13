extends Node2D
class_name TrailComet
## 彗星式拖尾组件(2D 画布亮带)
## 参考 godotshaders.com "Particle based trail"(3D GPUParticles 把拖尾数据编进 TRANSFORM、
## draw pass 拉伸成条带) 的思路, 在 2D 画布上用 Line2D 亮带实现同款"连续条带拖尾":
## 每物理帧记录父节点的飞行轨迹点, 从头部主色渐变到尾部同色系渐隐、宽度渐细。
## 样式(E_TrailStyle): 双层(柔光+亮芯, 普通混合) / 单层(只亮芯, 普通混合) / 发光(双层, 加色混合)
## 长度只受记录点数限制(与贴图无关, 可以做得很长)。
## 用法: 作为子弹/移动物体的子节点, 父节点位移即自动产生拖尾;
##       父节点销毁前调用 detach_and_fade() 让拖尾留在原地淡出, 更自然;
##       运行时可用 setup() 按校准参数(长度/颜色/样式)重建亮带。

## 拖尾样式(调试校准 JSON: trail_style)
enum E_TrailStyle {
	Double = 0,	## 双层亮带: 外层柔光 + 内层亮芯, 普通混合(暗色调可直接呈现)
	Single = 1,	## 单层亮带: 只亮芯, 普通混合
	Glow = 2,	## 发光: 双层 + 加色混合(亮背景上压不暗, 适合亮色调)
}

## 最大记录点数(拖尾长度 ≈ 点数 × 平均间距, 速度 620 时约 500px 以上)
@export var max_points: int = 56
## 相邻两点最小间距(px): 高速时限制点密度, 同时保证长度稳定
@export var min_gap: float = 5.0
## 亮芯最大宽度(px, 头部)
@export var head_width: float = 8.0
## 头部颜色(主色; 中部=主色×0.7, 尾部=主色×0.3 渐隐透明)
@export var head_color: Color = Color(0.7, 0.08, 0.12, 0.95)
## 中部颜色(主色派生, setup 时重算)
@export var mid_color: Color = Color(0.5, 0.04, 0.08, 0.65)
## 尾部颜色(主色派生, 渐隐到全透明)
@export var tail_color: Color = Color(0.22, 0.01, 0.03, 0.0)
## 外层柔光宽度倍数(相对亮芯; 同色低透明度, 模拟辉光晕)
@export var glow_width_scale: float = 2.6
## 外层柔光透明度倍数
@export var glow_alpha_scale: float = 0.4
## 是否绘制外层柔光层(E_TrailStyle.Single 时关闭)
@export var use_glow_layer: bool = true
## 是否加色混合(模拟辉光): 亮背景(草地)上压不暗, 需暗色调时改 false 用普通混合
@export var additive: bool = false
## 亮带头部沿飞行方向向前延伸的像素(接上弹头后端; 拖尾代替炮弹本体时留 0, 头部即子弹当前位置)
@export var head_extend: float = 0.0

## 历史轨迹点(全局坐标, 最新点在末尾=头部)
var _points: PackedVector2Array = PackedVector2Array()
## 最近一次位移方向(用于头部延伸, 与飞行方向对齐)
var _last_dir: Vector2 = Vector2.ZERO
var _core_line: Line2D = null
var _glow_line: Line2D = null

func _ready() -> void:
	_build_lines()

## 按样式参数重建亮带(柔光层/加色材质)
func _build_lines() -> void:
	for child in get_children():
		if child is Line2D:
			remove_child(child)
			child.queue_free()
	_core_line = _make_line()
	_glow_line = null
	if use_glow_layer:
		var glow_grad := _make_gradient()
		_scale_gradient_alpha(glow_grad, glow_alpha_scale)
		_glow_line = _make_line()
		_glow_line.width = head_width * glow_width_scale
		_glow_line.gradient = glow_grad
		_glow_line.z_index = -3
		add_child(_glow_line)
	add_child(_core_line)

## 运行时按校准参数重建亮带(长度/主色/样式/宽度); 颜色派生: 头=主色, 中=主色×0.7, 尾=主色×0.3 渐隐
func setup(new_max_points: int, new_color: Color, new_style: int, new_head_width: float = -1.0) -> void:
	max_points = maxi(new_max_points, 0)
	if new_head_width > 0.0:
		head_width = new_head_width
	head_color = Color(new_color.r, new_color.g, new_color.b, 0.95)
	mid_color = Color(new_color.r * 0.7, new_color.g * 0.7, new_color.b * 0.7, 0.65)
	tail_color = Color(new_color.r * 0.3, new_color.g * 0.3, new_color.b * 0.3, 0.0)
	match new_style:
		E_TrailStyle.Single:
			use_glow_layer = false
			additive = false
		E_TrailStyle.Glow:
			use_glow_layer = true
			additive = true
		_:
			use_glow_layer = true
			additive = false
	_build_lines()

## 创建一条亮带 Line2D(共用宽度曲线/渐变)
func _make_line() -> Line2D:
	var line := Line2D.new()
	line.width = head_width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	## 宽度曲线: 0=最老点(尾部)细, 1=最新点(头部)粗
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.06))
	width_curve.add_point(Vector2(0.7, 0.8))
	width_curve.add_point(Vector2(1.0, 1.0))
	line.width_curve = width_curve
	## 颜色渐变: 0=尾部渐隐透明, 1=头部主色
	line.gradient = _make_gradient()
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		line.material = mat
	## 画在子弹本体(身体/影子)之下
	line.z_index = -2
	return line

func _make_gradient() -> Gradient:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([tail_color, mid_color, head_color])
	return grad

func _scale_gradient_alpha(grad: Gradient, scale: float) -> void:
	var cols := grad.colors
	for i in cols.size():
		cols[i] = Color(cols[i].r, cols[i].g, cols[i].b, cols[i].a * scale)
	grad.colors = cols

func _physics_process(_delta: float) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var pos: Vector2 = parent.global_position
	if _points.is_empty() or pos.distance_to(_points[_points.size() - 1]) >= min_gap:
		if not _points.is_empty():
			_last_dir = (pos - _points[_points.size() - 1]).normalized()
		_points.append(pos)
		if _points.size() > max_points:
			_points.remove_at(0)
	_update_line()

## 把记录的全局轨迹点换算到本地空间并写进亮带; 头部点沿飞行方向延伸接上弹头后端
func _update_line() -> void:
	if _core_line == null:
		return
	var n := _points.size()
	if n == 0:
		_core_line.points = PackedVector2Array()
		if _glow_line != null:
			_glow_line.points = PackedVector2Array()
		return
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in range(n - 1):
		pts[i] = to_local(_points[i])
	var head := _points[n - 1]
	if _last_dir != Vector2.ZERO and head_extend > 0.0:
		head += _last_dir * head_extend
	pts[n - 1] = to_local(head)
	_core_line.points = pts
	if _glow_line != null:
		_glow_line.points = pts

## 拖尾脱离父节点留在原地淡出(父节点销毁前调用, 避免拖尾瞬间消失)
func detach_and_fade(fade_time: float = 0.16) -> void:
	set_physics_process(false)
	var parent := get_parent()
	if not is_instance_valid(parent):
		queue_free()
		return
	_update_line()
	var keeper := parent.get_parent()
	if is_instance_valid(keeper) and keeper != self:
		reparent(keeper, true)
	var tw := create_tween()
	if _glow_line != null:
		tw.parallel().tween_property(_glow_line, "modulate:a", 0.0, fade_time).set_ease(Tween.EASE_IN)
	tw.tween_property(_core_line, "modulate:a", 0.0, fade_time).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
