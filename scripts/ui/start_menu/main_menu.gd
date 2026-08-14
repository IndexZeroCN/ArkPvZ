extends Node3D
class_name MainMenu

## 主菜单（1:1 复刻 arknights-ui-master 明日方舟主界面，3D 版）
## 左面板 = LevelBox + LeftMenu，右面板 = RightMenu，分别渲染进 SubViewport 后贴到 Sprite3D
## 两 Sprite3D 绕 Y 轴向内凹陷（左 +18°、右 -18°），鼠标点击用相机射线命中面板并映射回 Control 按钮
## 2D 覆盖层（选项/用户/退出/对话框）在 CanvasLayer 上

@export var bgm: AudioStream
@onready var camera: Camera3D = $Camera3D
@onready var left_sprite: Sprite3D = %LeftSprite
@onready var right_sprite: Sprite3D = %RightSprite
@onready var left_content: Control = $LeftViewport/LeftContent
@onready var right_content: Control = $RightViewport/RightContent
@onready var dialog: Dialog = $CanvasLayer/Dialog
@onready var user_panel: Control = %UserPanel

## 内凹基础角（左 +18° 右 -18°，绕 Y 向内凹陷）—— 可在选项→开发者选项实时调整
var left_angle := 18.0
var right_angle := -18.0
## 鼠标跟随摆动幅度（度）
var swing_y := 9.0
var swing_x := 6.0
## 相机参数
var cam_fov := 40.0
var cam_dist := 15.0
var cam_height := 0.3
## 鼠标透视偏移程度（相机随鼠标平移的幅度倍率）
var cam_parallax := 1.0
## 面板缩放系数（左/右分别）
var left_panel_scale := 1.0
var right_panel_scale := 1.0

var _mouse_target := Vector2.ZERO
var _mouse_current := Vector2.ZERO

func _ready() -> void:
	SoundManager.setup_ui_start_menu_sound(self)
	SoundManager.play_bgm(bgm)
	Global.time_scale = 1.0
	Engine.time_scale = 1.0

	left_sprite.texture = $LeftViewport.get_texture()
	right_sprite.texture = $RightViewport.get_texture()
	_load_developer_options()
	camera.fov = cam_fov
	## 相机保持平行视角（rotation xyz 均为 0），不做 look_at 朝向调整

	_connect_menu_buttons()
	(%LevelName as Label).text = Global.user_manager.curr_user_name
	_update_currency()
	Global.global_game_state.coin_value_changed.connect(func(_v: int) -> void: _update_currency())
	_update_clock()


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 1.0:
		_clock_accum = 0.0
		_update_clock()
	_update_mouse_follow(delta)


## 读取已保存的开发者选项（全局选项；默认值与 developer_options.gd 的 PARAMS 一致，为用户 IndexZero 设定的全局数值）
func _load_developer_options() -> void:
	left_angle = Global.config_service.get_developer_option("left_angle", 18.5)
	right_angle = Global.config_service.get_developer_option("right_angle", -30.0)
	swing_y = Global.config_service.get_developer_option("swing_y", 5.0)
	swing_x = Global.config_service.get_developer_option("swing_x", 1.5)
	cam_fov = Global.config_service.get_developer_option("cam_fov", 25.0)
	cam_dist = Global.config_service.get_developer_option("cam_dist", 12.5)
	cam_height = Global.config_service.get_developer_option("cam_height", -0.7)
	cam_parallax = Global.config_service.get_developer_option("cam_parallax", 0.5)
	left_panel_scale = Global.config_service.get_developer_option("left_panel_scale", 1.0)
	right_panel_scale = Global.config_service.get_developer_option("right_panel_scale", 1.15)
	left_sprite.pixel_size = 0.01 * left_panel_scale
	right_sprite.pixel_size = 0.006 * right_panel_scale
	_update_mouse_follow(0.0)


## 开发者选项写入入口（developer_options.gd 调用），同时持久化
func set_developer_param(key: String, value: float) -> void:
	match key:
		"left_angle":
			left_angle = value
		"right_angle":
			right_angle = value
		"swing_y":
			swing_y = value
		"swing_x":
			swing_x = value
		"cam_fov":
			cam_fov = value
			camera.fov = value
		"cam_dist":
			cam_dist = value
		"cam_height":
			cam_height = value
		"cam_parallax":
			cam_parallax = value
		"left_panel_scale":
			left_panel_scale = value
			left_sprite.pixel_size = 0.01 * value
		"right_panel_scale":
			right_panel_scale = value
			right_sprite.pixel_size = 0.006 * value
	Global.config_service.set_developer_option(key, value)
	_update_mouse_follow(0.0)


## 鼠标跟随 3D 效果：面板绕 Y 摆动（保持内凹基础角）+ X 俯仰 + 相机轻微平移视差
func _update_mouse_follow(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	if mouse.x >= 0 and mouse.x <= size.x and mouse.y >= 0 and mouse.y <= size.y:
		_mouse_target = (mouse - size * 0.5) / (size * 0.5)
	_mouse_current = _mouse_current.lerp(_mouse_target, 1.5 * delta)
	var c := _mouse_current
	left_sprite.rotation_degrees.y = left_angle + c.x * swing_y
	right_sprite.rotation_degrees.y = right_angle + c.x * swing_y
	left_sprite.rotation_degrees.x = c.y * -swing_x
	right_sprite.rotation_degrees.x = c.y * -swing_x
	## 相机视差（轻微平移，幅度 × cam_parallax；相机始终保持平行视角 rotation=0）
	camera.position.x = c.x * 0.5 * cam_parallax
	camera.position.y = cam_height + c.y * -0.3 * cam_parallax
	camera.position.z = cam_dist
	camera.rotation = Vector3.ZERO


#region 输入：相机射线 → Sprite3D 面板 → Control 按钮
func _unhandled_input(event: InputEvent) -> void:
	## 更多选项(控制台)面板打开时不处理 3D 射线点击，避免穿透点到下层菜单按钮
	var console := get_node_or_null("ConsolePanel") as CanvasLayerConsole
	if console != null and console.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_menu_click(event.position)


func _handle_menu_click(screen_pos: Vector2) -> void:
	for pair in [[left_sprite, left_content], [right_sprite, right_content]]:
		var sprite: Sprite3D = pair[0]
		var content: Control = pair[1]
		var hit := _ray_intersect_sprite(sprite, screen_pos)
		if hit != Vector3.INF:
			var tex := sprite.texture
			var qw: float = tex.get_width() * sprite.pixel_size
			var qh: float = tex.get_height() * sprite.pixel_size
			var u := hit.x / qw + 0.5
			var v := 0.5 - hit.y / qh
			var pos := Vector2(u * content.size.x, v * content.size.y)
			var btn := _find_button(content, pos)
			if btn:
				btn.pressed.emit()
			return


## 相机射线与 Sprite3D 平面求交，返回 Sprite 本地坐标（平面在 XY，z=0）
func _ray_intersect_sprite(sprite: Sprite3D, screen_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var inv := sprite.global_transform.affine_inverse()
	var local_origin := inv * origin
	var local_dir := inv.basis * dir
	if abs(local_dir.z) < 0.0001:
		return Vector3.INF
	var t := -local_origin.z / local_dir.z
	if t < 0:
		return Vector3.INF
	var hit := local_origin + local_dir * t
	var half := Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.pixel_size * 0.5
	if abs(hit.x) <= half.x and abs(hit.y) <= half.y:
		return hit
	return Vector3.INF


## 在 Control 树中找包含点 pos（根本地坐标）的最上层 Button
func _find_button(root: Control, pos: Vector2) -> Button:
	for i in range(root.get_child_count() - 1, -1, -1):
		var child := root.get_child(i) as Control
		if child == null or not child.visible:
			continue
		var p := child.position
		var s := child.size
		if pos.x >= p.x and pos.x <= p.x + s.x and pos.y >= p.y and pos.y <= p.y + s.y:
			if child is Button:
				return child
			var sub := _find_button(child, pos - p)
			if sub:
				return sub
	return null
#endregion


#region 数据刷新
var _clock_accum := 0.0

func _update_currency() -> void:
	(right_content.get_node("Pos1/MoneyLabel") as Label).text = str(Global.global_game_state.coin_value)


func _update_clock() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var lbl := right_content.get_node("Pos1/TimeLabel") as Label
	lbl.text = "%04d/%02d/%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
#endregion


#region 按钮接线（射线命中后 emit pressed 触发）
func _connect_menu_buttons() -> void:
	right_content.get_node("Pos2/Battle/BattleBtn").pressed.connect(_on_battle_pressed)
	right_content.get_node("Pos4/Shop/ShopBtn").pressed.connect(_on_shop_pressed)
	right_content.get_node("Pos5/Infrastructure/InfrastructureBtn").pressed.connect(_on_infrastructure_pressed)
	left_content.get_node("LeftMenu/RightCol/Information/InformationBtn").pressed.connect(_on_information_pressed)
	for p in ["LeftMenu/RightCol/Friends/FriendsBtn"]:
		left_content.get_node(p).pressed.connect(_unrealized)
	for p in [
		"Pos3/Team/TeamBtn",
		"Pos3/Member/MemberBtn",
		"Pos4/Gamble/GambleBtn",
		"Pos4/GambleLeft/GambleLeftBtn",
		"Pos4/GambleRight/GambleRightBtn",
		"Pos5/Task/TaskBtn",
		"Pos5/Warehouse/WarehouseBtn",
	]:
		right_content.get_node(p).pressed.connect(_unrealized)


func _unrealized() -> void:
	dialog.appear_dialog()


## 作战 → 冒险选关
func _on_battle_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])

## 基建 → 花园
func _on_infrastructure_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Garden])

## 采购中心 → 商店
func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store])

## 情报 → 图鉴
func _on_information_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac])

## 选项 / 用户 / 退出
func _on_option_pressed() -> void:
	%OptionDialog.appear_menu()

func _on_user_pressed() -> void:
	user_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()
#endregion
