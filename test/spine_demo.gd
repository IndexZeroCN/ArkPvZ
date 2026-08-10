extends Node2D

# 明日方舟 Spine 模型可视化演示（左: 战斗模型 Idle | 右: 基建模型 Relax）
# 运行: godot --path . res://test/spine_demo.tscn
# 素材: assets/image/operator/kroos/（原始 Spine 3.8.99）

func _make_sprite(skel_path: String, atlas_path: String, pos: Vector2, anim: String) -> void:
	var skel_res = SpineSkeletonFileResource.new()
	skel_res.load_from_file(skel_path)
	var atlas_res = SpineAtlasResource.new()
	atlas_res.load_from_atlas_file(atlas_path)
	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res = atlas_res
	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	sprite.position = pos
	sprite.get_animation_state().set_animation(anim, true, 0)
	add_child(sprite)

func _ready() -> void:
	_make_sprite(
		"res://assets/image/operator/kroos/char_124_kroos.skel",
		"res://assets/image/operator/kroos/char_124_kroos.atlas",
		Vector2(320, 540), "Idle"
	)
	_make_sprite(
		"res://assets/image/operator/kroos/build_char_124_kroos.skel",
		"res://assets/image/operator/kroos/build_char_124_kroos.atlas",
		Vector2(740, 540), "Relax"
	)
