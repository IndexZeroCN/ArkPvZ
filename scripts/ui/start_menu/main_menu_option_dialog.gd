extends Panel
class_name MainMenuOptionDialog

## 主菜单选项面板（音乐/音效音量 + 全屏切换 + 开发者选项入口），与主菜单一起在加载界面期间加载
## 开发者选项仅在 DEBUG 构建可见（导出 release 后隐藏）

@onready var music_h_slider: HSlider = %MusicSlider
@onready var sound_h_slider: HSlider = %SoundSlider
@onready var full_screen_check: CheckButton = %FullScreenCheck
@onready var dev_button: Button = %DevButton

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_slider(music_h_slider, AudioServer.get_bus_index("BGM"))
	_setup_slider(sound_h_slider, AudioServer.get_bus_index("SFX"))
	full_screen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full_screen_check.toggled.connect(_on_full_screen_toggled)
	## 开发者选项仅 DEBUG 显示
	dev_button.visible = OS.is_debug_build()


func _setup_slider(slider: HSlider, bus_index: int) -> void:
	slider.value = SoundManager.get_volum(bus_index)
	slider.value_changed.connect(func(v: float) -> void:
		SoundManager.set_volume(bus_index, v)
		Global.config_service.save_config()
	)


func _on_full_screen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func appear_menu() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_return_pressed() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 打开更多选项（复用游戏内控制台面板 CanvasLayerConsole，挂在主菜单场景根节点 ConsolePanel）
func _on_more_options_pressed() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var console := get_tree().current_scene.get_node_or_null("ConsolePanel") as CanvasLayerConsole
	if console:
		console.appear_canvas_layer_control()


## 打开开发者选项（原生窗口）；先关闭设置窗口，避免挡住 3D 内容
func _on_dev_pressed() -> void:
	if not OS.is_debug_build():
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dev_window := get_tree().current_scene.get_node_or_null("DevPanel") as DeveloperOptions
	if dev_window:
		dev_window.appear()
