extends SpineSprite
class_name OperatorSpineSprite
## 干员 Spine 形象节点
## 挂载于 Body/BodyCorrect/OperatorSprite 下, 运行时加载明日方舟原始 3.8.99 skel+atlas 替换立绘占位
## 依赖: bin/ 内自编译 spine-godot GDExtension(Spine Runtime 3.8), 直接加载游戏原始数据, 无需版本转换
## 约定: _ready 只加载数据不自动播放动画 —— 部署预览(hm_character 复制本节点)需要静态形象;
##       由 Operator000Base.ready_norm -> play_enter_animation 播放入场动画
## 动画名: 战斗模型固定 Idle/Attack/Start/Die/Default(克洛斯已运行时验证, Die 为 1s 死亡动画)
## 注意: 3.8 移植版 set_animation(name, loop, track) / add_animation(name, delay, loop, track)
## 正/背面双素材: 主素材 = 正面(BattleFront), back_* 路径 = 背面(BattleBack, 方舟战斗中干员背对镜头视角);
##               转身时 switch_data 切换 skeleton_data_res 并保持当前动画

## skel 文件路径(res://) - 正面素材
@export var skel_path: String = ""
## atlas 文件路径(res://) - 正面素材
@export var atlas_path: String = ""
## 背面素材 skel 路径(空则不启用背面切换)
@export var back_skel_path: String = ""
## 背面素材 atlas 路径(空则不启用背面切换)
@export var back_atlas_path: String = ""

## 骨架数据是否已成功加载
var is_data_loaded := false
## 当前是否为背面素材
var is_back_data := false
## 最近一次播放的动画名(素材切换后重播用; 不用 get_current_anim_name 避免切换瞬间 state 失效)
var _last_anim_name := "Idle"

var _front_data: SpineSkeletonDataResource
var _back_data: SpineSkeletonDataResource

func _ready() -> void:
	## 已由外部设置过数据(部署预览复制出的节点等)则跳过重复加载
	if skeleton_data_res != null:
		is_data_loaded = true
		return
	load_data()

## 加载/重新加载骨架数据(调试工具切换干员时重新调用; 正面+背面各一套)
func load_data() -> void:
	_front_data = _load_data_res(skel_path, atlas_path)
	_back_data = _load_data_res(back_skel_path, back_atlas_path)
	skeleton_data_res = _front_data
	is_data_loaded = _front_data != null

## 加载一套 skel+atlas 数据
func _load_data_res(skel_p: String, atlas_p: String) -> SpineSkeletonDataResource:
	if skel_p.is_empty() or atlas_p.is_empty():
		return null
	var skel_res := SpineSkeletonFileResource.new()
	skel_res.load_from_file(skel_p)
	var atlas_res := SpineAtlasResource.new()
	atlas_res.load_from_atlas_file(atlas_p)
	var data_res := SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	return data_res

## 切换正/背面素材(转身): 切换 skeleton_data_res 并重播缓存动画(循环, 避免切换后动画停住)
## 数据懒加载: 复制节点(部署预览虚影)未预加载 _front_data/_back_data 时, 首次切换按路径加载
func switch_data(use_back: bool) -> void:
	if use_back == is_back_data:
		return
	if use_back and _back_data == null and not back_skel_path.is_empty():
		_back_data = _load_data_res(back_skel_path, back_atlas_path)
	elif not use_back and _front_data == null and not skel_path.is_empty():
		_front_data = _load_data_res(skel_path, atlas_path)
	var data := _back_data if use_back else _front_data
	if data == null:
		return
	is_back_data = use_back
	skeleton_data_res = data
	is_data_loaded = true
	## 重播缓存动画(切换后 Spine state 重置, 必须重播; 循环保证动画不停)
	play_spine(_last_anim_name, true)

## 播放动画(loop 为 true 时循环)
func play_spine(anim_name: String, loop: bool) -> void:
	if not is_data_loaded:
		return
	_last_anim_name = anim_name
	get_animation_state().set_animation(anim_name, loop, 0)

## 播放动画序列: first 播完后自动衔接循环的 next(用于入场 Start→Idle / 攻击 Attack→Idle)
func play_spine_sequence(first: String, next: String) -> void:
	if not is_data_loaded:
		return
	_last_anim_name = next
	var state := get_animation_state()
	state.set_animation(first, false, 0)
	state.add_animation(next, 0.0, true, 0)

## 当前轨道实际播放的动画名(无动画时返回空串)
func get_current_anim_name() -> String:
	if not is_data_loaded:
		return ""
	var track_entry := get_animation_state().get_current(0)
	if track_entry == null:
		return ""
	var anim := track_entry.get_animation()
	if anim == null:
		return ""
	return anim.get_name()

## 当前轨道动画时长(秒)
func get_current_anim_duration() -> float:
	if not is_data_loaded:
		return 0.0
	var track_entry := get_animation_state().get_current(0)
	if track_entry == null:
		return 0.0
	var anim := track_entry.get_animation()
	if anim == null:
		return 0.0
	return anim.get_duration()
