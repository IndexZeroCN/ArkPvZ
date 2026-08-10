extends Node2D
# 克洛丝 Spine 朝向查看: 新提取的 BattleBack(战斗背面) vs 旧素材(正面)
# 运行: godot --path . res://test/operator_back_view.tscn

func _ready() -> void:
	## 新提取的 BattleBack(战斗背面) - 原始朝向
	_make_sprite("res://assets/image/operator/kroos/back/char_124_kroos.skel",
		"res://assets/image/operator/kroos/back/char_124_kroos.atlas",
		Vector2(300, 430), 1.0, "BattleBack(新) scale=+1", "Idle")
	## 旧素材(战斗正面) 对照
	_make_sprite("res://assets/image/operator/kroos/char_124_kroos.skel",
		"res://assets/image/operator/kroos/char_124_kroos.atlas",
		Vector2(760, 430), 1.0, "旧素材(正面) scale=+1", "Idle")

func _make_sprite(skel_path: String, atlas_path: String, pos: Vector2, scale_x: float, label: String, anim: String) -> void:
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
	sprite.scale.x = scale_x
	sprite.scale.y = 1.0
	sprite.get_animation_state().set_animation(anim, true, 0)
	add_child(sprite)
	var label_node := Label.new()
	label_node.text = label
	label_node.position = pos + Vector2(-100, -180)
	label_node.add_theme_font_size_override("font_size", 14)
	add_child(label_node)
