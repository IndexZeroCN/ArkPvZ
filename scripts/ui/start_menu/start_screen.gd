extends Control
class_name StartScreen

## 开始界面（简版）：星球 + 标题，点击任意位置进入加载界面
## 登录/注册已暂时移除，直接进入主菜单

@export var bgm: AudioStream

const LOADING_SCENE_PATH := "res://scenes/main/00LoadingScreen.tscn"

@onready var planet: TextureRect = %Planet

var _planet_base_y := 0.0

func _ready() -> void:
	SoundManager.play_bgm(bgm)
	Global.time_scale = 1.0
	Engine.time_scale = 1.0

	_planet_base_y = planet.position.y
	## 首页状态星球位于下方
	planet.position.y = _planet_base_y + 146.0

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


## 点击任意位置进入加载界面
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_enter_loading()


func _on_start_button_pressed() -> void:
	_enter_loading()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _enter_loading() -> void:
	modulate.a = 1.0
	create_tween().tween_property(self, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)
