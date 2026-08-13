extends SceneTree

# TrailComet 彗星拖尾组件冒烟测试（无窗口检查, 组件零 autoload 依赖）
# 运行: godot --headless --path . --script res://test/trail_comet_check.gd
# 验证: 父节点移动时组件记录轨迹生成双层 Line2D 亮带(柔光+亮芯, 点数增长/尾部在后方/加色材质);
#       头部沿飞行方向延伸(head_extend)接上弹头后端;
#       detach_and_fade 脱离子弹留在原地淡出

func _initialize() -> void:
	var packed: GDScript = load("res://scripts/bullet/component/trail_comet.gd")
	print("拖尾组件脚本加载: ", packed != null)
	## 用脚本直接创建组件(不依赖具体场景)
	var holder := Node2D.new()
	root.add_child(holder)
	var trail: Node = packed.new()
	trail.name = "Trail"
	## 拖尾代替炮弹本体: 头部延伸为 0(亮带头部=子弹当前位置)
	trail.set("head_extend", 0.0)
	holder.add_child(trail)
	## 模拟子弹直线飞行: 每物理帧向右移动 10px
	holder.position = Vector2.ZERO
	for i in range(50):
		holder.position.x += 10.0
		await physics_frame
	## 找出两层亮带(柔光 + 亮芯)
	var lines: Array[Line2D] = []
	for c in trail.get_children():
		if c is Line2D:
			lines.append(c)
	var ok := lines.size() == 2
	print("双层亮带数量: ", lines.size(), " (应为2)")
	if not ok:
		print("结果: 失败 (亮带数量不对)")
		quit()
		return
	## 柔光比亮芯宽
	var core: Line2D = lines[1] if lines[1].width < lines[0].width else lines[0]
	var glow: Line2D = lines[0] if lines[0] != core else lines[1]
	print("亮芯宽度: ", core.width, " 柔光宽度: ", glow.width, " 柔光更宽: ", glow.width > core.width)
	## 默认普通混合(无材质=混合); 检查不是加色(暗红可直接呈现)
	var not_additive: bool = core.material == null or (core.material as CanvasItemMaterial).blend_mode != CanvasItemMaterial.BLEND_MODE_ADD
	print("普通混合(非加色): ", not_additive)
	ok = ok and glow.width > core.width
	ok = ok and not_additive
	ok = ok and core.points.size() >= 10
	print("亮芯点数: ", core.points.size(), " (应为 20~56)")
	## 尾部(首点)比头部(末点)更靠左; 头部延伸为 0 时末点即子弹当前位置
	if core.points.size() >= 3:
		var first_x: float = trail.to_global(core.points[0]).x
		var last_x: float = trail.to_global(core.points[core.points.size() - 1]).x
		var second_last_x: float = trail.to_global(core.points[core.points.size() - 2]).x
		print("尾部 x=", snappedf(first_x, 1.0), " 头部 x=", snappedf(last_x, 1.0), " 尾部在后方: ", first_x < last_x)
		print("头部延伸量: ", snappedf(last_x - second_last_x, 1.0), " (应≈10 单帧间距, 无额外延伸)")
		ok = ok and first_x < last_x - 20.0
		ok = ok and last_x - second_last_x < 15.0
	## detach_and_fade: 拖尾脱离子弹并留在原地
	trail.detach_and_fade()
	await process_frame
	print("detach 后拖尾父节点已不是原父: ", is_instance_valid(trail) and trail.get_parent() != holder)
	ok = ok and is_instance_valid(trail) and trail.get_parent() != holder
	## setup() 运行时重建: 单层(无柔光) / 发光(加色)
	var single_ok := false
	if is_instance_valid(trail) and trail.has_method("setup"):
		trail.setup(30, Color(1, 0, 0), 1)
		var n: int = 0
		for c in trail.get_children():
			if c is Line2D:
				n += 1
		var mat_add := false
		for c in trail.get_children():
			if c is Line2D and (c as Line2D).material != null:
				mat_add = true
		single_ok = n == 1 and not mat_add
		print("setup 单层样式: 亮带数=", n, " 无加色: ", not mat_add)
		trail.setup(30, Color(1, 0.2, 0.1), 2)
		n = 0
		mat_add = false
		for c in trail.get_children():
			if c is Line2D:
				n += 1
				if (c as Line2D).material != null and (c as Line2D).material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
					mat_add = true
		single_ok = single_ok and n == 2 and mat_add
		print("setup 发光样式: 亮带数=", n, " 有加色: ", mat_add)
	ok = ok and single_ok
	holder.queue_free()
	print("结果: ", "通过" if ok else "失败")
	quit()
