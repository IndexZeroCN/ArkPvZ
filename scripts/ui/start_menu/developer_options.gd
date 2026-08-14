extends Window
class_name DeveloperOptions

## 开发者选项原生窗口：透视/画面大小等调试参数，实时写入主菜单（main_menu.set_developer_param）并持久化
## 仅 DEBUG 构建启用（OS.is_debug_build），导出 release 后不显示
## 参数行由 PARAMS 数据表在 _ready 程序化生成（调试工具，无需逐个手写场景节点）

const FONT_MED := "res://assets/fonts/HarmonyOS_Sans_Medium.tres"

const PARAMS := [
	{ "key": "left_angle", "label": "左面板角度", "min": -30.0, "max": 30.0, "step": 0.5, "def": 18.5 },
	{ "key": "right_angle", "label": "右面板角度", "min": -30.0, "max": 30.0, "step": 0.5, "def": -30.0 },
	{ "key": "swing_y", "label": "鼠标水平摆动", "min": 0.0, "max": 20.0, "step": 0.5, "def": 5.0 },
	{ "key": "swing_x", "label": "鼠标垂直俯仰", "min": 0.0, "max": 15.0, "step": 0.5, "def": 1.5 },
	{ "key": "cam_fov", "label": "相机FOV", "min": 20.0, "max": 80.0, "step": 1.0, "def": 25.0 },
	{ "key": "cam_dist", "label": "相机距离", "min": 8.0, "max": 25.0, "step": 0.5, "def": 12.5 },
	{ "key": "cam_height", "label": "相机高度", "min": -2.0, "max": 3.0, "step": 0.1, "def": -0.7 },
	{ "key": "cam_parallax", "label": "鼠标透视偏移", "min": 0.0, "max": 2.0, "step": 0.05, "def": 0.5 },
	{ "key": "left_panel_scale", "label": "左面板缩放", "min": 0.5, "max": 1.5, "step": 0.05, "def": 1.0 },
	{ "key": "right_panel_scale", "label": "右面板缩放", "min": 0.5, "max": 1.5, "step": 0.05, "def": 1.15 },
	{ "key": "wisdel_cover_scale", "label": "封面干员大小", "min": 0.4, "max": 1.2, "step": 0.05, "def": 0.8 },
]

@onready var rows: VBoxContainer = %Rows

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}

func _ready() -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	hide()
	if not OS.is_debug_build():
		set_process(false)
		return
	_build_rows()
	## 仅把已保存的值灌入滑块（不触发应用——主菜单 _ready 会自行应用，且此时主菜单 onready 未就绪）
	_load_saved_values()


func appear() -> void:
	if not OS.is_debug_build():
		return
	## 子级 Window 用 show()（popup() 会报 “Attempting to parent and popup a dialog that already has a parent”）
	show()
	grab_focus()
	## 居中
	var screen_size := DisplayServer.screen_get_size()
	position = Vector2i(int((screen_size.x - size.x) / 2.0), int((screen_size.y - size.y) / 2.0))
	_apply_all()


## 由 PARAMS 数据表生成滑块行：标签 + HSlider + 数值
func _build_rows() -> void:
	for p in PARAMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)

		var label := Label.new()
		label.text = p.label
		label.custom_minimum_size = Vector2(110, 0)
		label.add_theme_font_override("font", load(FONT_MED))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		row.add_child(label)

		var slider := HSlider.new()
		slider.min_value = p.min
		slider.max_value = p.max
		slider.step = p.step
		## 初始化不触发 value_changed（主菜单 onready 未就绪）
		slider.set_value_no_signal(p.def)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)

		var value_label := Label.new()
		value_label.text = "%.1f" % p.def
		value_label.custom_minimum_size = Vector2(44, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_override("font", load(FONT_MED))
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color(0, 0.69, 1))
		row.add_child(value_label)

		_sliders[p.key] = slider
		_value_labels[p.key] = value_label
		slider.value_changed.connect(_on_value_changed.bind(p.key, value_label))


func _on_value_changed(value: float, key: String, value_label: Label) -> void:
	value_label.text = "%.1f" % value
	var menu := get_tree().current_scene as MainMenu
	if menu:
		menu.set_developer_param(key, value)


## 加载已保存的开发者选项值到滑块（不应用，避免主菜单 onready 未就绪）
func _load_saved_values() -> void:
	for p in PARAMS:
		var saved: float = Global.config_service.get_developer_option(p.key, p.def)
		_sliders[p.key].set_value_no_signal(saved)
		_value_labels[p.key].text = "%.1f" % saved


func _apply_all() -> void:
	var menu := get_tree().current_scene as MainMenu
	if menu == null:
		return
	for key in _sliders:
		menu.set_developer_param(key, _sliders[key].value)


func _on_reset_pressed() -> void:
	for p in PARAMS:
		_sliders[p.key].value = p.def
	_apply_all()


func _on_return_pressed() -> void:
	hide()
