extends Control
class_name LoadingScreen

## 加载界面（1:1 复刻明日方舟 LoginUI.loadingPanel：双进度条向中间收敛，InQuint 加速）
## 流程：加载主菜单场景 → 加载全部卡片场景 → 预热 AllCards/全部音效/种植数据 → 2s 停顿 → 进入主菜单
## 规格参考：docs/明日方舟复刻_开始加载主菜单_规格说明.md §5
## 说明：Godot 4.7 下对 all_cards.tscn 使用 load_threaded_request 会卡在 50%，故采用
## 分段同步加载 + InQuint 进度动画的方式，启动耗时可控且能明确反馈进度。
## 注意：2026-08 起【暂时跳过加载界面画面】，直接进入主菜单（恢复加载界面时撤销 _ready 的改动即可）。

const ALL_CARDS_SCENE_PATH := "res://scenes/autoload/all_cards.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main/01MainMenu.tscn"
const TRACK_WIDTH := 460.0
## 每阶段进度动画时长（InQuint 加速）
const STAGE_ANIM_DURATION := 0.8

@onready var bar_left: ColorRect = %BarLeft
@onready var bar_right: ColorRect = %BarRight
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel

var _display_progress := 0.0
var _bar_tween: Tween
var _finished := false

func _ready() -> void:
	## 暂时跳过加载界面画面：直接进入主菜单。
	## AllCards/音效/种植数据保持懒加载（首次使用时加载），需要时再恢复下方的 _start_loading 流程。
	## 必须 call_deferred：_ready 时场景仍在入树，立即 change_scene 会报 "Parent node is busy adding/removing children"
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE_PATH)


## 分段加载：主菜单（快）→ 全部卡片（慢）→ 预热音效/种植数据 → 2s 停顿 → 主菜单
## 耗启动时间的加载项全部集中在此加载：启动预加载项均已改为懒加载，由这里主动预热
func _start_loading() -> void:
	_set_stage(0.12, "正在加载主菜单…")
	_main_menu_scene = load(MAIN_MENU_SCENE_PATH)
	if _main_menu_scene == null:
		printerr("加载主菜单失败: ", MAIN_MENU_SCENE_PATH)
		_set_stage(1.0, "加载失败")
		return

	_set_stage(0.32, "正在加载卡片…")
	var all_cards: PackedScene = load(ALL_CARDS_SCENE_PATH)
	if all_cards == null:
		printerr("加载卡片场景失败: ", ALL_CARDS_SCENE_PATH)
		_set_stage(1.0, "加载失败")
		return

	_set_stage(0.55, "正在初始化卡片…")
	## 预热 AllCards：实例化全部卡片，避免进入选卡/图鉴后卡顿
	AllCards.warm_up()

	_set_stage(0.75, "正在加载音效…")
	## 预热全部音效（原启动时 129 处 preload，已改为懒加载，这里统一加载）
	SoundManager.warm_up()

	_set_stage(0.9, "正在加载种植数据…")
	## 预热种植条件资源与干员技能图标
	Global.character_registry.warm_up()

	_finished = true
	_set_stage(1.0, "完成")
	tip_label.text = "完成"
	## 规格 §5.2：进度完成后停顿再进入主菜单（启动提速后由 2s 缩短为 0.8s）
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_packed(_main_menu_scene)


var _main_menu_scene: PackedScene

## 设置阶段目标进度（InQuint 加速动画向目标收敛）
func _set_stage(target_progress: float, tip_text: String) -> void:
	tip_label.text = tip_text
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_bar_tween.tween_method(_set_progress, _display_progress, target_progress, STAGE_ANIM_DURATION)
	_display_progress = target_progress


func _set_progress(value: float) -> void:
	var half := TRACK_WIDTH * 0.5 * value
	bar_left.size.x = half
	bar_right.size.x = half
	percent_label.text = "%d%%" % int(value * 100.0)
