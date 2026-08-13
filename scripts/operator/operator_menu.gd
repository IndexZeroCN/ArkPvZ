extends CanvasLayer
class_name OperatorMenu
## 干员菜单: 选中干员后显示的悬浮操作按钮(撤退=干员左上, 技能=干员右下), 点击空白处关闭
## 由 OperatorManager 创建并管理, 只负责显示与发信号, 不处理干员逻辑
## 同时显示干员脚下的攻击范围预览(挂在干员节点上, 世界坐标跟随干员, 避免 CanvasLayer 屏幕层错位)

## 技能按钮点击信号
signal signal_use_skill
## 撤退按钮点击信号
signal signal_retreat
## 关闭(点击菜单外空白处)信号
signal signal_close

## 技能/撤退按钮点击后标记: 本次点击的关闭信号忽略
## (防止同一次点击事件穿透到 CloseArea/_unhandled_input 导致菜单关闭)
var _suppress_close := false

## 撤退按钮中心相对干员中心的偏移(干员左上; 按钮 40x40)
const RETREAT_BUTTON_OFFSET := Vector2(-62, -96)
## 技能按钮中心相对干员中心的偏移(干员右下; 按钮 44x44, 往右偏一点)
const SKILL_BUTTON_OFFSET := Vector2(72, 4)

@onready var retreat_button: TextureButton = %RetreatButton
@onready var skill_button: TextureButton = %SkillButton

## 当前菜单绑定的干员
var curr_operator: Operator000Base
## 战场攻击范围预览(挂在干员节点下, 世界坐标)
var range_preview: OperatorRangePreview

func _ready() -> void:
	hide()

## 显示干员菜单
func open_menu(operator: Operator000Base):
	curr_operator = operator
	## 按钮可用状态(召唤物默认禁用)
	skill_button.disabled = not operator.is_can_manual_skill
	retreat_button.disabled = not operator.is_can_retreat
	## 技能按钮图标按干员所选技能显示(多技能干员, 如维什戴尔)
	var skill_icon: Texture2D = operator.get_skill_icon()
	if skill_icon:
		skill_button.texture_normal = skill_icon
		skill_button.texture_pressed = skill_icon
		skill_button.texture_hover = skill_icon
		skill_button.texture_disabled = skill_icon
	## 定位: 按钮中心 = 干员中心(干员屏幕位置) + 偏移(撤退左上 / 技能右下)
	var center: Vector2 = operator.get_global_transform_with_canvas().origin
	retreat_button.position = center + RETREAT_BUTTON_OFFSET - retreat_button.size * 0.5
	skill_button.position = center + SKILL_BUTTON_OFFSET - skill_button.size * 0.5
	## 攻击范围预览: 挂主游戏场景根(transform identity, polygon 世界坐标直接对应, 不随父偏移)
	if is_instance_valid(operator.plant_cell):
		if not is_instance_valid(range_preview):
			range_preview = OperatorRangePreview.new()
			range_preview.z_index = 0
			get_tree().current_scene.add_child(range_preview)
		range_preview.show_hint = false
		var cells: Array[Vector2] = operator.get_attack_range_cells()
		var spacing: Vector2 = DetectComponentOperator.get_grid_spacing(operator.plant_cell)
		var base: Vector2 = operator.plant_cell.global_position + operator.plant_cell.size * 0.5
		range_preview.set_range_cells(cells, spacing, base)
		range_preview.visible = true
	show()

## 关闭菜单(干员选中状态由管理器处理)
func close_menu():
	curr_operator = null
	## 移除范围预览(挂在干员节点下, 关闭菜单即删除)
	if is_instance_valid(range_preview):
		range_preview.queue_free()
		range_preview = null
	hide()

func _on_close_button_pressed() -> void:
	## 技能/撤退按钮刚点击过: 忽略本次穿透的关闭(菜单保持打开, 便于连续操作)
	if _suppress_close:
		_suppress_close = false
		return
	signal_close.emit()

func _on_skill_button_pressed() -> void:
	_suppress_close = true
	signal_use_skill.emit()

func _on_retreat_button_pressed() -> void:
	_suppress_close = true
	signal_retreat.emit()

## 点击位置是否落在菜单按钮(撤退/技能)上; 用于 _unhandled_input 防止点击按钮时误关菜单
func is_click_on_button(viewport_pos: Vector2) -> bool:
	for btn: TextureButton in [retreat_button, skill_button]:
		if not is_instance_valid(btn) or btn.disabled:
			continue
		var rect := Rect2(btn.global_position, btn.size)
		if rect.has_point(viewport_pos):
			return true
	return false
