extends Node
## 散落的加载场景
## 注意：全部改为懒加载（首次访问时才 load），避免启动时预加载这些场景拖慢进入开始界面

## 懒加载缓存（按路径缓存）
var _scene_cache: Dictionary = {}

## 按路径懒加载场景
func _lazy_scene(scene_path: String) -> PackedScene:
	if not _scene_cache.has(scene_path):
		_scene_cache[scene_path] = load(scene_path)
	return _scene_cache[scene_path]

## 花园植物格子
var PLANT_CELL_GARDEN:PackedScene:
	get: return _lazy_scene("res://scenes/garden/plant_cell_garden.tscn")
## 花园需求气泡
var GARDEN_SPEECH_BUBBLE:PackedScene:
	get: return _lazy_scene("res://scenes/garden/garden_speech_bubble.tscn")
## 花园花盆
var GARDEN_FLOWER_POT:PackedScene:
	get: return _lazy_scene("res://scenes/garden/garden_flower_pot.tscn")

## 戴夫
var CRAZY_DAVE:PackedScene:
	get: return _lazy_scene("res://scenes/crazy_dave/crazy_dave.tscn")

## 提示信息
var REMINDER_INFORMATION:PackedScene:
	get: return _lazy_scene("res://scenes/ui/reminder_information.tscn")

## 钻石、金币、银币
var COIN_DIAMOND:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/drop/coin_diamond.tscn")
var COIN_GOLD:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/drop/coin_gold.tscn")
var COIN_SILVER:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/drop/coin_silver.tscn")
var PRESENT:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/drop/present.tscn")

## 待选卡槽
var CARD_CANDIDATE_CONTAINER:PackedScene:
	get: return _lazy_scene("res://scenes/ui/all_cards/card_candidate_container.tscn")
## 植物种植特效
var PLANT_START_EFFECT:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/plant_effect/plant_start_effect.tscn")
var PLANT_START_EFFECT_WATER:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/plant_effect/plant_start_effect_water.tscn")

## 坑洞
var DOOM_SHROOM_CRATER:PackedScene:
	get: return _lazy_scene("res://scenes/fx/doom_shroom_crater.tscn")

## 墓碑
var TOMBSTONE:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/tombstone.tscn")

## 舞王管理器
var JACKSON_MANAGER:PackedScene:
	get: return _lazy_scene("res://scenes/character/components/jackson_manager.tscn")

## 奖杯
var TROPHY:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/trophy.tscn")

## 冰冻僵尸特效
var ICE_EFFECT:PackedScene:
	get: return _lazy_scene("res://scenes/fx/ice_effect.tscn")
## 泳池水花场景
var SPLASH:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/splash.tscn")
## 火焰特效(火爆辣椒\火焰豌豆)
var FIRE:PackedScene:
	get: return _lazy_scene("res://scenes/fx/fire.tscn")
## 黄油特效
var BUTTER_SPLAT:PackedScene:
	get: return _lazy_scene("res://scenes/fx/butter_splat.tscn")
## 魂灵之影攻击射线特效
var WISDEL_SHADOW_BEAM:PackedScene:
	get: return _lazy_scene("res://scenes/fx/wisdel_shadow_beam.tscn")
## 樱桃炸弹爆炸特效(维什戴尔三技能命中敌人时播放)
var CHERRY_BOMB_EFFECT:PackedScene:
	get: return _lazy_scene("res://scenes/fx/cherry_bomb_effect.tscn")

## 阳光
var SUN:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/sun.tscn")

## 泥土上升特效
var DIRT_RISE_EFFECT:PackedScene:
	get: return _lazy_scene("res://scenes/character/item/dirt_rise_effect.tscn")

## 梯子
var LADDER:PackedScene:
	get: return _lazy_scene("res://scenes/item/game_scenes_item/ladder.tscn")
