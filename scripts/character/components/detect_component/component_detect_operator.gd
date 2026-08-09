extends DetectComponent
class_name DetectComponentOperator
## 干员攻击范围检测组件
## 检测有限攻击范围内的僵尸(范围形状按部署方向旋转), 不依赖单行射线
## 继承 DetectComponent(兼容攻击组件的类型判断与信号), 覆盖检测逻辑

## 攻击范围形状: (行偏移, 列偏移), 以干员所在格为基准
## 克洛丝(速射手满级)范围: 3行x4列, 干员在中间行最左列
const ATTACK_RANGE_SHAPE: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3),
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
]

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

## 按方向生成攻击范围格子中心(世界坐标), 供干员本体与部署预览共用
static func get_range_cells_by_direction(direction: Operator000Base.E_AttackDirection, base_pos: Vector2, cell_size: Vector2) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	for offset: Vector2i in ATTACK_RANGE_SHAPE:
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
	if _check_timer < 0.1:
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

	var cell_size: Vector2 = _owner_operator.plant_cell.size
	var half_cell: Vector2 = cell_size / 2.0
	var range_cells: Array[Vector2] = _owner_operator.get_attack_range_cells()
	var operator_pos: Vector2 = _owner_operator.global_position

	var closest_zombie: Zombie000Base = null
	var closest_dist: float = INF
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		## 受击状态过滤
		if not zombie.curr_be_attack_status & can_attack_zombie_status:
			continue
		## 僵尸检测点(根位置/行地面, 与干员根位置同基准; 受击盒偏上不与范围矩形y匹配)
		var zombie_pos: Vector2 = zombie.global_position
		## 是否落在某个范围格内
		var in_range := false
		for cell_center: Vector2 in range_cells:
			if Rect2(cell_center - half_cell, cell_size).has_point(zombie_pos):
				in_range = true
				break
		if not in_range:
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

func _clear_target():
	curr_target_zombie = null
	if _is_attack:
		_is_attack = false
		signal_not_can_attack.emit()
