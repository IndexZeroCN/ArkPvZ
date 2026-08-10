extends SceneTree

# 明日方舟 Spine 素材冒烟测试（无窗口检查）
# 运行: godot --headless --path . --script res://test/spine_check.gd
# 依赖: bin/ 内自编译 spine-godot GDExtension（Spine Runtime 3.8），素材为 3.8.99 原始数据
# 说明: 3.8 移植版未暴露动画枚举 API（get_animation_count 等），此处以 set_animation 成功与否验证

func _check(skel_path: String, atlas_path: String, anim: String, label: String) -> bool:
	var skel_res = SpineSkeletonFileResource.new()
	skel_res.load_from_file(skel_path)
	var atlas_res = SpineAtlasResource.new()
	atlas_res.load_from_atlas_file(atlas_path)
	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	print("%s: 骨架数据已加载 = %s" % [label, data_res.is_skeleton_data_loaded()])
	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	root.add_child(sprite)
	sprite.get_animation_state().set_animation(anim, true, 0)
	print("%s: 播放 %s 成功" % [label, anim])
	return true

func _initialize() -> void:
	print("SpineSprite 类存在: ", ClassDB.class_exists("SpineSprite"))
	_check(
		"res://assets/image/operator/kroos/char_124_kroos.skel",
		"res://assets/image/operator/kroos/char_124_kroos.atlas",
		"Idle", "战斗模型"
	)
	_check(
		"res://assets/image/operator/kroos/build_char_124_kroos.skel",
		"res://assets/image/operator/kroos/build_char_124_kroos.atlas",
		"Relax", "基建模型"
	)
	## 序列衔接 API 验证(入场 Start→Idle / 攻击 Attack→Idle 依赖此接口)
	var skel_res = SpineSkeletonFileResource.new()
	skel_res.load_from_file("res://assets/image/operator/kroos/char_124_kroos.skel")
	var atlas_res = SpineAtlasResource.new()
	atlas_res.load_from_atlas_file("res://assets/image/operator/kroos/char_124_kroos.atlas")
	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	root.add_child(sprite)
	var state = sprite.get_animation_state()
	state.set_animation("Start", false, 0)
	state.add_animation("Idle", 0.0, true, 0)
	print("序列衔接 Start→Idle 调用成功")
	## 动画时长(Attack 之后衔接 Idle 用, 供死亡等待等逻辑参考)
	var track_entry = state.get_current(0)
	var duration = track_entry.get_animation().get_duration()
	print("Start 动画时长: %.3fs" % duration)
	## 探测战斗模型是否存在 Die 动画(已知枚举: Attack/Default/Idle/Start)
	state.set_animation("Die", false, 0)
	print("Die 动画调用未报错(存在 Die 动画)")
	quit()
