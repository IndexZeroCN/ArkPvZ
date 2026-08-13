extends DetectComponent
class_name DetectComponentOperator
## 干员攻击范围检测组件
## 检测有限攻击范围内的僵尸(范围形状按部署方向旋转), 不依赖单行射线
## 继承 DetectComponent(兼容攻击组件的类型判断与信号), 覆盖检测逻辑

## 攻击范围形状: (行偏移, 列偏移), 以干员所在格为基准
## 默认(克洛丝, 速射手满级)范围: 3行x4列, 干员在中间行最左列
## 其他干员覆盖 Operator000Base.get_attack_range_shape() 返回自己的形状
const ATTACK_RANGE_SHAPE: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3),
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
]

## 默认草坪格子尺寸(像素, 兜底值; 有真实植物格时用真实网格间距)
const GRID_CELL_SIZE := Vector2(76, 95)

## 索敌轮询间隔(秒): 干员狙击式攻击需要快速反应, 比普通植物射线检测更频繁
const POLL_INTERVAL := 0.05

## 将(行,列)偏移按方向转换为世界偏移(格子尺寸换算)
static func get_world_delta(offset: Vector2i, direction: Operator000Base.E_AttackDirection, cell_size: Vector2) -> Vector2:
	var row_delta: float = offset.x * cell_size.y
	var col_delta: float = offset.y * cell_size.x
	match direction:
		Operator000Base.E_AttackDirection.Left:
			return Vector2(-col_delta, row_delta)
		Operator000Base.E_AttackDirection.Up:
			## 前方(列)朝上, 侧翼(行)左右
			return Vector2(row_delta, -col_delta)
		Operator000Base.E_AttackDirection.Down:
			return Vector2(-row_delta, col_delta)
		## 默认朝右
		_:
			return Vector2(col_delta, row_delta)

## 将范围形状的行列偏移按部署方向旋转为目标格偏移(行, 列)
## Right 行下/列右, Left 行下/列左, Up 行左/列上, Down 行右/列下(与 get_world_delta 一致)
static func rotate_offset(offset: Vector2i, direction: Operator000Base.E_AttackDirection) -> Vector2i:
	match direction:
		Operator000Base.E_AttackDirection.Left:
			return Vector2i(offset.x, -offset.y)
		Operator000Base.E_AttackDirection.Up:
			return Vector2i(-offset.y, offset.x)
		Operator000Base.E_AttackDirection.Down:
			return Vector2i(offset.y, -offset.x)
		## 默认朝右
		_:
			return offset

## 获取网格间距(相邻格子中心距离); 优先取右侧/下侧相邻格, 无则取左侧/上侧, 兜底用格子尺寸
static func get_grid_spacing(cell: PlantCell) -> Vector2:
	var spacing: Vector2 = cell.size
	var rc: Vector2i = cell.row_col
	var total: Vector2i = Global.main_game.plant_cell_manager.row_col
	var all_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	if rc.y + 1 < total.y:
		spacing.x = all_cells[rc.x][rc.y + 1].global_position.x - cell.global_position.x
	elif rc.y - 1 >= 0:
		spacing.x = cell.global_position.x - all_cells[rc.x][rc.y - 1].global_position.x
	if rc.x + 1 < total.x:
		spacing.y = all_cells[rc.x + 1][rc.y].global_position.y - cell.global_position.y
	elif rc.x - 1 >= 0:
		spacing.y = cell.global_position.y - all_cells[rc.x - 1][rc.y].global_position.y
	return spacing

## 僵尸是否在范围格子集合内(格子级菱形判定; 行=zombie.lane, 列=x 映射到列索引)
## 菱形范围必须格子级判定——用整个范围的 x 跨度会把菱形补成矩形(每行都按干员行的列数命中)
static func is_zombie_in_range_rcs(zombie: Zombie000Base, rc_set: Dictionary, spacing_x: float) -> bool:
	var all_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	if zombie.lane < 0 or zombie.lane >= all_cells.size() or all_cells[zombie.lane].is_empty():
		return false
	var row0_cell: PlantCell = all_cells[zombie.lane][0]
	var col0_cx: float = row0_cell.global_position.x + row0_cell.size.x * 0.5
	var col_idx: int = int(round((zombie.global_position.x - col0_cx) / spacing_x))
	return rc_set.has(Vector2i(zombie.lane, col_idx))

## 按方向生成攻击范围格子的行列索引(真实植物格网格), 越界跳过
## 用于格子级检测(菱形范围内才命中, 避免用整个范围 x 跨度把菱形补成矩形)
static func get_range_rcs_on_grid(direction: Operator000Base.E_AttackDirection, operator_cell: PlantCell, shape: Array[Vector2i] = ATTACK_RANGE_SHAPE) -> Array[Vector2i]:
	var rcs: Array[Vector2i] = []
	var rc: Vector2i = operator_cell.row_col
	var total: Vector2i = Global.main_game.plant_cell_manager.row_col
	for offset: Vector2i in shape:
		var target_rc: Vector2i = rc + rotate_offset(offset, direction)
		if target_rc.x < 0 or target_rc.y < 0\
			or target_rc.x >= total.x or target_rc.y >= total.y:
			continue
		rcs.append(target_rc)
	return rcs

## 按方向生成攻击范围格子中心(真实植物格网格, 与部署预览完全一致)
## 越界的格子跳过; 干员所在格是否在内取决于 shape 是否含 (0,0)
static func get_range_cells_on_grid(direction: Operator000Base.E_AttackDirection, operator_cell: PlantCell, shape: Array[Vector2i] = ATTACK_RANGE_SHAPE) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var rc: Vector2i = operator_cell.row_col
	var total: Vector2i = Global.main_game.plant_cell_manager.row_col
	var all_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	for offset: Vector2i in shape:
		var target_rc: Vector2i = rc + rotate_offset(offset, direction)
		if target_rc.x < 0 or target_rc.y < 0\
			or target_rc.x >= total.x or target_rc.y >= total.y:
			continue
		var target_cell: PlantCell = all_cells[target_rc.x][target_rc.y]
		centers.append(target_cell.global_position + target_cell.size * 0.5)
	return centers

## 按方向生成攻击范围格子中心(世界坐标), 供干员本体与部署预览共用
static func get_range_cells_by_direction(direction: Operator000Base.E_AttackDirection, base_pos: Vector2, cell_size: Vector2, shape: Array[Vector2i] = ATTACK_RANGE_SHAPE) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	for offset: Vector2i in shape:
		cells.append(base_pos + get_world_delta(offset, direction, cell_size))
	return cells

## 当前攻击范围内的目标僵尸
var curr_target_zombie: Zombie000Base

var _owner_operator: Operator000Base
var _check_timer: float = 0.0
var _is_attack := false

func _ready() -> void:
	super()
	## 干员范围攻击不使用行属性
	is_lane = false
	_owner_operator = owner as Operator000Base

func _process(delta: float) -> void:
	if not is_enabling:
		return
	_check_timer += delta
	if _check_timer < POLL_INTERVAL:
		return
	_check_timer = 0.0
	judge_have_enemy()

## 更新攻击方向(检测每帧读取干员当前方向, 此处仅保证下一帧生效)
func update_attack_direction(_new_direction: Operator000Base.E_AttackDirection):
	pass

## 判断攻击范围内是否有可攻击僵尸, 选取最近的作为目标
func judge_have_enemy():
	if not is_instance_valid(_owner_operator) or not is_instance_valid(_owner_operator.plant_cell)\
		or not is_instance_valid(Global.main_game):
		_clear_target()
		return

	var operator_pos: Vector2 = _owner_operator.global_position

	## 行方向按"僵尸所在 lane"判断(僵尸行网格与植物格网格间距不同, 像素矩形会随行数偏移而漏检, 见 docs 踩坑)
	var operator_lane: int = _owner_operator.plant_cell.row_col.x
	var lane_offsets: Array[int] = _get_lane_offsets(_owner_operator.attack_direction)
	## 格子级判定: 范围格子(行,列)集合。菱形范围必须格子级判定——
	## 用整个范围的 x 跨度(min_x/max_x)会把菱形补成矩形(每行都按干员行的列数命中)
	var rc_set: Dictionary = {}
	for target_rc: Vector2i in get_range_rcs_on_grid(
		_owner_operator.attack_direction, _owner_operator.plant_cell, _owner_operator.get_attack_range_shape()):
		rc_set[target_rc] = true
	var spacing_x: float = get_grid_spacing(_owner_operator.plant_cell).x

	var closest_zombie: Zombie000Base = null
	var closest_dist: float = INF
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		## 受击状态过滤
		if not zombie.curr_be_attack_status & can_attack_zombie_status:
			continue
		## 行过滤(按 lane, 与像素错位无关)
		if not (zombie.lane - operator_lane) in lane_offsets:
			continue
		## 格子级范围过滤: 僵尸(行,列)在菱形范围格子集合内才命中
		var zombie_pos: Vector2 = zombie.global_position
		if not is_zombie_in_range_rcs(zombie, rc_set, spacing_x):
			continue
		var dist: float = zombie_pos.distance_squared_to(operator_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_zombie = zombie

	if is_instance_valid(closest_zombie):
		curr_target_zombie = closest_zombie
		if not _is_attack:
			_is_attack = true
			signal_can_attack.emit()
	else:
		_clear_target()
	_update_operator_visual()

## 按攻击目标位置更新干员视觉(转身/正背面):
## 无目标 → 恢复默认; 有目标 → update_visual_for_target 按素材(上方行→背面) + scale(目标左右×素材)
## 范围外的敌人不影响转向
func _update_operator_visual():
	if not is_instance_valid(_owner_operator) or not is_instance_valid(_owner_operator.plant_cell):
		return
	_owner_operator.update_visual_for_target(curr_target_zombie)

## 按方向返回攻击范围覆盖的 lane 偏移(相对干员所在行), 由范围形状(旋转后)的行偏移动态计算
## 支持不同干员的不同范围形状(克洛丝 3 行 / 维什戴尔 5 行等)
func _get_lane_offsets(direction: Operator000Base.E_AttackDirection) -> Array[int]:
	var offsets: Array[int] = []
	if not is_instance_valid(_owner_operator):
		return [-1, 0, 1]
	var shape: Array[Vector2i] = _owner_operator.get_attack_range_shape()
	for offset: Vector2i in shape:
		var rotated: Vector2i = rotate_offset(offset, direction)
		if not offsets.has(rotated.x):
			offsets.append(rotated.x)
	return offsets

func _clear_target():
	curr_target_zombie = null
	if _is_attack:
		_is_attack = false
		signal_not_can_attack.emit()
