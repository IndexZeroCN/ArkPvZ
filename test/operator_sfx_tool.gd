extends Control

## 干员音效调试界面 v2: 手动决定每个音频的发动时机
## 上半: 干员选择 + 控制按钮(攻击/技能/入场/撤退)触发对应时机音效
## 下半: 列出用户上传音效(assets/audio/SFX/operator/), 每个指定"发动时机"
## 配置: 文件->时机 转成"SoundManager键->文件" 保存 data/operator_sfx_config.json, 运行时生效
## 运行: godot --path . res://test/operator_sfx_tool.tscn

## 干员选择
const OPERATORS := [
	["kroos", "克洛斯"],
	["wisdel", "维什戴尔"],
	["shadow", "魂灵之影"],
]
## 用户上传音效目录
const OP_SFX_DIR := "res://assets/audio/SFX/operator"
## 候选音频目录(试听/设置用, 含全部提取候选)
const CAND_DIR := "res://assets/audio/SFX/operator_pick"
## 配置保存路径(键 -> 文件名, SoundManager 运行时读取)
const CONFIG_PATH := "res://data/operator_sfx_config.json"

## 发动时机 -> SoundManager键 (用户为音频选择时机后, 转成 键->文件)
const TIMING_KEYS := [
	["克洛斯 攻击", &"KroosAttack"],
	["维什戴尔 炮弹发射", &"WisdelAttackShot"],
	["维什戴尔 攻击动画开始", &"WisdelAttackAnimStart"],
	["维什戴尔 三技能启动", &"WisdelSkill3Start"],
	["维什戴尔 三技能动画开始", &"WisdelSkill3AnimStart"],
	["维什戴尔 受击(敌人被攻击)", &"WisdelHit"],
	["维什戴尔 撤退", &"WisdelRetreat"],
	["魂灵 攻击", &"ShadowAttack"],
	["魂灵 受击(敌人被攻击)", &"ShadowHit"],
	["魂灵 撤退", &"ShadowRetreat"],
	## 默认音效(无专属音效的干员使用, 如克洛丝的部署/死亡/技能发动)
	["默认 部署", &"OperatorDeploy"],
	["默认 死亡", &"OperatorDeath"],
	["默认 技能发动", &"OperatorSkill"],
]

## 当前干员 id
var _curr_operator := "wisdel"
## 配置(键 -> 文件名)
var _config: Dictionary = {}
var _player: AudioStreamPlayer = null

func _ready() -> void:
	_load_config()
	_build_ui()

## 加载配置
func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_config = parsed
		f.close()

## 保存配置
func _save_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_config, "\t"))
		f.close()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "干员音效调试 - 为每个音频指定发动时机(攻击/技能/入场/撤退), 控制按钮可测试"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	title.position = Vector2(20, 10)

	## 干员选择
	var op_row := HBoxContainer.new()
	op_row.position = Vector2(20, 45)
	add_child(op_row)
	op_row.add_child(_make_label("干员:"))
	var op_option := OptionButton.new()
	for op in OPERATORS:
		op_option.add_item(op[1])
	op_option.select(1)
	op_option.item_selected.connect(_on_operator_selected)
	op_row.add_child(op_option)

	## 控制按钮
	var ctrl_row := HBoxContainer.new()
	ctrl_row.position = Vector2(20, 85)
	add_child(ctrl_row)
	ctrl_row.add_child(_make_ctrl_button("攻击一次", _on_attack))
	ctrl_row.add_child(_make_ctrl_button("二技能", _on_skill2))
	ctrl_row.add_child(_make_ctrl_button("三技能", _on_skill3))
	ctrl_row.add_child(_make_ctrl_button("入场", _on_enter))
	ctrl_row.add_child(_make_ctrl_button("撤退", _on_retreat))

	## 音频->时机 配置表(滚动)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 130)
	scroll.size = Vector2(1100, 440)
	add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	## 已上传音效(operator/ 目录, 排除 unknown_hahaha)
	var files: Array[String] = []
	var dir := DirAccess.open(OP_SFX_DIR)
	if dir != null:
		for f in dir.get_files():
			if (f.ends_with(".wav") or f.ends_with(".ogg")) and f != "unknown_hahaha.wav":
				files.append(f)
		files.sort()

	var hint := Label.new()
	hint.text = "下方为已上传音效(%d 个), 每个指定发动时机; 同一时机后选的覆盖前选 | 配置存 %s" % [files.size(), CONFIG_PATH]
	hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	vbox.add_child(hint)

	## 反向: 键 -> 文件 (显示当前各时机的音频)
	for entry in TIMING_KEYS:
		vbox.add_child(_make_timing_row(entry[0], entry[1]))

	vbox.add_child(HSeparator.new())
	var file_title := Label.new()
	file_title.text = "— 音频文件 → 发动时机 —"
	file_title.add_theme_font_size_override("font_size", 15)
	file_title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(file_title)
	for f: String in files:
		vbox.add_child(_make_file_row(f))

## 控制按钮
func _make_ctrl_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 40)
	btn.pressed.connect(callback)
	return btn

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(60, 0)
	return label

## 时机行: 显示该时机当前配置的音效
func _make_timing_row(timing_name: String, key: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = "【%s】" % timing_name
	label.custom_minimum_size = Vector2(280, 0)
	row.add_child(label)
	var file_label := Label.new()
	file_label.text = _config.get(key, "(默认)")
	file_label.custom_minimum_size = Vector2(340, 0)
	file_label.add_theme_font_size_override("font_size", 12)
	row.add_child(file_label)
	var play_btn := Button.new()
	play_btn.text = "▶ 试听"
	play_btn.custom_minimum_size = Vector2(70, 0)
	play_btn.pressed.connect(_play_sfx_key.bind(key))
	row.add_child(play_btn)
	return row

## 文件行: 试听 + 发动时机下拉
func _make_file_row(file_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 32)
	var file_label := Label.new()
	file_label.text = file_name
	file_label.custom_minimum_size = Vector2(320, 0)
	file_label.add_theme_font_size_override("font_size", 12)
	row.add_child(file_label)
	var play_btn := Button.new()
	play_btn.text = "▶"
	play_btn.custom_minimum_size = Vector2(40, 0)
	play_btn.pressed.connect(_play_file.bind(file_name))
	row.add_child(play_btn)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(280, 0)
	option.add_item("(不播放)")
	for entry in TIMING_KEYS:
		option.add_item(entry[0])
	## 当前配置反向查找: 该文件被配置到哪个时机
	var curr_timing := 0
	for i in TIMING_KEYS.size():
		if _config.get(TIMING_KEYS[i][1], "") == file_name:
			curr_timing = i + 1
			break
	option.select(curr_timing)
	option.item_selected.connect(_on_timing_selected.bind(file_name, option))
	row.add_child(option)
	return row

## 为音频指定发动时机: 更新配置(键->文件)
func _on_timing_selected(index: int, file_name: String, option: OptionButton) -> void:
	## 先清除该文件在其它时机的配置
	for entry in TIMING_KEYS:
		if _config.get(entry[1], "") == file_name:
			_config.erase(entry[1])
	if index <= 0:
		print("[SFX] %s -> 不播放" % file_name)
	else:
		var key: StringName = TIMING_KEYS[index - 1][1]
		_config[key] = file_name
		print("[SFX] %s -> 时机[%s]" % [file_name, TIMING_KEYS[index - 1][0]])
	_save_config()

## 干员选择
func _on_operator_selected(index: int) -> void:
	_curr_operator = OPERATORS[index][0]

## 控制: 攻击
func _on_attack() -> void:
	match _curr_operator:
		"kroos":
			_play_sfx_key(&"KroosAttack")
		"wisdel":
			_play_sfx_key(&"WisdelAttackAnimStart")
			_play_sfx_key(&"WisdelAttackShot")
		"shadow":
			_play_sfx_key(&"ShadowAttack")

## 控制: 释放二技能(维什戴尔; 无专属音效, 提示)
func _on_skill2() -> void:
	if _curr_operator == "wisdel":
		print("[SFX] 二技能(饱和复仇): 无专属音效(用户未上传)")
	elif _curr_operator == "shadow":
		## 魂灵技能即攻击
		_play_sfx_key(&"ShadowAttack")
	else:
		print("[SFX] 当前干员无二技能音效: ", _curr_operator)

## 控制: 释放三技能(维什戴尔启动音 + 动画开始)
func _on_skill3() -> void:
	if _curr_operator == "wisdel":
		_play_sfx_key(&"WisdelSkill3Start")
		_play_sfx_key(&"WisdelSkill3AnimStart")
	else:
		print("[SFX] 当前干员无三技能音效: ", _curr_operator)

## 控制: 入场(无专属音效, 提示)
func _on_enter() -> void:
	print("[SFX] 入场: 无专属入场音效(默认动画音), 干员=", _curr_operator)

## 控制: 撤退
func _on_retreat() -> void:
	match _curr_operator:
		"wisdel":
			_play_sfx_key(&"WisdelRetreat")
		"shadow":
			_play_sfx_key(&"ShadowRetreat")
		_:
			print("[SFX] 当前干员无撤退音效: ", _curr_operator)

## 播放时机音效(按配置)
func _play_sfx_key(key: StringName) -> void:
	var cfg: String = _config.get(key, "")
	if cfg.is_empty():
		SoundManager.play_character_SFX(key)
		print("[SFX] %s -> 默认音效" % key)
		return
	_play_file(cfg)

## 播放指定文件
func _play_file(file_name: String) -> void:
	var stream: AudioStream = load("%s/%s" % [OP_SFX_DIR, file_name])
	if stream == null:
		stream = load("%s/%s" % [CAND_DIR, file_name])
	if stream == null:
		print("加载失败: ", file_name)
		return
	if is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.stream = stream
	_player.play()
