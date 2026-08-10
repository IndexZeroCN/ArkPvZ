extends SceneTree
## 验证 OperatorRangePreview: 间距矩形 + 角相邻直角桥接合并为连续多边形 + shader 条纹加载
## 运行: godot --headless --path . --script res://test/range_preview_check.gd

func _init() -> void:
	print("=== 预览: 间距矩形 + 角相邻直角桥接 ===")
	var preview = load("res://scripts/character/components/detect_component/operator_range_preview.gd").new()
	root.add_child(preview)
	## 模拟克洛丝朝右范围(3行x4列, 含干员所在格(0,0)), 中心 = 网格中心
	var spacing := Vector2(80, 96)
	var base_pos := Vector2(400, 300)
	var centers: Array[Vector2] = []
	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3),
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	]
	for o: Vector2i in offsets:
		centers.append(base_pos + Vector2(o.y * spacing.x, o.x * spacing.y))
	preview.set_range_cells(centers, spacing, base_pos)
	preview.show_hint = true
	print("[range_preview] fill=", preview._fill_polygons.size(), " (期望 1 个连续多边形)")
	if preview._fill_polygons.size() == 1:
		var poly: PackedVector2Array = preview._fill_polygons[0].polygon
		print("[range_preview] 顶点数=", poly.size())
		## 检查所有角是否为 90°(连续三点转角)
		var all_90 := true
		for k in poly.size():
			var a: Vector2 = poly[k]
			var b: Vector2 = poly[(k + 1) % poly.size()]
			var c: Vector2 = poly[(k + 2) % poly.size()]
			var v1 := b - a
			var v2 := c - b
			if v1.length_squared() < 0.01 or v2.length_squared() < 0.01:
				continue
			var dot: float = v1.normalized().dot(v2.normalized())
			if absf(dot) > 0.05:  # 允许 ±3° 误差
				all_90 = false
				print("[range_preview] 非直角顶点: ", b, " dot=", dot)
		print("[range_preview] 全部 90° 直角: ", all_90)
	## 同一数据再调一次, 应跳过重建(数量不变)
	preview.set_range_cells(centers, spacing, base_pos)
	print("[range_preview] 重复调用后 fill=", preview._fill_polygons.size())

	print("=== 缺角形状(不含干员格, 验证直角桥接) ===")
	var centers2: Array[Vector2] = []
	var offsets2: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3),
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	]
	for o: Vector2i in offsets2:
		centers2.append(base_pos + Vector2(o.y * spacing.x, o.x * spacing.y))
	preview.set_range_cells(centers2, spacing, base_pos)
	print("[range_preview] 缺角 fill=", preview._fill_polygons.size())
	if preview._fill_polygons.size() == 1:
		var poly: PackedVector2Array = preview._fill_polygons[0].polygon
		print("[range_preview] 缺角顶点数=", poly.size())
		var all_90 := true
		for k in poly.size():
			var a: Vector2 = poly[k]
			var b: Vector2 = poly[(k + 1) % poly.size()]
			var c: Vector2 = poly[(k + 2) % poly.size()]
			var v1 := b - a
			var v2 := c - b
			if v1.length_squared() < 0.01 or v2.length_squared() < 0.01:
				continue
			var dot: float = v1.normalized().dot(v2.normalized())
			if absf(dot) > 0.05:
				all_90 = false
				print("[range_preview] 缺角非直角顶点: ", b, " dot=", dot)
		print("[range_preview] 缺角全部 90° 直角: ", all_90)
	await process_frame
	await process_frame
	print("[range_preview] OK")
	quit()
