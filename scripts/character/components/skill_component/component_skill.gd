extends ComponentNormBase
class_name SkillComponent
## 干员技能组件
## 管理技能点(SP)与技能条UI, 支持 攻击回复/时间回复, 自动触发/手动触发
## 技能条显示在干员头顶(HP条上方), 常显
## 技能条三种状态:
## - 普通(未激活): 绿色条 = 当前SP/上限
## - 持续技能激活(如维什戴尔二技能): 满格橙色条, 随时间持续减少, 减到0技能结束
## - 弹药技能激活(如维什戴尔三技能6发): 分成 N 个橙色小格, 每发弹药消耗一格

## 技能点回复方式
enum E_SpRecoveryType{
	Attack,		## 攻击回复: 每次攻击获得技能点
	Time,		## 时间回复: 随时间自动回复
	None,		## 无回复(手动/其他方式回复)
}

## 技能条填充色(普通绿色 / 持续技能前段橙色 / 持续技能过载深红 / 弹药技能橙色)
const COLOR_BAR_NORMAL := Color(0.616, 0.69, 0.298)
const COLOR_BAR_SUSTAIN := Color("#da9108")  ## 维什戴尔二技能前段
const COLOR_BAR_OVERLOAD := Color("#bd3f00")  ## 维什戴尔二技能过载
const COLOR_BAR_ACTIVE := Color(1.0, 0.62, 0.12)  ## 弹药/其他激活色

@onready var progress_bar_skill: ProgressBar = %ProgressBarSkill
@onready var label_skill: Label = %LabelSkill

## 技能需要技能点(技能条上限)
@export var max_sp:int = 5
## 部署时初始技能点(方舟"初始技力", 如维什戴尔三技能初始40/二技能初始15)
@export var initial_sp:int = 0
## 每次攻击获得技能点(攻击回复)
@export var sp_gain_per_attack:int = 1
## 每秒回复技能点(时间回复)
@export var sp_regen_per_sec:float = 1.0
## 技能点回复方式
@export var sp_recovery_type:E_SpRecoveryType = E_SpRecoveryType.Attack
## 技能就绪后是否自动触发
@export var is_auto_trigger:bool = true
## 是否为持续技能(激活期间技能条显示橙色倒计时条, 减到0自动结束)
@export var is_sustain_skill := false
## 自动触发前的额外条件(返回 true 才触发; 如召唤物需等目标进入范围再释放)。
## 未设置(无效 Callable)视为恒真; 设置后技能满会"攒着"SP 不消耗, 每帧重试直到条件满足
var auto_trigger_check: Callable = Callable()

## 当前技能点(浮点累计, 时间回复每帧平滑增长, 技能条恢复更自然)
var curr_sp:float = 0.0
## 技能是否就绪
var is_skill_ready:bool = false
## 技能是否激活中(持续技能: 激活中再次触发=提前关闭; 弹药技能: 弹药耗尽结束)
var is_skill_active := false
## 持续技能是否处于"过载"阶段(如维什戴尔二技能后段; 技能条颜色切换为过载色)
var is_overload := false
## 持续技能总时长/剩余时间(秒)
var skill_max_duration := 0.0
var skill_time_left := 0.0
## 过载段时长(秒, 0=无过载): 过载时技能条按此时长"重新充满"倒计时(如维什戴尔二技能后12.5s)
var overload_duration := 0.0
## 弹药技能总弹药/剩余弹药
var skill_ammo_max := 0
var skill_ammo_left := 0
## 一次性多连发技能条(橙色倒计时): 非 is_skill_active, 不阻断攻击回复SP
var burst_active := false
var burst_time_left := 0.0
var burst_duration := 0.0

## 弹药格 UI(运行时创建, 弹药技能激活时显示)
var ammo_box: HBoxContainer
var ammo_cells: Array[ColorRect] = []

## 技能点变化信号
signal signal_sp_change(curr_sp:float, max_sp:int)
## 技能就绪信号
signal signal_skill_ready
## 技能被使用(触发)信号
signal signal_skill_use
## 技能结束信号(提前关闭/计时结束/弹药耗尽, 见 end_skill)
signal signal_skill_ended

var _style_fill_normal: StyleBox
var _style_fill_sustain: StyleBox
var _style_fill_overload: StyleBox

func _ready() -> void:
	super()
	curr_sp = mini(initial_sp, max_sp)
	update_skill_bar()
	if curr_sp >= max_sp:
		is_skill_ready = true
		signal_skill_ready.emit()
		## 自动触发技能(有 auto_trigger_check 时检查不通过则攒着)
		_try_auto_trigger()

## 创建弹药格 UI(与技能条同锚点布局, 完全对齐)
func _setup_ammo_ui():
	if not is_instance_valid(progress_bar_skill) or ammo_box != null:
		return
	ammo_box = HBoxContainer.new()
	ammo_box.name = "AmmoBox"
	ammo_box.visible = false
	ammo_box.z_index = 20
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_box.add_theme_constant_override("separation", 2)
	## 与技能条(ProgressBarSkill)相同锚点(居中)与偏移, 避免手动 position 错位
	ammo_box.set_anchors_preset(Control.PRESET_CENTER)
	ammo_box.offset_left = progress_bar_skill.offset_left
	ammo_box.offset_top = progress_bar_skill.offset_top
	ammo_box.offset_right = progress_bar_skill.offset_right
	ammo_box.offset_bottom = progress_bar_skill.offset_bottom
	ammo_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	progress_bar_skill.get_parent().add_child(ammo_box)

## 按弹药数重建格子(三技能6发 → 6格)
func _rebuild_ammo_cells(count: int):
	_setup_ammo_ui()
	for cell in ammo_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	ammo_cells.clear()
	if count <= 0:
		return
	var cell_w := (progress_bar_skill.size.x - (count - 1) * 2.0) / count
	for i in count:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(cell_w, progress_bar_skill.size.y)
		cell.size = Vector2(cell_w, progress_bar_skill.size.y)
		cell.color = Color(0.3, 0.25, 0.15, 1.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_box.add_child(cell)
		ammo_cells.append(cell)

## 更新弹药格亮暗(从左向右消耗: 已发射的弹药, 最左格先灭, 用完的格子连在左端)
func _update_ammo_cells():
	if ammo_box == null:
		return
	var consumed := skill_ammo_max - skill_ammo_left
	for i in ammo_cells.size():
		var cell := ammo_cells[i]
		if not is_instance_valid(cell):
			continue
		## i=0 最左, i=size-1 最右; 最左 consumed 个格子熄灭(用完连在左端)
		cell.color = COLOR_BAR_ACTIVE if i >= consumed else Color(0.3, 0.25, 0.15, 1.0)

## 增加技能点(攻击回复/时间回复逐帧小数或外部调用)
func add_sp(value:float):
	## 技能激活中/多连发橙条倒计时期间不回复技能点(技能期间的本次攻击不计入技力)
	if is_skill_ready or is_skill_active or burst_active:
		return
	curr_sp = minf(curr_sp + value, float(max_sp))
	update_skill_bar()
	if curr_sp >= max_sp:
		is_skill_ready = true
		signal_skill_ready.emit()
		## 自动触发技能(有 auto_trigger_check 时检查不通过则攒着)
		_try_auto_trigger()

func _process(delta: float) -> void:
	## 技能就绪且自动触发: 持续重试触发条件(如召唤物等目标进入范围), 满足即释放
	_try_auto_trigger()
	## 一次性多连发橙色技能条: 随时间耗尽为0(不阻断攻击回复SP)
	if burst_active:
		burst_time_left -= delta
		if burst_time_left <= 0.0:
			burst_time_left = 0.0
			burst_active = false
			burst_duration = 0.0
		update_skill_bar()
		return
	## 持续技能激活: 倒计时递减, 减到0自动结束; 若设置过载段, 则前段耗尽后进入过载并重置时间
	if is_skill_active and is_sustain_skill:
		skill_time_left -= delta
		if skill_time_left <= 0.0:
			if not is_overload and overload_duration > 0.0:
				is_overload = true
				skill_time_left = overload_duration
			else:
				skill_time_left = 0.0
				end_skill()
		update_skill_bar()
		return
	## 技能激活(弹药/一次性)期间不回复SP
	if is_skill_active:
		return
	## 时间回复(自动回复): 每帧按浮点累加, 技能条平滑增长
	if sp_recovery_type == E_SpRecoveryType.Time and not is_skill_ready and sp_regen_per_sec > 0:
		add_sp(delta * sp_regen_per_sec)

## 技能就绪且自动触发时尝试释放: 通过 auto_trigger_check 才真正触发
## (技能满后范围内无目标等场景: 检查不通过则"攒着"SP 不消耗, 由 _process 每帧重试直到有目标)
func _try_auto_trigger() -> void:
	if not is_skill_ready or not is_auto_trigger:
		return
	if auto_trigger_check.is_valid() and not auto_trigger_check.call():
		return
	use_skill()

## 使用技能: 技能激活中再次触发 = 提前关闭; 技能就绪时触发并返回true
func use_skill()->bool:
	## 激活中再次触发: 提前关闭(不消耗SP, 见维什戴尔二/三技能"可随时停止")
	if is_skill_active:
		end_skill()
		return true
	if not is_skill_ready:
		return false
	is_skill_ready = false
	curr_sp = 0.0
	update_skill_bar()
	signal_skill_use.emit()
	return true

## 开始持续技能(干员技能开启时调用): 技能条变橙色满条并随时间减少
func start_sustain(duration: float):
	is_skill_active = true
	is_sustain_skill = true
	skill_max_duration = duration
	skill_time_left = duration
	update_skill_bar()

## 开始弹药技能(干员技能开启时调用): 技能条分成 N 个橙色小格
func start_ammo(ammo: int):
	is_skill_active = true
	is_sustain_skill = false
	skill_ammo_max = ammo
	skill_ammo_left = ammo
	_rebuild_ammo_cells(ammo)
	update_skill_bar()

## 开始一次性橙色技能条(多连发技能): 技能条变橙色满条, 在 duration 秒内逐渐耗尽为0
## 注意: 不设置 is_skill_active, 因此攻击回复SP照常结算(克洛丝/羽毛笔二连发用)
func start_burst_bar(duration: float):
	burst_active = true
	burst_duration = maxf(duration, 0.0001)
	burst_time_left = burst_duration
	update_skill_bar()

## 弹药技能扣一发(干员每发射一轮调用); 返回是否弹药耗尽(技能已结束)
func consume_ammo() -> bool:
	skill_ammo_left -= 1
	update_skill_bar()
	if skill_ammo_left <= 0:
		end_skill()
		return true
	return false

## 结束技能(提前关闭/计时结束/弹药耗尽; 恢复绿色SP条)
func end_skill():
	if not is_skill_active:
		return
	is_skill_active = false
	is_overload = false
	skill_time_left = 0.0
	skill_ammo_left = 0
	skill_ammo_max = 0
	update_skill_bar()
	signal_skill_ended.emit()

## 更新技能条UI(三态: 绿色SP条 / 橙色倒计时条 / 橙色弹药格)
func update_skill_bar():
	if not is_instance_valid(progress_bar_skill):
		return
	var value := 0.0
	var bar_color := COLOR_BAR_NORMAL
	## 弹药技能激活: 显示橙色小格
	if is_skill_active and skill_ammo_max > 0:
		if ammo_box != null:
			ammo_box.visible = true
		progress_bar_skill.visible = false
		_update_ammo_cells()
		bar_color = COLOR_BAR_ACTIVE
	else:
		if ammo_box != null:
			ammo_box.visible = false
		progress_bar_skill.visible = true
		## 一次性多连发橙色技能条: 满条在攻击动画内耗尽为0(普通橙条, 非弹药格)
		if burst_active and burst_duration > 0.0:
			value = clampf(burst_time_left / burst_duration, 0.0, 1.0)
			bar_color = COLOR_BAR_SUSTAIN
		## 持续技能激活: 前段橙色条倒计时耗尽; 过载阶段技能条"重新充满"(#bd3f00)按过载段时长倒计时
		elif is_skill_active and is_sustain_skill and skill_max_duration > 0:
			if is_overload and overload_duration > 0.0:
				value = clampf(skill_time_left / overload_duration, 0.0, 1.0)
				bar_color = COLOR_BAR_OVERLOAD
			else:
				value = clampf(skill_time_left / skill_max_duration, 0.0, 1.0)
				bar_color = COLOR_BAR_SUSTAIN
		else:
			## 普通: 绿色SP条(浮点SP, 条随时间平滑增长)
			value = clampf(curr_sp / float(maxi(max_sp, 1)), 0.0, 1.0)
	## 应用填充色(缓存样式对象)
	if _style_fill_normal == null:
		_style_fill_normal = progress_bar_skill.get_theme_stylebox("fill")
	if _style_fill_sustain == null:
		var sb_sustain := StyleBoxFlat.new()
		sb_sustain.bg_color = COLOR_BAR_SUSTAIN
		_style_fill_sustain = sb_sustain
	if _style_fill_overload == null:
		var sb_overload := StyleBoxFlat.new()
		sb_overload.bg_color = COLOR_BAR_OVERLOAD
		_style_fill_overload = sb_overload
	var style: StyleBox = _style_fill_normal
	if bar_color == COLOR_BAR_SUSTAIN:
		style = _style_fill_sustain
	elif bar_color == COLOR_BAR_OVERLOAD:
		style = _style_fill_overload
	progress_bar_skill.add_theme_stylebox_override("fill", style)
	progress_bar_skill.value = value
	## 数字标签向下取整显示(浮点SP, 如 3.7 显示 3/5)
	label_skill.text = str(int(curr_sp)) + "/" + str(max_sp)
	signal_sp_change.emit(curr_sp, max_sp)
