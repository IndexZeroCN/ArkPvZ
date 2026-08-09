extends SceneTree

func _initialize() -> void:
	print("SpineSprite: ", ClassDB.class_exists("SpineSprite"))
	var skel_res = load("res://assets/image/operator/kroos/char_124_kroos_v42.skel")
	var atlas_res = load("res://assets/image/operator/kroos/char_124_kroos_256.atlas")
	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	var anim_names: Array = []
	if data_res.has_method("get_animation_count") and data_res.has_method("get_animation_name"):
		for i in data_res.get_animation_count():
			anim_names.append(data_res.get_animation_name(i))
	print("动画名: ", anim_names)
	if anim_names.is_empty():
		quit()
	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	root.add_child(sprite)
	sprite.get_animation_state().set_animation("Idle", true, 0)
	print("播放 Idle 成功")
	quit()
