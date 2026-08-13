extends SceneTree

# 维什戴尔干员场景冒烟测试（无窗口检查, 同步版无 await）
# 运行: godot --headless --path . --script res://test/wisdel_operator_check.gd
# 验证: 场景可实例化, Spine 数据可加载, 技能配置(按 operator_skill_id)生效, 攻击范围形状正确

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/character/operator/operator_002_wisdel.tscn")
	var op: Operator002Wisdel = scene.instantiate() as Operator002Wisdel
	root.add_child(op)
	op.set_physics_process(false)
	print("Spine 有效: ", is_instance_valid(op.get_operator_spine()))
	var spine := op.get_operator_spine()
	if is_instance_valid(spine):
		print("Spine 数据已加载: ", (spine as OperatorSpineSprite).is_data_loaded)
	print("默认技能组件 max_sp: ", op.skill_component.max_sp, " (应为 2, 一技能)")
	print("攻击范围形状格子数: ", op.get_attack_range_shape().size(), " (应为 19)")
	## 切换为三技能(爆裂黎明): SP50/初始40/时间回复/手动触发
	op.apply_operator_skill(3)
	print("三技能 max_sp: ", op.skill_component.max_sp, " (应为 50)")
	print("三技能 initial_sp: ", op.skill_component.initial_sp, " (应为 40)")
	print("三技能 curr_sp: ", op.skill_component.curr_sp, " (应为 40)")
	print("三技能回复方式: ", op.skill_component.sp_recovery_type, " (应为 1 Time)")
	print("三技能自动触发: ", op.skill_component.is_auto_trigger, " (应为 false)")
	## 二技能(饱和复仇): SP25/初始15
	op.apply_operator_skill(2)
	print("二技能 max_sp: ", op.skill_component.max_sp, " (应为 25)")
	print("二技能 curr_sp: ", op.skill_component.curr_sp, " (应为 15)")
	## 召唤物场景
	var sum_scene: PackedScene = load("res://scenes/character/operator/summon_002_wisdel_shadow.tscn")
	var sum: Summon002WisdelShadow = sum_scene.instantiate() as Summon002WisdelShadow
	root.add_child(sum)
	sum.set_physics_process(false)
	print("召唤物实例有效: ", is_instance_valid(sum))
	print("召唤物技能 max_sp: ", sum.skill_component.max_sp, " (应为 5)")
	print("召唤物范围形状继承测试: ", sum.get_attack_range_shape().size())
	quit()
