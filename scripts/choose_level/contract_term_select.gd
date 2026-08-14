extends Control
class_name ContractTermSelect

## 危机合约词条选择面板：视觉对齐干员技能选择面板(AllOperatorSkillCard)——
## 全屏覆盖 + 居中 470×480 纹理面板 + 36px 内边距 + 22px 标题 + 滚动词条按钮列表 + 底部按钮。
## 词条来自 ContractTerms.TERM_INFO, 同 group 互斥(单选), 确认后发出 signal_confirm(selected_terms)。
## 节点全部代码构建(参考 card_slot_candidate._build_skill_buttons 模式), 场景文件仅一个空 Control。

signal signal_confirm(selected_terms: Array)
signal signal_cancel

## 与技能选择面板一致的面板纹理与边距
const PANEL_TEXTURE := "res://assets/image/ui/ui_main_game_menu/UI_BG/combined_result_2.png"
const PANEL_SIZE := Vector2(470, 480)
const PANEL_MARGIN := 36.0

## 当前已选中词条 id 列表
var _selected: Array = []
## id -> Button
var _toggles: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	## 全屏暗色遮罩(点击拦截, 模态)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	## 居中面板(与技能选择面板同款纹理样式)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = PANEL_MARGIN
	inner.offset_top = PANEL_MARGIN
	inner.offset_right = -PANEL_MARGIN
	inner.offset_bottom = -PANEL_MARGIN
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)

	## 标题(与技能面板同: 22px 居中)
	var title := Label.new()
	title.text = "危 机 合 约 · 词 条 选 择"
	title.custom_minimum_size = Vector2(0, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	inner.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "自选词条提升难度，0 条直接开始"
	subtitle.custom_minimum_size = Vector2(0, 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68))
	inner.add_child(subtitle)

	## 词条列表(滚动, 按钮样式对齐技能按钮)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for id in ContractTerms.TERM_INFO:
		list.add_child(_make_term_button(id))

	## 底部按钮(与技能面板取消按钮同尺寸风格)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	inner.add_child(bottom)

	var confirm := Button.new()
	confirm.text = "开始行动"
	confirm.custom_minimum_size = Vector2(150, 40)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.add_theme_font_size_override("font_size", 18)
	confirm.pressed.connect(_on_confirm)
	bottom.add_child(confirm)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(130, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(func() -> void:
		signal_cancel.emit()
		queue_free()
	)
	bottom.add_child(cancel)

func _make_term_button(id: String) -> Button:
	var info: Dictionary = ContractTerms.TERM_INFO[id]
	var btn := Button.new()
	btn.toggle_mode = true
	btn.text = "%s\n%s" % [info["name"], info["desc"]]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 88)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("normal", _make_term_style(false))
	btn.add_theme_stylebox_override("hover", _make_term_style(false))
	btn.add_theme_stylebox_override("pressed", _make_term_style(true))
	btn.add_theme_stylebox_override("hover_pressed", _make_term_style(true))
	btn.toggled.connect(_on_term_toggled.bind(id, info))
	_toggles[id] = btn
	return btn

## 同 group 互斥：选中时取消同组其它词条
func _on_term_toggled(pressed: bool, id: String, info: Dictionary) -> void:
	if pressed:
		var group: String = info.get("group", "")
		if group != "":
			for other_id in _toggles:
				if other_id != id and ContractTerms.TERM_INFO[other_id].get("group", "") == group:
					_toggles[other_id].set_pressed_no_signal(false)
					_selected.erase(other_id)
	if not _selected.has(id):
		_selected.append(id)
	else:
		_selected.erase(id)

func _on_confirm() -> void:
	signal_confirm.emit(_selected)
	queue_free()

func _make_panel_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(PANEL_TEXTURE)
	sb.texture_margin_left = 60.0
	sb.texture_margin_top = 50.0
	sb.texture_margin_right = 60.0
	sb.texture_margin_bottom = 120.0
	sb.expand_margin_left = 20.0
	sb.expand_margin_right = 20.0
	sb.expand_margin_top = 20.0
	sb.expand_margin_bottom = 20.0
	return sb

func _make_term_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.78, 0.3, 0.28) if selected else Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.93, 0.78, 0.3, 0.95) if selected else Color(1, 1, 1, 0.14)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb
