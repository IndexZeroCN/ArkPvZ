extends SceneTree

# 桃金娘 Spine 素材冒烟测试（无窗口检查）
# 运行: godot --headless --path . --script res://test/myrtle_spine_check.gd
# 验证 char_151_myrtle 正/背面战斗模型 skel/atlas 可加载, 动画名 Idle_/Attack_/Start_/Die_/Skill_* 可播放

func _check(skel_path: String, atlas_path: String, anims: Array[String], label: String) -> bool:
	var skel_res = SpineSkeletonFileResource.new()
	skel_res.load_from_file(skel_path)
	var atlas_res = SpineAtlasResource.new()
	atlas_res.load_from_atlas_file(atlas_path)
	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	print("%s: 骨架数据已加载 = %s" % [label, data_res.is_skeleton_data_loaded()])
	if not data_res.is_skeleton_data_loaded():
		return false
	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	root.add_child(sprite)
	for anim in anims:
		sprite.get_animation_state().set_animation(anim, true, 0)
		print("%s: 播放 %s 成功" % [label, anim])
	return true

func _initialize() -> void:
	print("SpineSprite 类存在: ", ClassDB.class_exists("SpineSprite"))
	_check(
		"res://assets/image/operator/myrtle/char_151_myrtle.skel",
		"res://assets/image/operator/myrtle/char_151_myrtle.atlas",
		["Idle", "Attack", "Start", "Die", "Skill_Begin", "Skill_Loop", "Skill_End"],
		"正面战斗模型"
	)
	_check(
		"res://assets/image/operator/myrtle/back/char_151_myrtle.skel",
		"res://assets/image/operator/myrtle/back/char_151_myrtle.atlas",
		["Idle", "Attack", "Start", "Die"],
		"背面战斗模型"
	)
	quit()
