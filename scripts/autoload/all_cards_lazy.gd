extends Node
## AllCards 懒加载自动加载脚本
## 原 all_cards.tscn 场景包含全部卡片（约 767 张贴图、1908 个节点），作为自动加载场景会拖慢启动。
## 改为脚本自动加载：首次访问卡片属性时才真正实例化该场景，并在此缓存。
## 业务代码仍以 `AllCards.all_plant_card_prefabs` 等方式访问，接口保持不变。

const ALL_CARDS_SCENE_PATH := "res://scenes/autoload/all_cards.tscn"

var _cards_scene: Node
var _loaded := false

## 确保卡片场景已加载（首次访问属性时自动触发）
func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var packed: PackedScene = load(ALL_CARDS_SCENE_PATH)
	_cards_scene = packed.instantiate()
	add_child(_cards_scene)

## 主动预热：强制完成卡片场景实例化（加载界面在进入主菜单前调用，避免选卡时卡顿）
func warm_up() -> void:
	_ensure_loaded()

var all_plant_card_prefabs: Dictionary:
	get:
		_ensure_loaded()
		return _cards_scene.all_plant_card_prefabs

var all_zombie_card_prefabs: Dictionary:
	get:
		_ensure_loaded()
		return _cards_scene.all_zombie_card_prefabs

var plant_card_ids: Dictionary:
	get:
		_ensure_loaded()
		return _cards_scene.plant_card_ids

var zombie_card_ids: Dictionary:
	get:
		_ensure_loaded()
		return _cards_scene.zombie_card_ids
