extends SceneTree
func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/character/operator/operator_001_kroos.tscn")
	var op: Node = scene.instantiate()
	root.add_child(op)
	await create_timer(2.0).timeout
	var spine = op.get_operator_spine()
	print("2 秒后动画: '", spine.get_current_anim_name(), "' (应为 Idle)")
	# 模拟攻击动画调用
	spine.play_spine_sequence("Attack", "Idle")
	print("攻击后动画: '", spine.get_current_anim_name(), "'")
	await create_timer(1.2).timeout
	print("攻击后 1.2 秒动画: '", spine.get_current_anim_name(), "' (应为 Idle)")
	# 模拟死亡动画
	spine.play_spine("Die", false)
	await create_timer(0.2).timeout
	print("死亡动画: '", spine.get_current_anim_name(), "'")
	quit()
