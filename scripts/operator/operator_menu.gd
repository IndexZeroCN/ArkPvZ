extends CanvasLayer
class_name OperatorMenu
## 干员菜单: 选中干员后显示的浮动菜单(技能/撤退按钮), 点击空白处关闭
## 由 OperatorManager 创建并管理, 只负责显示与发信号, 不处理干员逻辑

## 技能按钮点击信号
signal signal_use_skill
## 撤退按钮点击信号
signal signal_retreat
## 关闭(点击菜单外空白处)信号
signal signal_close

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var name_label: Label = %NameLabel
@onready var skill_button: Button = %SkillButton
@onready var retreat_button: Button = %RetreatButton
@onready var range_icon: OperatorMenuRangeIcon = %RangeIcon

## 当前菜单绑定的干员
var curr_operator: Operator000Base

func _ready() -> void:
	hide()

## 显示干员菜单
func open_menu(operator: Operator000Base):
	curr_operator = operator
	## 干员名
	var operator_name: String = "干员"
	if operator.plant_type != CharacterRegistry.PlantType.Null:
		operator_name = str(Global.character_registry.get_plant_info(operator.plant_type, CharacterRegistry.PlantInfoAttribute.PlantName))
	name_label.text = operator_name
	## 按钮可用状态(召唤物默认禁用)
	skill_button.disabled = not operator.is_can_manual_skill
	retreat_button.disabled = not operator.is_can_retreat
	## 攻击范围小图标(点亮范围格)
	range_icon.set_range_shape(DetectComponentOperator.ATTACK_RANGE_SHAPE)
	## 定位在干员头顶上方(世界坐标转屏幕坐标)
	var screen_pos: Vector2 = operator.get_global_transform_with_canvas().origin
	menu_panel.position = screen_pos + Vector2(20, -84)
	show()

## 关闭菜单(干员选中状态由管理器处理)
func close_menu():
	curr_operator = null
	hide()

func _on_close_button_pressed() -> void:
	signal_close.emit()

func _on_skill_button_pressed() -> void:
	signal_use_skill.emit()

func _on_retreat_button_pressed() -> void:
	signal_retreat.emit()
