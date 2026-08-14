extends SceneTree
## 项目核查: 关键场景加载 + 干员/预览逻辑 + shader 编译
## 运行: godot --headless --path . --script res://test/project_check.gd
## 注: --script 模式下 Global/EventBus 等 autoload 全局类不可见属已知现象, 游戏内正常;
##     只关注 Parse Error / 真实脚本错误

var _fail_count := 0

func _init() -> void:
	## 1. 关键脚本语法加载
	print("===== 1. 脚本加载检查 =====")
	var scripts := [
		"res://scripts/character/operator/operator_000_base.gd",
		"res://scripts/character/operator/operator_001_kroos.gd",
		"res://scripts/character/operator/operator_spine_sprite.gd",
		"res://scripts/character/operator/operator_calibration.gd",
		"res://scripts/character/components/detect_component/component_detect_operator.gd",
		"res://scripts/character/components/detect_component/operator_range_preview.gd",
		"res://scripts/character/components/attack_behavior_component/component_attack_operator.gd",
		"res://scripts/character/components/anim_component/component_anim_operator.gd",
		"res://scripts/character/components/skill_component/skill_component.gd",
		"res://scripts/manager/hand_manager/hm_character.gd",
		"res://scripts/manager/hand_manager/hand_manager.gd",
		"res://scripts/manager/operator_manager.gd",
		"res://scripts/operator/operator_menu.gd",
		"res://scripts/operator/operator_menu_range_icon.gd",
		"res://scripts/manager/plant_cell_manager/plant_cell_manager.gd",
		"res://scripts/main_game_item/plant_cell.gd",
		"res://scripts/manager/main_game_manager.gd",
		"res://scripts/character/components/component_hurt_box_zombie.gd",
	]
	for f: String in scripts:
		var s = load(f)
		if s == null:
			_fail_count += 1
			print("[FAIL] 加载失败: ", f)
		else:
			print("[OK] ", f.get_file())

	## 2. 关键场景加载
	print("===== 2. 场景加载检查 =====")
	var scenes := [
		"res://scenes/character/operator/operator_001_kroos.tscn",
		"res://scenes/character/operator/operator_000_base.tscn",
		"res://scenes/operator/operator_menu.tscn",
		"res://scenes/manager/HandManager.tscn",
		"res://scenes/main/MainGame00Base.tscn",
		"res://scenes/main/MainGame01Front.tscn",
		"res://scenes/autoload/all_cards.tscn",
		"res://scenes/autoload/global.tscn",
		"res://scenes/main/00StartScreen.tscn",
		"res://scenes/main/00LoadingScreen.tscn",
		"res://scenes/main/01MainMenu.tscn",
	]
	for f: String in scenes:
		var s = load(f)
		if s == null:
			_fail_count += 1
			print("[FAIL] 场景加载失败: ", f)
		else:
			print("[OK] ", f.get_file())

	## 3. shader 编译
	print("===== 3. shader 检查 =====")
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/operator_range_stripes.gdshader")
	var uniforms := shader.get_shader_uniform_list()
	if uniforms.size() == 0:
		_fail_count += 1
		print("[FAIL] 条纹 shader 编译失败")
	else:
		print("[OK] 条纹 shader uniforms=", uniforms.size())

	## 4. 干员范围预览逻辑(独立验证, 不依赖主场景)
	print("===== 4. OperatorRangePreview 逻辑 =====")
	var preview = load("res://scripts/character/components/detect_component/operator_range_preview.gd").new()
	root.add_child(preview)
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
	if preview._fill_polygons.size() == 1:
		print("[OK] 范围合并单多边形, 顶点=", preview._fill_polygons[0].polygon.size())
	else:
		_fail_count += 1
		print("[FAIL] 范围合并异常: fill=", preview._fill_polygons.size())

	print("===== 结果: ", "全部通过" if _fail_count == 0 else "存在 %d 个失败" % _fail_count, " =====")
	quit()
