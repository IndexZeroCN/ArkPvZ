extends Control

## 音效试听与备注场景: 扫描 assets/audio/SFX/operator_pick/ 下所有音频, 按分类列出
## 每个音效: 播放按钮 + 已听复选框(播放过/被打断=标记, 行变蓝, 可取消) + 文件名 + 备注输入框
## 已听状态与备注自动保存(user://), 「导出备注」写入 data/sfx_notes.json
## 用途: 试听克洛斯/维什戴尔候选音效, 记录每个音效决定用什么
## 运行: godot --path . res://test/sfx_pick.tscn

const SFX_DIR := "res://assets/audio/SFX/operator_pick"
## 备注自动保存路径(user:// 可写)
const NOTES_PATH := "user://sfx_notes.json"
## 已听标记保存路径
const PLAYED_PATH := "user://sfx_played.json"
## 导出路径(写入项目 data/, 供读取集成)
const EXPORT_PATH := "res://data/sfx_notes.json"

## 已听标记的蓝色
const COLOR_PLAYED := Color(0.45, 0.7, 1.0)

## 当前播放器(点击新音效时停掉旧的)
var _player: AudioStreamPlayer = null
## 备注表: 文件名 -> 备注文字
var _notes: Dictionary = {}
## 已听标记: 文件名 -> true
var _played: Dictionary = {}
## 文件名 -> 行控件(更新蓝/复选框用)
var _row_controls: Dictionary = {}

func _ready() -> void:
	_load_notes()
	_load_played()
	_build_ui()

## 加载备注: 先加载推测备注(data/sfx_notes.json), 再加载用户备注(user:// 覆盖)
func _load_notes() -> void:
	var f := FileAccess.open("res://data/sfx_notes.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_notes = parsed
		f.close()
	f = FileAccess.open(NOTES_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for key in parsed:
				_notes[key] = parsed[key]
		f.close()

## 保存备注
func _save_notes() -> void:
	var f := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_notes, "\t"))
		f.close()

## 加载已听标记
func _load_played() -> void:
	var f := FileAccess.open(PLAYED_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_played = parsed
		f.close()

## 保存已听标记
func _save_played() -> void:
	var f := FileAccess.open(PLAYED_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_played, "\t"))
		f.close()

func _build_ui() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		print("目录不存在: ", SFX_DIR)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			files.append(f)
	files.sort()
	if files.is_empty():
		print("目录无音频文件: ", SFX_DIR)
		return

	## 按音效类型分组
	var groups := {
		"弓/箭类(arrow/bow/crossbow... 克洛斯候选)": [],
		"炮/枪类(blackcannon/chngun... 维什戴尔候选)": [],
		"投掷/爆炸/范围类(axethrow/explo/bomb/aoe...)": [],
		"技能类(p_skill_*)": [],
		"受击类(p_imp_*)": [],
		"战斗状态/特效类(btl_snd b_char_*)": [],
		"人声类(vox v_*)": [],
	}
	for f: String in files:
		var key := "技能类(p_skill_*)"
		if f.begins_with("p_skill_"):
			key = "技能类(p_skill_*)"
		elif f.begins_with("p_imp_"):
			key = "受击类(p_imp_*)"
		elif f.begins_with("p_atk_blackcannon") or f.begins_with("p_atk_chngun"):
			key = "炮/枪类(blackcannon/chngun... 维什戴尔候选)"
		elif f.begins_with("p_atk_axethrow") or f.begins_with("p_atk_axe") or f.begins_with("p_aoe_"):
			key = "投掷/爆炸/范围类(axethrow/explo/bomb/aoe...)"
		elif f.begins_with("b_"):
			key = "战斗状态/特效类(btl_snd b_char_*)"
		elif f.begins_with("v_"):
			key = "人声类(vox v_*)"
		else:
			key = "弓/箭类(arrow/bow/crossbow... 克洛斯候选)"
		groups[key].append(f)

	## UI: 全屏 ScrollContainer + VBox
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	## 标题 + 说明 + 导出按钮
	var title := Label.new()
	title.text = "音效试听与备注 - 点击播放, 已听(含打断)的音频行变蓝, 可取消; 备注自动保存"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "共 %d 个音效 | 备注保存 user://sfx_notes.json | 已听标记保存 user://sfx_played.json | 「导出备注」写入 data/sfx_notes.json" % files.size()
	hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	vbox.add_child(hint)
	var export_btn := Button.new()
	export_btn.text = "导出备注(写入 data/sfx_notes.json)"
	export_btn.pressed.connect(_export_notes)
	vbox.add_child(export_btn)

	## 分组列出
	for group_name: String in groups:
		var list: Array = groups[group_name]
		if list.is_empty():
			continue
		var group_label := Label.new()
		group_label.text = "【%s】 (%d 个)" % [group_name, list.size()]
		group_label.add_theme_font_size_override("font_size", 15)
		group_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		vbox.add_child(group_label)
		for f: String in list:
			vbox.add_child(_make_row(f))

## 构造一行: 播放按钮 + 已听复选框 + 文件名 + 备注输入框
func _make_row(file_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 30)
	var btn := Button.new()
	btn.text = "▶ 播放"
	btn.custom_minimum_size = Vector2(64, 0)
	btn.pressed.connect(_play_sfx.bind(file_name))
	row.add_child(btn)
	var check := CheckBox.new()
	check.text = "已听"
	check.tooltip_text = "播放过(含被打断)自动勾选; 取消勾选可移除蓝色标记"
	check.button_pressed = _played.has(file_name)
	check.toggled.connect(_on_played_toggled.bind(file_name))
	row.add_child(check)
	var label := Label.new()
	label.text = file_name
	label.custom_minimum_size = Vector2(340, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = "备注(用途)..."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text = _notes.get(file_name, "")
	edit.text_changed.connect(_on_note_changed.bind(file_name))
	row.add_child(edit)
	## 记录控件, 播放/取消标记时更新
	_row_controls[file_name] = {"label": label, "check": check}
	## 应用已听状态(蓝色)
	_apply_played_color(file_name)
	return row

## 应用已听颜色(文件名变蓝)
func _apply_played_color(file_name: String) -> void:
	var ctrl: Dictionary = _row_controls.get(file_name, {})
	if ctrl.is_empty() or not (ctrl["label"] is Label):
		return
	var label: Label = ctrl["label"]
	if _played.has(file_name):
		label.add_theme_color_override("font_color", COLOR_PLAYED)
	else:
		label.remove_theme_color_override("font_color")

## 已听复选框切换(取消标记=移除蓝色)
func _on_played_toggled(pressed: bool, file_name: String) -> void:
	if pressed:
		_played[file_name] = true
	else:
		_played.erase(file_name)
	_save_played()
	_apply_played_color(file_name)

## 备注变化: 更新并保存
func _on_note_changed(text: String, file_name: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		_notes.erase(file_name)
	else:
		_notes[file_name] = trimmed
	_save_notes()

## 导出备注到项目 data/
func _export_notes() -> void:
	var f := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if f == null:
		print("导出失败: ", EXPORT_PATH, " (res:// 只读? 用编辑器运行)")
		return
	f.store_string(JSON.stringify(_notes, "\t"))
	f.close()
	print("已导出备注到: ", EXPORT_PATH)
	print("备注内容: ", JSON.stringify(_notes, "\t"))

## 播放音效(停止上一个; 播放过即标记已听)
func _play_sfx(file_name: String) -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
		_player = null
	var stream: AudioStream = load("%s/%s" % [SFX_DIR, file_name])
	if stream == null:
		print("加载失败: ", file_name)
		return
	## 播放过(含被打断)标记已听 -> 行变蓝
	if not _played.has(file_name):
		_played[file_name] = true
		_save_played()
		_apply_played_color(file_name)
		var ctrl: Dictionary = _row_controls.get(file_name, {})
		if not ctrl.is_empty() and ctrl["check"] is CheckBox:
			(ctrl["check"] as CheckBox).set_pressed_no_signal(true)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.stream = stream
	_player.play()
