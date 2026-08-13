extends Node2D
## 干员调试工具（攻击时序 / 发射点 校准）
## 运行: godot --path . res://test/operator_debug_tool.tscn（或编辑器 F6 运行此场景）
## 用途: 校准每个干员的 发射延迟 + 发射点, 数据写入 data/operator_calibration.json
## 说明: 干员的位置/缩放为全干员共用配置(JSON 的 _shared 段, 所有干员一样),
##       在本工具"共用配置"滑块区调整, 应用后写入 JSON, 游戏运行时读取
## 操作:
##   - 顶部下拉选择干员（自动扫描 assets/image/operator/ 下含 skel 的文件夹, 键=干员id）
##   - 点击画面任意位置: 直接把发射点设到该处（对准弩口/松手位置）
##   - 滑块: 发射延迟 / 发射点X / 发射点Y
##   - 自动循环攻击: 每 attack_cd 秒打一发真实箭矢, 边看边点最方便
##   - 「应用」写入 JSON（游戏运行时读取覆盖场景默认值）
## 新增干员: 在 CharacterRegistry.PlantInfo 登记 Operator* 字段(显示名/子弹/攻击动画/攻击模式),
##          并在 OPERATOR_GAME_VALUES(初始值回退)登记校准初始值(JSON 无此干员时使用)

const ARROW_SCENE := preload("res://scenes/bullet/bullet_101_kroos_arrow.tscn")
## 干员子弹场景/攻击动画/攻击模式/显示名均从 CharacterRegistry 的 PlantInfo 读取(见 PlantInfoAttribute.Operator*),
## 调试工具不再维护硬编码表; 未登记干员回退: 子弹=克洛丝箭矢, 动画=["Attack"], 模式=普通, 显示名=文件夹名
## 校准数据文件(键=干员id, 游戏运行时读取)
const JSON_PATH := "res://data/operator_calibration.json"

## 参考点: 模拟植物根节点位置(游戏内即 PlantNormContainer 全局位置)
const ROOT_POS := Vector2(400, 300)
## 根节点相对格底偏移(PlantNormContainer: anchor bottom, offset -20)
const ROOT_TO_CELL_BOTTOM := 20.0

## 干员初始值回退表(JSON 无该干员时使用): 仅 delay/spawn/cd/speed/拖尾/子弹大小
var OPERATOR_GAME_VALUES := {
	"kroos": {"delay": 0.55, "spawn_x": 80.0, "spawn_y": -69.0, "speed": 900.0, "trail_len": 56, "trail_color": [0.7, 0.08, 0.12], "trail_style": 0, "bullet_scale": 1.0},
	"char_124_kroos": {"delay": 0.55, "spawn_x": 80.0, "spawn_y": -69.0, "speed": 900.0, "trail_len": 56, "trail_color": [0.7, 0.08, 0.12], "trail_style": 0, "bullet_scale": 1.0},
	"wisdel": {"delay": 0.6, "spawn_x": 96.0, "spawn_y": -62.0, "cd": 2.1, "speed": 620.0, "trail_len": 64, "trail_color": [0.7, 0.08, 0.12], "trail_style": 0},
	"char_1035_wisdel": {"delay": 0.6, "spawn_x": 96.0, "spawn_y": -62.0, "cd": 2.1, "speed": 620.0, "trail_len": 64, "trail_color": [0.7, 0.08, 0.12], "trail_style": 0},
	"myrtle": {"delay": 0.4, "spawn_x": 60.0, "spawn_y": -40.0, "cd": 1.3, "speed": 600.0},
	"crow": {"delay": 0.4, "spawn_x": 60.0, "spawn_y": -40.0, "cd": 1.3, "speed": 600.0},
	"char_421_crow": {"delay": 0.4, "spawn_x": 60.0, "spawn_y": -40.0, "cd": 1.3, "speed": 600.0},
}
const DEFAULT_GAME_VALUES := {"delay": 0.55, "spawn_x": 30.0, "spawn_y": -50.0, "cd": 1.0, "speed": 300.0, "trail_len": 56, "trail_color": [0.7, 0.08, 0.12], "trail_style": 0, "bullet_scale": 1.0}

## 扫描到的干员定义: [{id, skel, atlas, display_name}]
var _operator_defs: Array[Dictionary] = []
## 当前干员 id（= 素材文件夹名 = JSON 键）
var _operator_id := ""
## 当前攻击动画时长（限制延迟滑块上限）
var _attack_duration := 1.0
## 攻击间隔(自动循环用, 秒)
var _attack_cd := 1.0

## 当前校准值(仅干员独有)
var _delay := 0.55
var _spawn := Vector2(30, -50)
## 子弹速度(该干员子弹场景的 speed, 校准用)
var _bullet_speed := 300.0
## 拖尾参数(写入 JSON, 游戏运行时应用到子弹 Trail): 长度点数/主色/样式(0双层 1单层 2发光)/宽度
var _trail_len := 56
var _trail_color := Color(0.7, 0.08, 0.12)
var _trail_style := 0
var _trail_width := 8.0
## 子弹大小缩放(BulletBody.scale; 无子弹素材的干员如维什戴尔不可设置)
var _bullet_scale := 1.0

## 当前干员的攻击模式列表(从注册表 OperatorAttackModes 读取, 未登记时仅"普通")
var _attack_modes: Array[Dictionary] = []
## 当前攻击模式索引(对应 _attack_modes)
var _attack_mode := 0
## 测试僵尸靶子(模拟僵尸最小接口, 供 速度0直接命中/魂灵射线/爆炸特效 测试)
var _target_root: Node2D
var _targets: Array[Node2D] = []
var _option_attack_mode: OptionButton

## 全干员共用配置(JSON _shared, 所有干员一样)
var _shared_container_y := 20.0
var _shared_spine_x := 0.0
var _shared_spine_y := 0.0
var _shared_scale := 0.33
## 血条/经验条(同长同宽): 长度 / 宽度 / 血条中心Y(相对根, 经验条在其下紧贴)
var _shared_bar_len := 85.0
var _shared_bar_w := 4.0
var _shared_bar_y := -7.0

## 控件引用
var _op_option: OptionButton
var _auto_check: CheckButton
var _slider_delay: HSlider
var _slider_spawn_x: HSlider
var _slider_spawn_y: HSlider
var _slider_speed: HSlider
var _slider_trail_len: HSlider
var _slider_trail_width: HSlider
var _slider_bullet_scale: HSlider
var _color_picker_trail: ColorPickerButton
var _option_style: OptionButton
var _slider_container_y: HSlider
var _slider_spine_x: HSlider
var _slider_spine_y: HSlider
var _slider_scale: HSlider
var _slider_bar_len: HSlider
var _slider_bar_w: HSlider
var _slider_bar_y: HSlider
var _label_values: Array[Label] = []
var _label_info: Label
var _loop_timer: Timer

## 攻击轮次号: 切换干员时 +1, 使挂起的攻击协程失效
var _attack_seq := 0

## 粘性消息(错误/应用结果等), 非空时优先显示, 不被每帧实时信息覆盖
var _sticky_msg := ""

@onready var op_spine: OperatorSpineSprite = $OpSpine
@onready var bullets: Node2D = $Bullets

func _ready() -> void:
	queue_redraw()
	_target_root = Node2D.new()
	_target_root.name = "Targets"
	add_child(_target_root)
	_build_ui()
	_discover_operators()
	if _operator_defs.is_empty():
		_sticky_msg = "未在 assets/image/operator/ 下发现干员素材（skel+atlas）"
		_label_info.text = _sticky_msg
		return
	var default_index := 0
	for i in _operator_defs.size():
		if _operator_defs[i].id == "kroos" or _operator_defs[i].id == "char_124_kroos":
			default_index = i
			break
	_op_option.select(default_index)
	_load_operator(default_index)

func _process(_delta: float) -> void:
	## 清理飞出屏幕的箭矢
	for b in bullets.get_children():
		if b.global_position.x > 1500.0 or b.global_position.x < -300.0:
			b.queue_free()
	## 实时信息
	if _label_info != null and op_spine.is_data_loaded:
		var state: Object = op_spine.get_animation_state()
		var te: Object = null
		var anim_name := "-"
		var anim_time := 0.0
		if state != null:
			te = state.get_current(0)
		if te != null:
			var anim: Object = te.get_animation()
			if anim != null:
				anim_name = anim.get_name()
			anim_time = te.get_animation_time()
		_label_info.text = "干员: %s\n动画: %s  时间: %.2fs/%s\n延迟 %.2f | 发射点(%d, %d) | 速度 %.0f | 拖尾 长%d #%s 样式%d | 大小 %.2f | 容器Y %.0f Spine(%d, %d) 缩放 %.2f" % [
			_operator_id, anim_name, anim_time, _attack_duration,
			_delay, int(_spawn.x), int(_spawn.y), _bullet_speed,
			_trail_len, _trail_color.to_html(), _trail_style, _bullet_scale,
			_shared_container_y, int(_shared_spine_x), int(_shared_spine_y), _shared_scale]
		if not _sticky_msg.is_empty():
			_label_info.text = _sticky_msg + "\n" + _label_info.text

func _draw() -> void:
	## 格子参考框(76x95)与地面线(格底)
	var cell_size := Vector2(76, 95)
	var cell_bottom: float = ROOT_POS.y + ROOT_TO_CELL_BOTTOM
	var cell_rect := Rect2(ROOT_POS.x - cell_size.x / 2.0, cell_bottom - cell_size.y, cell_size.x, cell_size.y)
	draw_rect(cell_rect, Color(1, 1, 1, 0.15), false, 1.5)
	draw_line(Vector2(cell_rect.position.x - 12, cell_bottom), Vector2(cell_rect.end.x + 12, cell_bottom), Color(1, 1, 1, 0.6), 1.5)
	## 根节点标记
	draw_circle(ROOT_POS, 3, Color(1, 0.6, 0.2, 0.9))
	draw_string(ThemeDB.fallback_font, ROOT_POS + Vector2(8, -8), "根节点(影子位置)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
	## 发射点标记(十字 + 圆圈), 点击画面可设置
	var spawn_pos := ROOT_POS + _spawn
	draw_line(spawn_pos + Vector2(-8, 0), spawn_pos + Vector2(8, 0), Color(1, 0.3, 0.3, 0.95), 2.0)
	draw_line(spawn_pos + Vector2(0, -8), spawn_pos + Vector2(0, 8), Color(1, 0.3, 0.3, 0.95), 2.0)
	draw_arc(spawn_pos, 10, 0, TAU, 24, Color(1, 0.3, 0.3, 0.5), 1.0)
	draw_string(ThemeDB.fallback_font, spawn_pos + Vector2(10, 20), "发射点(点击设置)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.5, 0.5, 0.9))
	## 血条/经验条预览(按校准参数; 血条上=青蓝 #6ebee4, 经验条下=鲜绿 #9db04c, 同长同宽, 贴底边)
	var bar_len := _shared_bar_len
	var bar_w := _shared_bar_w
	var hp_y: float = ROOT_POS.y + _shared_bar_y
	var exp_y: float = hp_y + bar_w
	draw_rect(Rect2(ROOT_POS.x - bar_len * 0.5, hp_y - bar_w * 0.5, bar_len, bar_w), Color(0.43, 0.745, 0.894, 1))
	draw_rect(Rect2(ROOT_POS.x - bar_len * 0.5, exp_y - bar_w * 0.5, bar_len, bar_w), Color(0.616, 0.69, 0.298, 1))

## 点击画面: 直接设置发射点
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_spawn_point((event as InputEventMouseButton).position)

func _set_spawn_point(global_pos: Vector2) -> void:
	_spawn = global_pos - ROOT_POS
	_slider_spawn_x.value = _spawn.x
	_slider_spawn_y.value = _spawn.y
	queue_redraw()

#region 干员发现与加载
## 素材文件夹 id(如 kroos/wisdel) → 注册表 PlantType(按 PlantName 小写匹配; 未匹配返回 Null)
func _get_operator_plant_type(folder_id: String) -> CharacterRegistry.PlantType:
	for plant_type in CharacterRegistry.OperatorPlantType:
		var name: String = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)
		if str(name).to_lower() == folder_id.to_lower():
			return plant_type
	return CharacterRegistry.PlantType.Null

## 干员显示名(注册表 OperatorDisplayName; 未登记显示文件夹名)
func _get_operator_display_name(folder_id: String) -> String:
	var plant_type := _get_operator_plant_type(folder_id)
	if plant_type != CharacterRegistry.PlantType.Null:
		var dn: String = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.OperatorDisplayName)
		if not dn.is_empty():
			return dn
	return folder_id

## 干员攻击子弹场景(注册表 OperatorBulletScene; 未登记回退克洛丝箭矢)
func _get_operator_bullet_scene(folder_id: String) -> PackedScene:
	var plant_type := _get_operator_plant_type(folder_id)
	if plant_type != CharacterRegistry.PlantType.Null:
		var scene: PackedScene = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.OperatorBulletScene)
		if scene != null:
			return scene
	return ARROW_SCENE

## 干员攻击动画候选名(注册表 OperatorAttackAnims; 未登记默认 ["Attack"])
func _get_operator_attack_anims(folder_id: String) -> Array[String]:
	var plant_type := _get_operator_plant_type(folder_id)
	if plant_type != CharacterRegistry.PlantType.Null:
		var anims: Array = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.OperatorAttackAnims)
		if anims is Array and not anims.is_empty():
			var result: Array[String] = []
			for a in anims:
				result.append(str(a))
			return result
	return ["Attack"]

## 干员攻击模式列表(注册表 OperatorAttackModes; 未登记仅"普通")
## 模式字段: name 显示名 / count 发射数 / mult 伤害倍率 / is_skill3 是否三技能爆炸(樱桃特效)
func _get_operator_attack_modes(folder_id: String) -> Array[Dictionary]:
	var plant_type := _get_operator_plant_type(folder_id)
	if plant_type != CharacterRegistry.PlantType.Null:
		var modes: Dictionary = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.OperatorAttackModes)
		if modes is Dictionary and not modes.is_empty():
			var result: Array[Dictionary] = []
			for mode_name: String in modes:
				var p: Dictionary = modes[mode_name]
				result.append({
					"name": mode_name,
					"count": int(p.get("count", 1)),
					"mult": float(p.get("mult", 1.0)),
					"is_skill3": bool(p.get("is_skill3", false)),
				})
			return result
	return [{"name": "普通", "count": 1, "mult": 1.0, "is_skill3": false}]

func _discover_operators() -> void:
	var root_dir := DirAccess.open("res://assets/image/operator")
	if root_dir == null:
		return
	for entry in root_dir.get_directories():
		var folder := "res://assets/image/operator/%s" % entry
		var d := DirAccess.open(folder)
		if d == null:
			continue
		## 选 skel: 排除 build_ 基建与 mini 测试, 按字母取第一个(char_xxx 优先)
		var skel_files: Array[String] = []
		for f in d.get_files():
			if f.ends_with(".skel") and not f.begins_with("build_") and f != "mini.skel":
				skel_files.append(f)
		skel_files.sort()
		if skel_files.is_empty():
			continue
		var skel_name := skel_files[0]
		var base := skel_name.get_basename()
		if not FileAccess.file_exists("%s/%s.atlas" % [folder, base]):
			continue
		_operator_defs.append({
			"id": entry,
			"skel": "%s/%s" % [folder, skel_name],
			"atlas": "%s/%s.atlas" % [folder, base],
			"display_name": _get_operator_display_name(entry),
		})
	## 填充下拉选项
	for i in _operator_defs.size():
		_op_option.add_item(_operator_defs[i].display_name, i)

func _on_operator_selected(index: int) -> void:
	_load_operator(index)

func _load_operator(index: int) -> void:
	if index < 0 or index >= _operator_defs.size():
		return
	var def := _operator_defs[index]
	_operator_id = def.id
	## 切换干员: 强制关闭自动循环, 并作废挂起的攻击协程
	_attack_seq += 1
	if is_instance_valid(_auto_check):
		_auto_check.button_pressed = false
	if is_instance_valid(_loop_timer):
		_loop_timer.stop()
	## 切换素材
	op_spine.skeleton_data_res = null
	op_spine.is_data_loaded = false
	op_spine.skel_path = def.skel
	op_spine.atlas_path = def.atlas
	## 按干员设置攻击动画候选(注册表 OperatorAttackAnims, 未登记默认 ["Attack"])
	op_spine.attack_anim_names = _get_operator_attack_anims(_operator_id)
	op_spine.load_data()
	if not op_spine.is_data_loaded:
		_sticky_msg = "加载失败: %s" % def.skel
		_label_info.text = _sticky_msg
		return
	## 读取该干员的校准值(JSON; 无则回退登记表)
	var values: Dictionary = _read_calibration()
	var values_source := "JSON"
	if values.is_empty():
		values = OPERATOR_GAME_VALUES.get(_operator_id, DEFAULT_GAME_VALUES)
		values_source = "登记表(JSON无此干员)"
	_delay = values.get("delay", DEFAULT_GAME_VALUES.delay)
	_spawn = Vector2(values.get("spawn_x", 30.0), values.get("spawn_y", -50.0))
	_attack_cd = values.get("cd", 1.0)
	_bullet_speed = values.get("speed", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("speed", DEFAULT_GAME_VALUES.speed))
	## 拖尾参数(长度/颜色/样式)与子弹大小(JSON 无则回退登记表)
	_trail_len = int(values.get("trail_len", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("trail_len", DEFAULT_GAME_VALUES.trail_len)))
	_trail_style = int(values.get("trail_style", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("trail_style", 0)))
	_trail_width = float(values.get("trail_width", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("trail_width", 8.0)))
	_bullet_scale = float(values.get("bullet_scale", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("bullet_scale", DEFAULT_GAME_VALUES.bullet_scale)))
	var tc: Variant = values.get("trail_color", OPERATOR_GAME_VALUES.get(_operator_id, {}).get("trail_color", DEFAULT_GAME_VALUES.trail_color))
	if tc is Array and tc.size() >= 3:
		_trail_color = Color(float(tc[0]), float(tc[1]), float(tc[2]))
	## 读取全干员共用配置(_shared)
	var shared := _read_shared()
	_shared_container_y = shared.get("container_y", 20.0)
	_shared_spine_x = shared.get("spine_x", 0.0)
	_shared_spine_y = shared.get("spine_y", 0.0)
	_shared_scale = shared.get("scale", 0.33)
	_shared_bar_len = shared.get("hp_bar_len", 85.0)
	_shared_bar_w = shared.get("hp_bar_w", 4.0)
	_shared_bar_y = shared.get("hp_bar_y", -7.0)
	print("[干员调试] 加载 %s: 来源=%s | 延迟 %.2f 发射点(%.1f, %.1f) | 共用: 容器Y %.0f Spine(%d, %d) 缩放 %.2f | 血条 长%.0f 宽%.0f Y%.0f | 文件: %s" % [
		_operator_id, values_source, _delay, _spawn.x, _spawn.y,
		_shared_container_y, int(_shared_spine_x), int(_shared_spine_y), _shared_scale,
		_shared_bar_len, _shared_bar_w, _shared_bar_y, JSON_PATH])
	## 同步滑块(用 set_value_no_signal 避免 value_changed 级联把未同步的变量覆盖回默认值)
	_slider_delay.set_value_no_signal(_delay)
	_slider_spawn_x.set_value_no_signal(_spawn.x)
	_slider_spawn_y.set_value_no_signal(_spawn.y)
	_slider_speed.set_value_no_signal(_bullet_speed)
	_slider_trail_len.set_value_no_signal(_trail_len)
	_slider_trail_width.set_value_no_signal(_trail_width)
	_slider_bullet_scale.set_value_no_signal(_bullet_scale)
	_color_picker_trail.color = _trail_color
	_option_style.select(_trail_style)
	## 无子弹素材的干员(维什戴尔)禁用子弹大小滑块
	_slider_bullet_scale.editable = not _is_bullet_scale_disabled()
	_slider_container_y.set_value_no_signal(_shared_container_y)
	_slider_spine_x.set_value_no_signal(_shared_spine_x)
	_slider_spine_y.set_value_no_signal(_shared_spine_y)
	_slider_scale.set_value_no_signal(_shared_scale)
	_slider_bar_len.set_value_no_signal(_shared_bar_len)
	_slider_bar_w.set_value_no_signal(_shared_bar_w)
	_slider_bar_y.set_value_no_signal(_shared_bar_y)
	## 攻击模式下拉(注册表 OperatorAttackModes, 新干员无需改工具代码)
	_attack_modes = _get_operator_attack_modes(_operator_id)
	_attack_mode = 0
	if is_instance_valid(_option_attack_mode):
		_option_attack_mode.clear()
		for mode in _attack_modes:
			_option_attack_mode.add_item(mode.name)
		_option_attack_mode.select(0)
	_update_value_labels()
	_apply_position()
	## 测量攻击动画时长(失败不影响界面, 上限保持至少 0.1)
	_measure_attack_duration()
	## 回到待机
	op_spine.play_spine(op_spine.get_anim_name("idle"), true)
	queue_redraw()

## 测量当前干员攻击动画时长, 更新延迟滑块上限(失败时保持 1.0/0.1)
## 攻击动画候选逐个测量取最长(维什戴尔 Attack_A/B/C 时长不同, 上限按最长), 逻辑名经 get_anim_name 映射
func _measure_attack_duration() -> void:
	var duration := 1.0
	if op_spine.is_data_loaded:
		var state: Object = op_spine.get_animation_state()
		if state != null:
			var names: Array[String] = op_spine.attack_anim_names if not op_spine.attack_anim_names.is_empty() \
				else [op_spine.get_anim_name("attack")]
			var measured := 0.0
			for name: String in names:
				op_spine.play_spine(name, false)
				var te: Object = state.get_current(0)
				## 动画名匹配才计入(加载失败时 get_current 可能返回上一个动画, 避免量错)
				if te != null and te.get_animation() != null and te.get_animation().get_name() == name:
					measured = maxf(measured, te.get_animation().get_duration())
			if measured > 0.0:
				duration = measured
	_attack_duration = maxf(duration, 0.1)
	if is_instance_valid(_slider_delay):
		_slider_delay.max_value = _attack_duration
#endregion

#region UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	## 面板放右上角, 避免遮挡左侧的干员; 右锚定并向左生长
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-10, 10)
	layer.add_child(panel)
	## 菜单行数多, 套滚动容器避免超出窗口(高度上限, 超出滚动; 横向禁用)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "干员调试工具"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	## 干员选择
	var op_row := HBoxContainer.new()
	vbox.add_child(op_row)
	op_row.add_child(_make_label("干员:"))
	_op_option = OptionButton.new()
	_op_option.custom_minimum_size = Vector2(160, 0)
	op_row.add_child(_op_option)
	_op_option.item_selected.connect(_on_operator_selected)

	var hint := Label.new()
	hint.text = "提示: 点击画面任意位置 = 直接设置发射点"
	hint.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(hint)

	_slider_delay = _add_slider_row(vbox, "发射延迟(秒)", 0.0, 0.93, 0.55, 0.01)
	_slider_spawn_x = _add_slider_row(vbox, "发射点X", -120.0, 120.0, 30.0, 1.0)
	_slider_spawn_y = _add_slider_row(vbox, "发射点Y", -200.0, 80.0, -50.0, 1.0)
	## 速度 0 = 不生成子弹, 直接对测试僵尸结算伤害(无子弹显示, 直接命中)
	_slider_speed = _add_slider_row(vbox, "子弹速度(0=直接命中)", 0.0, 6000.0, 620.0, 10.0)
	## 攻击模式(仅维什戴尔有效, 其他干员忽略)
	var mode_row := HBoxContainer.new()
	vbox.add_child(mode_row)
	mode_row.add_child(_make_label("攻击模式"))
	_option_attack_mode = OptionButton.new()
	for m in ["普通", "二技能·3连发", "二技能·过载4连发", "三技能·爆炸"]:
		_option_attack_mode.add_item(m)
	_option_attack_mode.select(0)
	_option_attack_mode.custom_minimum_size = Vector2(160, 0)
	mode_row.add_child(_option_attack_mode)
	_option_attack_mode.item_selected.connect(_on_attack_mode_selected)
	_slider_trail_len = _add_slider_row(vbox, "拖尾长度", 0, 120, 56, 1)
	_slider_trail_width = _add_slider_row(vbox, "拖尾大小", 1, 30, 8, 1)
	## 拖尾颜色
	var color_row := HBoxContainer.new()
	vbox.add_child(color_row)
	color_row.add_child(_make_label("拖尾颜色"))
	_color_picker_trail = ColorPickerButton.new()
	_color_picker_trail.color = _trail_color
	_color_picker_trail.custom_minimum_size = Vector2(140, 0)
	color_row.add_child(_color_picker_trail)
	_color_picker_trail.color_changed.connect(_on_trail_color_changed)
	## 拖尾样式
	var style_row := HBoxContainer.new()
	vbox.add_child(style_row)
	style_row.add_child(_make_label("拖尾样式"))
	_option_style = OptionButton.new()
	for s in ["双层亮带", "单层亮带", "发光(加色)"]:
		_option_style.add_item(s)
	_option_style.select(0)
	_option_style.custom_minimum_size = Vector2(140, 0)
	style_row.add_child(_option_style)
	_option_style.item_selected.connect(_on_style_selected)
	_slider_bullet_scale = _add_slider_row(vbox, "子弹大小", 0.1, 2.0, 1.0, 0.05)

	## 共用配置(所有干员一样, 存 JSON _shared)
	var shared_title := Label.new()
	shared_title.text = "— 共用配置(所有干员) —"
	shared_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	vbox.add_child(shared_title)
	_slider_container_y = _add_slider_row(vbox, "容器Y", -30.0, 80.0, 20.0, 1.0)
	_slider_spine_x = _add_slider_row(vbox, "SpineX", -80.0, 80.0, 0.0, 1.0)
	_slider_spine_y = _add_slider_row(vbox, "SpineY", -80.0, 80.0, 0.0, 1.0)
	_slider_scale = _add_slider_row(vbox, "缩放", 0.1, 0.5, 0.33, 0.01)

	## 血条/经验条(同长同宽, 全干员共用)
	var bar_title := Label.new()
	bar_title.text = "— 血条/经验条(共用) —"
	bar_title.add_theme_color_override("font_color", Color(0.85, 1, 0.75))
	vbox.add_child(bar_title)
	_slider_bar_len = _add_slider_row(vbox, "条长度", 30.0, 150.0, 85.0, 1.0)
	_slider_bar_w = _add_slider_row(vbox, "条宽度", 2.0, 10.0, 4.0, 0.5)
	_slider_bar_y = _add_slider_row(vbox, "条位置Y", -30.0, 20.0, -7.0, 1.0)

	## 自动循环
	_auto_check = CheckButton.new()
	_auto_check.text = "自动循环攻击"
	_auto_check.toggled.connect(_on_auto_toggled)
	vbox.add_child(_auto_check)
	## 按钮行1: 攻击 / 测试僵尸 / 魂灵
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var attack_btn := Button.new()
	attack_btn.text = "攻击一次"
	attack_btn.pressed.connect(_attack_once)
	btn_row.add_child(attack_btn)
	var spawn_btn := Button.new()
	spawn_btn.text = "生成测试僵尸"
	spawn_btn.pressed.connect(_spawn_test_zombie)
	btn_row.add_child(spawn_btn)
	var clear_btn := Button.new()
	clear_btn.text = "清除僵尸"
	clear_btn.pressed.connect(_clear_targets)
	btn_row.add_child(clear_btn)
	var shadow_btn := Button.new()
	shadow_btn.text = "魂灵攻击"
	shadow_btn.pressed.connect(_shadow_attack)
	btn_row.add_child(shadow_btn)
	## 按钮行2: 应用 / 复制 / 重置
	var btn_row2 := HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row2)
	var apply_btn := Button.new()
	apply_btn.text = "应用(写入JSON)"
	apply_btn.pressed.connect(_apply_values)
	btn_row2.add_child(apply_btn)
	var copy_btn := Button.new()
	copy_btn.text = "复制结果"
	copy_btn.pressed.connect(_copy_result)
	btn_row2.add_child(copy_btn)
	var reset_btn := Button.new()
	reset_btn.text = "重置当前干员"
	reset_btn.pressed.connect(_reset_current)
	btn_row2.add_child(reset_btn)

	_label_info = Label.new()
	_label_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label_info)

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(110, 0)
	return label

func _add_slider_row(parent: Node, text: String, min_v: float, max_v: float, def_v: float, step_v: float) -> HSlider:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)
	hbox.add_child(_make_label(text))
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = def_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)
	_label_values.append(value_label)
	slider.value_changed.connect(_on_slider_changed)
	return slider

func _on_slider_changed(_v: float) -> void:
	## 用户拖动滑块后清除粘性消息
	_sticky_msg = ""
	_delay = _slider_delay.value
	_spawn = Vector2(_slider_spawn_x.value, _slider_spawn_y.value)
	_bullet_speed = _slider_speed.value
	_trail_len = int(_slider_trail_len.value)
	_trail_width = _slider_trail_width.value
	_bullet_scale = _slider_bullet_scale.value
	_shared_container_y = _slider_container_y.value
	_shared_spine_x = _slider_spine_x.value
	_shared_spine_y = _slider_spine_y.value
	_shared_scale = _slider_scale.value
	_shared_bar_len = _slider_bar_len.value
	_shared_bar_w = _slider_bar_w.value
	_shared_bar_y = _slider_bar_y.value
	_update_value_labels()
	_apply_position()
	queue_redraw()

## 拖尾颜色变更
func _on_trail_color_changed(color: Color) -> void:
	_sticky_msg = ""
	_trail_color = color

## 拖尾样式变更(0双层 1单层 2发光)
func _on_style_selected(index: int) -> void:
	_sticky_msg = ""
	_trail_style = index

## 攻击模式变更(索引对应注册表 OperatorAttackModes 列表)
func _on_attack_mode_selected(index: int) -> void:
	_sticky_msg = ""
	_attack_mode = index

## 无子弹素材的干员(炮弹无可视本体, 如维什戴尔用拖尾代替炮弹)禁用子弹大小滑块
## 通用判断: 实例化该干员炮弹, 检查是否有 Body/BulletBody 节点
func _is_bullet_scale_disabled() -> bool:
	var shell: Bullet000Base = _instantiate_shell()
	var body: Node = shell.get_node_or_null("Body/BulletBody")
	shell.free()
	return not is_instance_valid(body)

func _update_value_labels() -> void:
	var texts := [_delay, int(_spawn.x), int(_spawn.y), _bullet_speed,
		_trail_len, _trail_width, _bullet_scale,
		int(_shared_container_y), int(_shared_spine_x), int(_shared_spine_y), _shared_scale,
		int(_shared_bar_len), _shared_bar_w, int(_shared_bar_y)]
	for i in _label_values.size():
		_label_values[i].text = str(texts[i])

func _apply_position() -> void:
	## 工具里没有"基类容器"节点, OpSpine 原点即角色脚部:
	## 脚部 = 根节点 + 容器Y + Spine节点y; 缩放 = 共用配置
	op_spine.position = ROOT_POS + Vector2(_shared_spine_x, _shared_container_y + _shared_spine_y)
	op_spine.scale = Vector2.ONE * _shared_scale

func _reset_current() -> void:
	## 重置为 JSON 中的当前数值(重新读取)
	_load_operator(_op_option.selected)
#endregion

#region 攻击
func _on_auto_toggled(pressed: bool) -> void:
	if pressed:
		_loop_timer = Timer.new()
		_loop_timer.wait_time = _attack_cd
		_loop_timer.autostart = true
		_loop_timer.timeout.connect(_attack_once)
		add_child(_loop_timer)
	elif is_instance_valid(_loop_timer):
		_loop_timer.queue_free()
		_loop_timer = null

func _attack_once() -> void:
	var seq := _attack_seq
	if is_instance_valid(op_spine) and op_spine.is_data_loaded:
		op_spine.play_spine_sequence(op_spine.get_anim_name("attack"), op_spine.get_anim_name("idle"))
	if _delay > 0.0:
		await get_tree().create_timer(_delay).timeout
		## 等待期间切换了干员则取消本次攻击
		if seq != _attack_seq:
			return
	_shoot_attack()

## 按当前攻击模式发射/结算(模式数据来自注册表 OperatorAttackModes)
## 速度>0: 生成真实炮弹(多连发分别瞄向测试僵尸); 速度0: 不生成子弹, 直接对测试僵尸结算伤害
func _shoot_attack() -> void:
	var mode: Dictionary = _get_curr_mode()
	var mode_mult: float = mode.mult
	var mode_count: int = mode.count
	if _bullet_speed <= 0.0:
		_direct_hit(mode_mult, mode_count)
		return
	## 正常发射: 多连发分别瞄向测试僵尸, 无靶子时直线朝右
	var targets := _get_live_targets()
	for i in mode_count:
		var shell: Bullet000Base = _instantiate_shell()
		var dir := Vector2.RIGHT
		if i < targets.size():
			dir = (targets[i].global_position - (ROOT_POS + _spawn)).normalized()
		_spawn_shell(shell, dir)

## 当前攻击模式字典(越界/空时回退普通)
func _get_curr_mode() -> Dictionary:
	if _attack_modes.is_empty():
		return {"name": "普通", "count": 1, "mult": 1.0, "is_skill3": false}
	return _attack_modes[clampi(_attack_mode, 0, _attack_modes.size() - 1)]

## 实例化该干员自己的炮弹(注册表 OperatorBulletScene, 未登记回退克洛丝箭矢), 速度用当前校准值
## 炮弹支持溅射参数(如维什戴尔炮弹)时套用当前模式/溅射配置
func _instantiate_shell() -> Bullet000Base:
	var scene: PackedScene = _get_operator_bullet_scene(_operator_id)
	var shell: Bullet000Base = scene.instantiate()
	shell.speed = _bullet_speed
	if shell.has_method("init_splash_paras"):
		shell.call("init_splash_paras", _get_debug_splash_paras())
	return shell

## 发射一颗炮弹并应用拖尾参数与子弹大小(与游戏运行时 OperatorCalibration.apply_to_bullet 一致的本地值)
func _spawn_shell(shell: Bullet000Base, dir: Vector2) -> void:
	var spawn_pos: Vector2 = ROOT_POS + _spawn
	var bullet_paras: Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: -1,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(spawn_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: dir,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: 1,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: 1,
	}
	shell.init_bullet(bullet_paras)
	bullets.add_child(shell)
	var trail: Node = shell.get_node_or_null("Trail")
	if is_instance_valid(trail) and trail.has_method("setup"):
		trail.call("setup", _trail_len, _trail_color, _trail_style, _trail_width)
	var body: Node = shell.get_node_or_null("Body/BulletBody")
	if is_instance_valid(body):
		body.set("scale", Vector2.ONE * _bullet_scale)

## 维什戴尔炮弹溅射参数(与游戏运行时 operator_002_wisdel.gd 的 _get_splash_paras 一致)
func _get_debug_splash_paras() -> Dictionary:
	var p := {
		"splash_radius_px": 1.1 * 76.0,
		"after_shock_mult": 0.5,
		"main_target_mult": 1.25,
		"talent_explode_chance": 0.15,
		"talent_explode_damage": int(round(809.0 * 1.75)),
		"talent_explode_stun": 1.0,
		"stun_time": 0.0,
	}
	if _get_curr_mode().is_skill3:
		p["splash_radius_px"] = 2.5 * 76.0
		p["talent_explode_chance"] = 1.0
		p["is_skill3"] = true
	return p

## 速度0直接命中: 不生成子弹, 直接对测试僵尸结算伤害(主目标×1.25天赋倍率)
func _direct_hit(mult: float, count: int) -> void:
	var targets := _get_live_targets()
	if targets.is_empty():
		_sticky_msg = "速度=0 直接命中需要测试僵尸, 请先点\"生成测试僵尸\""
		_label_info.text = _sticky_msg
		return
	var shell: Bullet000Base = _instantiate_shell()
	var base_damage: int = int(shell.attack_value) if "attack_value" in shell else 809
	var is_skill3: bool = _get_curr_mode().is_skill3
	var hit_count := mini(count, targets.size())
	for i in hit_count:
		var t: Node2D = targets[i]
		var dmg: int = maxi(1, int(round(base_damage * mult * 1.25)))
		if is_skill3:
			## 三技能模式: 樱桃炸弹爆炸伤害(灰烬) + 爆炸特效 + 爆炸音
			if t.has_method("be_bomb"):
				t.call("be_bomb", dmg, true)
			_play_cherry_fx(t)
			SoundManager.play_character_SFX(&"CherryBomb")
		else:
			if t.has_method("be_attacked_bullet"):
				t.call("be_attacked_bullet", dmg, BulletRegistry.AttackMode.Norm, true, true)
	_sticky_msg = "直接命中 %d 发, 单发伤害 %d (模式%d, 速度0)" % [hit_count, maxi(1, int(round(base_damage * mult * 1.25))), _attack_mode]
	_label_info.text = _sticky_msg

## 在目标位置播放樱桃炸弹爆炸特效(与游戏运行时 bullet_102_wisdel_shell 一致)
func _play_cherry_fx(target: Node2D) -> void:
	var fx: Node2D = SceneRegistry.CHERRY_BOMB_EFFECT.instantiate()
	add_child(fx)
	fx.global_position = target.global_position + Vector2(0, -40)
	fx.z_index = 30
	if fx.has_method("activate_bomb_effect"):
		fx.call("activate_bomb_effect")

## 生成测试僵尸靶子(最多3个, 沿发射方向纵向排布)
func _spawn_test_zombie() -> void:
	var live := _get_live_targets()
	if live.size() >= 3:
		_sticky_msg = "测试僵尸最多3个"
		_label_info.text = _sticky_msg
		return
	var t: Node2D = preload("res://test/operator_debug_target.gd").new()
	t.position = ROOT_POS + Vector2(320.0, -50.0 + live.size() * 50.0)
	_target_root.add_child(t)
	_targets.append(t)

## 清除全部测试僵尸
func _clear_targets() -> void:
	for t in _targets:
		if is_instance_valid(t):
			t.queue_free()
	_targets.clear()

## 存活测试僵尸(未死亡)
func _get_live_targets() -> Array[Node2D]:
	var live: Array[Node2D] = []
	for t in _targets:
		if is_instance_valid(t) and not t.is_death:
			live.append(t)
	return live

## 魂灵之影攻击: 从干员位置向最近测试僵尸发射红色射线(命中: 伤害777 + 1秒停顿 + 受击音)
## 魂灵为维什戴尔专属召唤物, 仅维什戴尔可用; 其他干员若以后有召唤物可在此扩展
func _shadow_attack() -> void:
	if not _is_shadow_operator():
		_sticky_msg = "魂灵攻击仅维什戴尔可用"
		_label_info.text = _sticky_msg
		return
	var targets := _get_live_targets()
	if targets.is_empty():
		_sticky_msg = "魂灵攻击需要测试僵尸, 请先点\"生成测试僵尸\""
		_label_info.text = _sticky_msg
		return
	var target: Node2D = targets[0]
	## 从 OpSpine 位置向目标发射线(与 summon_002_wisdel_shadow._fire_beam 一致)
	var beam: Node2D = SceneRegistry.WISDEL_SHADOW_BEAM.instantiate()
	add_child(beam)
	beam.call("fire", op_spine.global_position, target.global_position, 40)
	SoundManager.play_character_SFX(&"ShadowAttack")
	if beam.has_signal("signal_beam_hit"):
		beam.signal_beam_hit.connect(_on_shadow_beam_hit.bind(target), CONNECT_ONE_SHOT)

## 魂灵射线命中帧(回调结算: 伤害 + 1秒停顿, 静默不显示黄油)
func _on_shadow_beam_hit(target: Node2D) -> void:
	if not is_instance_valid(target) or target.is_death:
		return
	SoundManager.play_character_SFX(&"ShadowHit")
	if target.has_method("be_attacked_bullet"):
		target.call("be_attacked_bullet", 777, BulletRegistry.AttackMode.Norm, true, true)
	if target.has_method("be_butter"):
		target.call("be_butter", 1.0, false)

## 当前干员是否维什戴尔(魂灵攻击仅其可用; 素材 id 匹配 wisdel 系列)
func _is_shadow_operator() -> bool:
	return _operator_id == "wisdel" or _operator_id == "char_1035_wisdel"
#endregion

#region 应用(写入 JSON)
## 把当前校准值写入 data/operator_calibration.json(键=干员id + _shared), 游戏运行时读取
func _apply_values() -> void:
	var op_id := _operator_id
	if op_id.is_empty():
		_sticky_msg = "未选择干员"
		_label_info.text = _sticky_msg
		return
	## 读取现有 JSON(保留其他干员条目)
	var data := _load_json()
	data[op_id] = {"delay": _delay, "spawn_x": _spawn.x, "spawn_y": _spawn.y, "speed": _bullet_speed,
		"trail_len": _trail_len, "trail_width": _trail_width,
		"trail_color": [_trail_color.r, _trail_color.g, _trail_color.b],
		"trail_style": _trail_style, "bullet_scale": _bullet_scale}
	data[OperatorCalibration.SHARED_KEY] = {
		"container_y": _shared_container_y,
		"spine_x": _shared_spine_x,
		"spine_y": _shared_spine_y,
		"scale": _shared_scale,
		"hp_bar_len": _shared_bar_len,
		"hp_bar_w": _shared_bar_w,
		"hp_bar_y": _shared_bar_y,
	}
	var out := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if out == null:
		_sticky_msg = "写入失败: %s (%s)" % [JSON_PATH, FileAccess.get_open_error()]
		_label_info.text = _sticky_msg
		return
	out.store_string(JSON.stringify(data, "\t"))
	out.close()
	## 写入后回读校验
	var verify: Dictionary = _load_json().get(op_id, {})
	print("[干员调试] 已写入 %s\n当前: 延迟 %.2f 发射点(%.1f, %.1f) 共用: 容器Y %.0f Spine(%d, %d) 缩放 %.2f | 血条 长%.0f 宽%.0f Y%.0f\n回读: %s" % [
		JSON_PATH, _delay, _spawn.x, _spawn.y,
		_shared_container_y, int(_shared_spine_x), int(_shared_spine_y), _shared_scale,
		_shared_bar_len, _shared_bar_w, _shared_bar_y,
		JSON.stringify(verify, "")])
	## 同步登记表(供"重置"回退使用)
	OPERATOR_GAME_VALUES[op_id] = {"delay": _delay, "spawn_x": _spawn.x, "spawn_y": _spawn.y, "cd": _attack_cd,
		"speed": _bullet_speed, "trail_len": _trail_len, "trail_width": _trail_width,
		"trail_color": [_trail_color.r, _trail_color.g, _trail_color.b],
		"trail_style": _trail_style, "bullet_scale": _bullet_scale}
	_sticky_msg = "已写入 %s\n延迟 %.2f | 发射点(%d, %d) | 速度 %.0f | 拖尾 长%d 色#%s 样式%d | 子弹大小 %.2f | 容器Y %.0f Spine(%d, %d) 缩放 %.2f | 血条 长%.0f 宽%.0f Y%.0f" % [
		JSON_PATH, _delay, int(_spawn.x), int(_spawn.y), _bullet_speed,
		_trail_len, _trail_color.to_html(), _trail_style, _bullet_scale,
		_shared_container_y, int(_shared_spine_x), int(_shared_spine_y), _shared_scale,
		_shared_bar_len, _shared_bar_w, _shared_bar_y]
	if _label_info != null:
		_label_info.text = _sticky_msg

## 读取当前干员在 JSON 中的校准值(无则返回空字典)
func _read_calibration() -> Dictionary:
	var entry: Variant = _load_json().get(_operator_id, {})
	return entry if entry is Dictionary else {}

## 读取全干员共用配置(JSON _shared; 无则返回空, 由调用方用默认值)
func _read_shared() -> Dictionary:
	var entry: Variant = _load_json().get(OperatorCalibration.SHARED_KEY, {})
	return entry if entry is Dictionary else {}

## 读取校准 JSON(不存在/解析失败返回空字典)
func _load_json() -> Dictionary:
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
#endregion

## 复制校准结果(可直接粘贴给开发/填入场景)
func _copy_result() -> void:
	var text := "干员: %s (%s)\n" % [_operator_defs[_op_option.selected].display_name if _op_option.selected >= 0 else "", _operator_id]
	text += "bullet_spawn_delay = %.2f\n" % _delay
	text += "bullet_spawn_offset = Vector2(%.0f, %.0f)\n" % [_spawn.x, _spawn.y]
	text += "bullet_speed = %.0f\n" % _bullet_speed
	text += "拖尾: 长度=%d 颜色=#%s 样式=%d | 子弹大小=%.2f\n" % [_trail_len, _trail_color.to_html(), _trail_style, _bullet_scale]
	text += "共用配置(_shared): 容器Y=%.0f Spine=(%.0f, %.0f) 缩放=%.2f | 血条 长%.0f 宽%.0f Y%.0f" % [
		_shared_container_y, _shared_spine_x, _shared_spine_y, _shared_scale,
		_shared_bar_len, _shared_bar_w, _shared_bar_y]
	DisplayServer.clipboard_set(text)
	_sticky_msg = "已复制到剪贴板:\n" + text
	if _label_info != null:
		_label_info.text = _sticky_msg
