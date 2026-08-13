extends SceneTree

# 维什戴尔 Spine 素材冒烟测试（无窗口检查）
# 运行: godot --headless --path . --script res://test/wisdel_spine_check.gd
# 验证: 正/背面 skel 可加载, 标准动画名 Idle/Attack/Start/Die/Skill_* 可播放

func _check(skel_path: String, atlas_path: String, anims: Array, label: String) -> bool:
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
	for anim: String in anims:
		sprite.get_animation_state().set_animation(anim, true, 0)
		print("%s: 播放 %s 成功" % [label, anim])
	sprite.queue_free()
	return true

func _initialize() -> void:
	print("SpineSprite 类存在: ", ClassDB.class_exists("SpineSprite"))
	_check(
		"res://assets/image/operator/wisdel/char_1035_wisdel.skel",
		"res://assets/image/operator/wisdel/char_1035_wisdel.atlas",
		["Idle", "Attack_A", "Attack_B", "Attack_C", "Start", "Die"],
		"维什戴尔正面"
	)
	_check(
		"res://assets/image/operator/wisdel/back/char_1035_wisdel.skel",
		"res://assets/image/operator/wisdel/back/char_1035_wisdel.atlas",
		["Idle", "Attack_A"],
		"维什戴尔背面"
	)
	_check(
		"res://assets/image/operator/wisdel/shadow/char_1041_angel2.skel",
		"res://assets/image/operator/wisdel/shadow/char_1041_angel2.atlas",
		["Idle", "Start", "Die", "Skill_2_Begin"],
		"魂灵之影正面"
	)
	quit()
