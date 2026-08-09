extends Control
class_name StoreManager

@onready var crazy_dave: CrazyDave = $CrazyDave
@export var all_goods :Array[Goods]
@onready var confirm_goods: ConfirmGoods = $ConfirmGoods

## 离开商店页信号
signal signal_exit_store

# 进入场景树时执行（首次就绪）
func _ready() -> void:
	Global.save_service.save_now()
	for goods in all_goods:
		goods.look_goods_signal.connect(crazy_dave.external_trigger_dialog)
		goods.look_end_goods_signal.connect(crazy_dave.external_trigger_dialog_end)
		## 确认购买页面
		goods.signal_pressed_this_goods.connect(confirm_goods.appear_canvas_layer.bind(goods))

## 离开商店
func _on_store_main_menu_button_pressed() -> void:
	signal_exit_store.emit()
	Global.save_service.save_now()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	else:
		queue_free()

