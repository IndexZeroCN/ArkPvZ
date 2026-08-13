extends Node2D
class_name WisdelShadowBeam
## 魂灵之影攻击射线特效(仿明日方舟游戏内效果)
## 过程: 射线从魂灵之影向目标伸展(0.09s) -> 命中点白红四芒星闪光 -> 暗红碎片爆发+蓝色小电火花, 射线淡出
## 伤害时机: 射线到达目标时发出 signal_beam_hit, 由召唤物回调结算伤害

## 射线到达目标(命中帧)
signal signal_beam_hit

## 射线贴图像素宽度(与 beam.png 一致)
const BEAM_TEX_WIDTH := 256.0
## 射线伸展时长(秒)
const BEAM_EXTEND_TIME := 0.09
## 射线粗细系数(scale.y): 1.0 = 贴图原视觉宽度约10px; 调大变粗(2.0 = 约20px), 调小变细
const BEAM_THICKNESS := 5.0

@onready var beam: Sprite2D = $Beam
@onready var impact_star: Sprite2D = $ImpactStar
@onready var burst: Sprite2D = $Burst
@onready var spark: Sprite2D = $Spark

## 惰性解析节点引用(fire 可能在 _ready 前被调用, 如测试/提前触发场景)
func _resolve_nodes():
	if is_instance_valid(beam):
		return
	beam = $Beam
	impact_star = $ImpactStar
	burst = $Burst
	spark = $Spark

## 发射射线(需先 add_child 再调用)
## [from_pos] 射线起点全局坐标(魂灵之影口部) [to_pos] 目标点全局坐标 [z] 渲染层级(按行 lane*50+40)
func fire(from_pos: Vector2, to_pos: Vector2, z: int):
	_resolve_nodes()
	z_index = z
	z_as_relative = false
	global_position = from_pos
	var dir: Vector2 = to_pos - from_pos
	rotation = dir.angle()
	var dist: float = maxf(dir.length(), 1.0)
	## 命中点特效挂到射线末端(随根节点旋转)
	impact_star.position = Vector2(dist, 0)
	burst.position = Vector2(dist, 0)
	## 电火花略偏下(图中火花在爆点下方)
	spark.position = Vector2(dist + 6.0, 10.0)
	spark.rotation = randf_range(-0.6, 0.6)
	## 射线从起点向目标伸展(粗细 = 贴图宽 × BEAM_THICKNESS)
	beam.scale = Vector2(0.03, BEAM_THICKNESS)
	var tween := create_tween()
	tween.tween_property(beam, "scale:x", dist / BEAM_TEX_WIDTH, BEAM_EXTEND_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_beam_arrive)

## 射线到达目标: 命中信号 + 四芒星闪光 + 射线宽度逐渐缩小直至没有
func _on_beam_arrive():
	signal_beam_hit.emit()
	impact_star.visible = true
	impact_star.scale = Vector2.ONE * 0.2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact_star, "scale", Vector2.ONE * 1.15, 0.07).set_ease(Tween.EASE_OUT)
	## 射线宽度(纵向)渐缩至 0, 线段随之消失
	tween.tween_property(beam, "scale:y", 0.0, 0.22).set_delay(0.05).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_interval(0.09)
	tween.tween_callback(_show_burst)

## 闪光收尾: 暗红碎片爆发 + 蓝色电火花闪烁, 全部淡出后销毁
func _show_burst():
	impact_star.visible = false
	burst.visible = true
	spark.visible = true
	burst.scale = Vector2.ONE * 0.35
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.22).set_delay(0.08)
	tween.tween_property(spark, "modulate:a", 0.0, 0.15).set_delay(0.05)
	tween.set_parallel(false)
	tween.tween_interval(0.35)
	tween.tween_callback(queue_free)
