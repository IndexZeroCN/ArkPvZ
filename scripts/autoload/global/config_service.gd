extends Node
class_name ConfigService

## 配置服务：只负责 config.ini 的读写、保存当前设置、并对外提供配置值
## 运行态逻辑请直接通过 Global.config_service/<var> 与 <signal> 获取

signal signal_change_disappear_spare_card_placeholder
signal signal_change_display_plant_HP_label(value: bool)
signal signal_change_display_zombie_HP_label(value: bool)
signal signal_change_card_slot_top_mouse_focus
signal signal_fog_is_static
## 子弹无目标时追踪鼠标
signal signal_track_bullet_mouse

@onready var user_manager: UserManager = %UserManager

## 用户个人配置文件（每个用户一份）
const CURRENT_CONFIG_FILE := "config.ini"
## 全局配置文件（所有用户共享，与用户个人 config.ini 分离，存放开发者选项等全局选项）
const GLOBAL_CONFIG_FILE := "config_global.ini"


func _ready() -> void:
	## 开发者选项为全局选项，场景就绪即加载（不依赖用户登录状态）
	load_global_developer_options()

## 用户选项（持久化字段）
var auto_collect_sun := false
var auto_collect_coin := false

var disappear_spare_card_Placeholder := false:
	set(value):
		if disappear_spare_card_Placeholder == value:
			return
		disappear_spare_card_Placeholder = value
		signal_change_disappear_spare_card_placeholder.emit()

var display_plant_HP_label := false:
	set(value):
		if display_plant_HP_label == value:
			return
		display_plant_HP_label = value
		signal_change_display_plant_HP_label.emit(display_plant_HP_label)

var display_zombie_HP_label := false:
	set(value):
		if display_zombie_HP_label == value:
			return
		display_zombie_HP_label = value
		signal_change_display_zombie_HP_label.emit(display_zombie_HP_label)

var card_slot_top_mouse_focus := false:
	set(value):
		if card_slot_top_mouse_focus == value:
			return
		card_slot_top_mouse_focus = value
		signal_change_card_slot_top_mouse_focus.emit()

var fog_is_static := false:
	set(value):
		if fog_is_static == value:
			return
		fog_is_static = value
		signal_fog_is_static.emit()

var plant_be_shovel_front := true
var open_all_level := false

## 开发者选项（透视/画面等调试参数，仅 DEBUG 使用）。
## 全局选项：所有用户共享，持久化到 user://config_global.ini 的 developer/options，与用户个人 config.ini 分离。
## 默认值 = 用户 IndexZero 调好的全局数值（新装/文件丢失时回退到该组数值）。
var developer_options: Dictionary = {}

##追踪子弹无目标时跟随标
var track_bullet_mouse := false:
	set(value):
		if track_bullet_mouse == value:
			return
		track_bullet_mouse = value
		signal_track_bullet_mouse.emit()


func _get_config_path() -> String:
	if user_manager == null or user_manager.curr_user_name.is_empty():
		return ""
	return "user://" + user_manager.curr_user_name + "/" + CURRENT_CONFIG_FILE

## 全局配置文件的绝对 user:// 路径（与当前用户无关）
func _get_global_config_path() -> String:
	return "user://" + GLOBAL_CONFIG_FILE

## 开发者选项全局默认值（用户 IndexZero 设定，作为全局选项数值）
const DEFAULT_DEVELOPER_OPTIONS := {
	"left_angle": 18.5,
	"right_angle": -30.0,
	"swing_y": 5.0,
	"swing_x": 1.5,
	"cam_fov": 25.0,
	"cam_dist": 12.5,
	"cam_height": -0.7,
	"cam_parallax": 0.5,
	"left_panel_scale": 1.0,
	"right_panel_scale": 1.15,
	"wisdel_cover_scale": 0.8,
}

## 加载全局开发者选项（与用户无关；文件不存在时回退到 DEFAULT_DEVELOPER_OPTIONS）
func load_global_developer_options() -> void:
	var config := ConfigFile.new()
	if config.load(_get_global_config_path()) == OK:
		developer_options = config.get_value("developer", "options", DEFAULT_DEVELOPER_OPTIONS.duplicate())
	else:
		developer_options = DEFAULT_DEVELOPER_OPTIONS.duplicate()

## 保存全局开发者选项到 user://config_global.ini
func save_global_developer_options() -> void:
	var config := ConfigFile.new()
	config.set_value("developer", "options", developer_options)
	config.save(_get_global_config_path())

func load_and_apply_config() -> void:

	## 开发者选项为全局选项（所有用户共享），先于用户个人配置加载，与是否登录无关
	load_global_developer_options()

	var path := _get_config_path()
	if path.is_empty():
		return

	var config := ConfigFile.new()
	# config 不存在时 load 的返回值可能非 OK，此时仍使用默认值应用（不报错可提升兼容性）
	var load_err := config.load(path)

	# 音量设置
	SoundManager.set_volume(SoundManager.Bus.MASTER, config.get_value("audio", "master", 1.0))
	SoundManager.set_volume(SoundManager.Bus.BGM, config.get_value("audio", "bgm", 0.5))
	SoundManager.set_volume(SoundManager.Bus.SFX, config.get_value("audio", "sfx", 0.5))

	# 用户选项控制台
	auto_collect_sun = config.get_value("user_control", "auto_collect_sun", false)
	auto_collect_coin = config.get_value("user_control", "auto_collect_coin", false)
	disappear_spare_card_Placeholder = config.get_value("user_control", "disappear_spare_card_Placeholder", false)
	display_plant_HP_label = config.get_value("user_control", "display_plant_HP_label", false)
	display_zombie_HP_label = config.get_value("user_control", "display_zombie_HP_label", false)
	card_slot_top_mouse_focus = config.get_value("user_control", "card_slot_top_mouse_focus", false)
	fog_is_static = config.get_value("user_control", "fog_is_static", false)
	plant_be_shovel_front = config.get_value("user_control", "plant_be_shovel_front", true)
	## 新用户（config.ini 不存在）默认所有关卡全部开放；老用户按各自已保存的值
	open_all_level = config.get_value("user_control", "open_all_level", load_err != OK)
	track_bullet_mouse = config.get_value("user_control", "track_bullet_mouse", false)

	EventBus.push_event("on_config_update")


## 读取开发者选项值
func get_developer_option(key: String, default_value: float) -> float:
	return developer_options.get(key, default_value)


## 写入开发者选项值并保存（全局选项，保存到 user://config_global.ini，不写入用户个人配置）
func set_developer_option(key: String, value: float) -> void:
	developer_options[key] = value
	save_global_developer_options()

## 新用户初始化个人配置：用户创建后默认所有关卡全部开放（写入该用户的 config.ini）
func init_new_user_config(user_name: String) -> void:
	var config := ConfigFile.new()
	config.set_value("user_control", "open_all_level", true)
	config.save("user://%s/%s" % [user_name, CURRENT_CONFIG_FILE])

func save_config() -> void:
	var path := _get_config_path()
	if path.is_empty():
		return

	var config := ConfigFile.new()

	# 音乐相关
	config.set_value("audio", "master", SoundManager.get_volum(SoundManager.Bus.MASTER))
	config.set_value("audio", "bgm", SoundManager.get_volum(SoundManager.Bus.BGM))
	config.set_value("audio", "sfx", SoundManager.get_volum(SoundManager.Bus.SFX))

	# 用户选项控制台相关
	config.set_value("user_control", "auto_collect_sun", auto_collect_sun)
	config.set_value("user_control", "auto_collect_coin", auto_collect_coin)
	config.set_value("user_control", "disappear_spare_card_Placeholder", disappear_spare_card_Placeholder)
	config.set_value("user_control", "display_plant_HP_label", display_plant_HP_label)
	config.set_value("user_control", "display_zombie_HP_label", display_zombie_HP_label)
	config.set_value("user_control", "card_slot_top_mouse_focus", card_slot_top_mouse_focus)
	config.set_value("user_control", "fog_is_static", fog_is_static)
	config.set_value("user_control", "plant_be_shovel_front", plant_be_shovel_front)
	config.set_value("user_control", "open_all_level", open_all_level)
	config.set_value("user_control", "track_bullet_mouse", track_bullet_mouse)
	## 开发者选项是全局选项，由 save_global_developer_options 写 user://config_global.ini，不在此保存

	config.save(path)
