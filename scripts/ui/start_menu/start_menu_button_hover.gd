extends TextureButton

## 开始菜单按钮鼠标悬浮效果：默认显示背景图，悬浮时切换为高亮图

@onready var mouse: TextureRect = $mouse
@onready var default: TextureRect = $default

func _ready() -> void:
	texture_normal = null
	_on_mouse_exited()

func _on_mouse_entered() -> void:
	mouse.visible = true
	default.visible = false

func _on_mouse_exited() -> void:
	mouse.visible = false
	default.visible = true
