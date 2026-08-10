class_name OperatorCalibration
## 干员校准数据（JSON）读取与应用
## 数据文件: res://data/operator_calibration.json（由 test/operator_debug_tool.tscn 的"应用"按钮写入）
## JSON 结构:
##   "_shared": 全干员共用配置 {container_y, spine_x, spine_y, scale}（可调, 代码常量仅作缺省兜底）
##   "<干员id>": 该干员独有 {delay, spawn_x, spawn_y}
## 干员 id = 素材文件夹名, 与干员场景根节点 operator_id 一致
## 场景里的值为默认/兜底, 运行时以本 JSON 覆盖

const CALIBRATION_PATH := "res://data/operator_calibration.json"

## 共用配置在 JSON 里的键（不是干员 id）
const SHARED_KEY := "_shared"
## 共用配置缺省值（JSON 没有 _shared 时回退, 不是权威值）
const DEFAULT_SHARED := {
	"container_y": 20.0,
	"spine_x": 0.0,
	"spine_y": 0.0,
	"scale": 0.33,
	## 血条/经验条(同长同宽): 长度px / 宽度px / 血条中心Y(相对干员根, 经验条在其下紧贴)
	"hp_bar_len": 85.0,
	"hp_bar_w": 4.0,
	"hp_bar_y": -7.0,
}

static var _cache: Dictionary = {}

## 读取全部校准数据（懒加载并缓存）
static func get_all() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(CALIBRATION_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_cache = parsed
			f.close()
	return _cache

## 获取全干员共用配置（缺省值合并, 保证字段齐全）
static func get_shared() -> Dictionary:
	var result := DEFAULT_SHARED.duplicate()
	var entry: Variant = get_all().get(SHARED_KEY, {})
	if entry is Dictionary:
		for key in entry:
			result[key] = entry[key]
	return result

## 获取指定干员的校准数据（无则返回空字典）
static func get_calibration(operator_id: String) -> Dictionary:
	var entry: Variant = get_all().get(operator_id, {})
	return entry if entry is Dictionary else {}

## 把校准数据应用到干员本体（部署时 Operator000Base._ready 与部署预览 HM_Character 都调用）
static func apply_to(operator_root: Node) -> void:
	## 1) 全干员共用配置: 容器 Y / Spine 位置 / 缩放（有 Spine 形象时）
	var shared := get_shared()
	if operator_root.has_method("get_operator_spine"):
		var spine: Node = operator_root.call("get_operator_spine")
		if is_instance_valid(spine):
			spine.set("position", Vector2(shared["spine_x"], shared["spine_y"]))
			spine.set("scale", Vector2.ONE * shared["scale"])
			if operator_root.has_method("get_operator_sprite"):
				var container: Node2D = operator_root.call("get_operator_sprite")
				if is_instance_valid(container):
					container.position.y = shared["container_y"]
	## 2) 该干员独有: 发射延迟与发射点（JSON）
	var op_id: String = str(operator_root.get("operator_id"))
	var calib := get_calibration(op_id)
	## 3) 血条/经验条: 长度/宽度/位置（全干员共用, 同长同宽）
	_apply_hp_bar_config(operator_root, shared)
	if calib.is_empty():
		return
	print("[干员校准] 应用 %s: %s" % [op_id, JSON.stringify(calib, "")])
	var atk: Node = operator_root.get_node_or_null("AttackComponent")
	if atk != null:
		if calib.has("delay"):
			atk.set("bullet_spawn_delay", float(calib["delay"]))
		if calib.has("spawn_x") and calib.has("spawn_y"):
			atk.set("bullet_spawn_offset", Vector2(float(calib["spawn_x"]), float(calib["spawn_y"])))

## 应用血条/经验条尺寸位置(全干员共用; 血条上、经验条下紧贴, 同长同宽)
static func _apply_hp_bar_config(operator_root: Node, shared: Dictionary) -> void:
	var bar_len := float(shared.get("hp_bar_len", 85.0))
	var bar_w := float(shared.get("hp_bar_w", 4.0))
	var bar_y := float(shared.get("hp_bar_y", -7.0))
	## 经验条中心 = 血条中心 + 条宽(紧紧贴住, 无间距)
	var exp_y := bar_y + bar_w
	var hp_control: Control = operator_root.get_node_or_null("HpComponent/HpControl")
	var skill_control: Control = operator_root.get_node_or_null("SkillComponent/SkillControl")
	if is_instance_valid(hp_control):
		hp_control.offset_top = bar_y
		hp_control.offset_bottom = bar_y
	if is_instance_valid(skill_control):
		skill_control.offset_top = exp_y
		skill_control.offset_bottom = exp_y
	var hp_bar: Control = operator_root.get_node_or_null("HpComponent/HpControl/ProgressBarHp")
	var skill_bar: Control = operator_root.get_node_or_null("SkillComponent/SkillControl/ProgressBarSkill")
	for bar in [hp_bar, skill_bar]:
		if bar is ProgressBar:
			(bar as ProgressBar).custom_minimum_size = Vector2(bar_len, bar_w)
			bar.offset_left = -bar_len * 0.5
			bar.offset_right = bar_len * 0.5
			bar.offset_top = -bar_w * 0.5
			bar.offset_bottom = bar_w * 0.5
	## 技能条水平镜像: fill 从右往左增长(攒SP右端长), 与血条掉血方向(右端缩)一致, 两条方向不相反
	## pivot_offset 设为中心, 否则镜像以左上角为轴会整体偏到左边
	if skill_bar is ProgressBar:
		skill_bar.pivot_offset = Vector2(bar_len * 0.5, bar_w * 0.5)
		skill_bar.scale.x = -1.0
