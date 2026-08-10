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
## 新增干员: 在 OPERATOR_NAMES(显示名) 与 OPERATOR_GAME_VALUES(初始值回退) 登记

const ARROW_SCENE := preload("res://scenes/bullet/bullet_101_kroos_arrow.tscn")
## 校准数据文件(键=干员id, 游戏运行时读取)
const JSON_PATH := "res://data/operator_calibration.json"

## 参考点: 模拟植物根节点位置(游戏内即 PlantNormContainer 全局位置)
const ROOT_POS := Vector2(400, 300)
## 根节点相对格底偏移(PlantNormContainer: anchor bottom, offset -20)
const ROOT_TO_CELL_BOTTOM := 20.0

## 干员显示名映射（未登记的显示文件夹名）
const OPERATOR_NAMES := {
	"kroos": "克洛丝",
	"char_124_kroos": "克洛丝",
}

## 干员初始值回退表(JSON 无该干员时使用): 仅 delay/spawn
var OPERATOR_GAME_VALUES := {
	"kroos": {"delay": 0.55, "spawn_x": 80.0, "spawn_y": -69.0},
	"char_124_kroos": {"delay": 0.55, "spawn_x": 80.0, "spawn_y": -69.0},
}
const DEFAULT_GAME_VALUES := {"delay": 0.55, "spawn_x": 30.0, "spawn_y": -50.0, "cd": 1.0}

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
		_label_info.text = "干员: %s\n动画: %s  时间: %.2fs/%s\n延迟 %.2f | 发射点(%d, %d) | 容器Y %.0f Spine(%d, %d) 缩放 %.2f" % [
			_operator_id, anim_name, anim_time, _attack_duration,
			_delay, int(_spawn.x), int(_spawn.y),
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
			"display_name": OPERATOR_NAMES.get(entry, entry),
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
	_slider_container_y.set_value_no_signal(_shared_container_y)
	_slider_spine_x.set_value_no_signal(_shared_spine_x)
	_slider_spine_y.set_value_no_signal(_shared_spine_y)
	_slider_scale.set_value_no_signal(_shared_scale)
	_slider_bar_len.set_value_no_signal(_shared_bar_len)
	_slider_bar_w.set_value_no_signal(_shared_bar_w)
	_slider_bar_y.set_value_no_signal(_shared_bar_y)
	_update_value_labels()
	_apply_position()
	## 测量攻击动画时长(失败不影响界面, 上限保持至少 0.1)
	_measure_attack_duration()
	## 回到待机
	op_spine.play_spine("Idle", true)
	queue_redraw()

## 测量当前干员攻击动画时长, 更新延迟滑块上限(失败时保持 1.0/0.1)
func _measure_attack_duration() -> void:
	var duration := 1.0
	if op_spine.is_data_loaded:
		var state: Object = op_spine.get_animation_state()
		if state != null:
			op_spine.play_spine("Attack", false)
			var te: Object = state.get_current(0)
			if te != null and te.get_animation() != null:
				duration = te.get_animation().get_duration()
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
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
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
	## 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var attack_btn := Button.new()
	attack_btn.text = "攻击一次"
	attack_btn.pressed.connect(_attack_once)
	btn_row.add_child(attack_btn)
	var apply_btn := Button.new()
	apply_btn.text = "应用(写入JSON)"
	apply_btn.pressed.connect(_apply_values)
	btn_row.add_child(apply_btn)
	var copy_btn := Button.new()
	copy_btn.text = "复制结果"
	copy_btn.pressed.connect(_copy_result)
	btn_row.add_child(copy_btn)
	var reset_btn := Button.new()
	reset_btn.text = "重置当前干员"
	reset_btn.pressed.connect(_reset_current)
	btn_row.add_child(reset_btn)

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

func _update_value_labels() -> void:
	var texts := [_delay, int(_spawn.x), int(_spawn.y),
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
		op_spine.play_spine_sequence("Attack", "Idle")
	if _delay > 0.0:
		await get_tree().create_timer(_delay).timeout
		## 等待期间切换了干员则取消本次攻击
		if seq != _attack_seq:
			return
	_shoot_arrow()

func _shoot_arrow() -> void:
	var bullet: Bullet000Base = ARROW_SCENE.instantiate()
	var spawn_pos: Vector2 = ROOT_POS + _spawn
	var bullet_paras: Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: -1,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(spawn_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: 1,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: 1,
	}
	bullet.init_bullet(bullet_paras)
	bullets.add_child(bullet)
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
	data[op_id] = {"delay": _delay, "spawn_x": _spawn.x, "spawn_y": _spawn.y}
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
	OPERATOR_GAME_VALUES[op_id] = {"delay": _delay, "spawn_x": _spawn.x, "spawn_y": _spawn.y, "cd": _attack_cd}
	_sticky_msg = "已写入 %s\n延迟 %.2f | 发射点(%d, %d) | 容器Y %.0f Spine(%d, %d) 缩放 %.2f | 血条 长%.0f 宽%.0f Y%.0f" % [
		JSON_PATH, _delay, int(_spawn.x), int(_spawn.y),
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
	text += "共用配置(_shared): 容器Y=%.0f Spine=(%.0f, %.0f) 缩放=%.2f | 血条 长%.0f 宽%.0f Y%.0f" % [
		_shared_container_y, _shared_spine_x, _shared_spine_y, _shared_scale,
		_shared_bar_len, _shared_bar_w, _shared_bar_y]
	DisplayServer.clipboard_set(text)
	_sticky_msg = "已复制到剪贴板:\n" + text
	if _label_info != null:
		_label_info.text = _sticky_msg
