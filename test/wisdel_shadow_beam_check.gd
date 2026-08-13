extends SceneTree

# 魂灵之影攻击射线特效冒烟测试（无窗口检查）
# 运行: godot --headless --path . --script res://test/wisdel_shadow_beam_check.gd
# 验证: 特效场景可实例化, fire() 伸展射线, 命中信号发出, 特效自行销毁

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/fx/wisdel_shadow_beam.tscn")
	print("场景加载: ", packed != null)
	var fx: WisdelShadowBeam = packed.instantiate()
	root.add_child(fx)
	var hit_ok := [false]
	fx.signal_beam_hit.connect(func(): hit_ok[0] = true)
	fx.fire(Vector2(700, 400), Vector2(200, 250), 40)
	print("fire 后射线旋转(度): ", snappedf(rad_to_deg(fx.rotation), 0.1))
	## 驱动帧循环, 观察射线伸展与自销毁
	var freed := false
	for i in range(600):
		await process_frame
		if i == 3:
			print("第3帧 射线 scale.x = ", snappedf(fx.beam.scale.x, 0.01), " (伸展中)")
		if i % 120 == 119 and is_instance_valid(fx):
			print("第", i + 1, "帧: 特效存活, burst可见=", fx.burst.visible, " beam alpha=", snappedf(fx.beam.modulate.a, 0.01))
		if not is_instance_valid(fx):
			freed = true
			print("第", i, "帧: 特效已自行销毁")
			break
	if is_instance_valid(fx):
		print("命中信号: ", hit_ok[0], " 特效仍在(600帧内未销毁)")
		fx.queue_free()
	else:
		print("命中信号: ", hit_ok[0])
	print("结果: ", "通过" if hit_ok[0] and freed else "失败")
	quit()
