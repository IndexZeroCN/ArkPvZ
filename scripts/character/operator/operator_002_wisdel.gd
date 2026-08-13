extends Operator000Base
class_name Operator002Wisdel
## 维什戴尔 - 狙击/投掷手 (★6 限定)
## 特性: 攻击对小范围地面敌人造成两次物理伤害(第二次为余震, 伤害=攻击力一半)
## 天赋1 好礼: 攻击时对主目标的攻击力提升至125%并附着残影; 带残影目标被余震影响时15%概率爆炸
##   (对周围所有敌人造成175%攻击力的物理伤害并晕眩1秒)
## 天赋2 死魂灵的余息: 部署动画结束后在攻击范围内召唤1个魂灵之影(初始0技力)
## 技能(选卡时选择, operator_skill_id, 见 CardBase.operator_skill_id):
##   1 定点清算(攻击回复·自动触发): 下次攻击额外造成2次余震并使所有目标晕眩1.5秒,
##     溅射范围略微扩大且余震伤害变为攻击力的120%
##   2 饱和复仇(自动回复·手动触发·可随时关闭): 攻击力+35%, 攻击间隔缩短(-0.7),
##     可同时攻击3名敌人; 过载(技能后段): 攻击改为攻击力80%的4连发随机攻击范围内目标
##   3 爆裂黎明(自动回复·手动触发): 立刻召唤2个魂灵之影(最多3个, 技能结束后保留),
##     攻击力+180%, 攻击间隔大幅增大(+2.9), 攻击时攻击力提升至220%, 溅射范围大幅扩大,
##     第一天赋发动概率提高至100%, 攻击装有6发弹药, 打完后结束(可随时停止)

## 技能枚举(与选卡技能选择面板一致)
enum E_Skill {Skill1 = 1, Skill2 = 2, Skill3 = 3}

## 三个技能图标(干员菜单技能按钮/技能选择面板使用, 从游戏 spritepack/skill_icons 提取)
const SKILL_ICONS: Dictionary = {
	E_Skill.Skill1: preload("res://assets/image/operator/wisdel/skill_icon_1.png"),
	E_Skill.Skill2: preload("res://assets/image/operator/wisdel/skill_icon_2.png"),
	E_Skill.Skill3: preload("res://assets/image/operator/wisdel/skill_icon_3.png"),
}

## 干员技能图标(干员菜单技能按钮, 按所选技能显示)
func get_skill_icon() -> Texture2D:
	return SKILL_ICONS.get(operator_skill_id, SKILL_ICONS[E_Skill.Skill1])

## 当前技能(选卡时选择, 默认一技能; 创建后由 hm_character 从卡片写入)
@export var operator_skill_id: int = 1

## 技能发动音效: 三技能有专属启动音(WisdelSkill3Start 在 _skill3_activate 播放), 其余用默认技能发动音
func get_skill_use_sfx() -> StringName:
	if operator_skill_id == E_Skill.Skill3:
		return &""
	return super()

## 攻击范围形状(投掷手精英2): 5行菱形大范围, 干员在中间行最左列(每行从干员列起连续, 无空格)
## 用户提供: XXX / XXXX / OXXXX / XXXX / XXX (O=干员, 每行左对齐从 O 列开始)
const WISADEL_RANGE_SHAPE: Array[Vector2i] = [
	Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, 2),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3),
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
]

## 魂灵之影召唤物场景
const SHADOW_SCENE := preload("res://scenes/character/operator/summon_002_wisdel_shadow.tscn")

## 基础攻击间隔(2.1s)
const BASE_ATTACK_CD := 2.1
## 基础攻击力(与炮弹场景 attack_value 一致: 满级687+潜能32+信赖90)
const BASE_ATTACK := 809

## 天赋1 好礼
const TALENT_MAIN_TARGET_MULT := 1.25
const TALENT_EXPLODE_CHANCE := 0.15
const TALENT_EXPLODE_DAMAGE_MULT := 1.75
const TALENT_EXPLODE_STUN := 1.0
## 当前残影爆炸概率(三技能期间 100%, 平时 15%)
var curr_explode_chance := TALENT_EXPLODE_CHANCE

## 溅射半径(格): 普通1.1 / 一技能略微扩大1.5 / 三技能大幅扩大2.5 (1格=76px)
const SPLASH_RADIUS_CELL_NORM := 1.1
const SPLASH_RADIUS_CELL_SKILL1 := 1.5
const SPLASH_RADIUS_CELL_SKILL3 := 2.5
const CELL_PX_PER_GRID := 76.0

## 余震倍率(投掷手特性: 第二次伤害=攻击力一半; 一技能变为120%)
const AFTERSHOCK_MULT_NORM := 0.5
const AFTERSHOCK_MULT_SKILL1 := 1.2

## 技能1 定点清算
var skill1_pending := false
const SKILL1_STUN_TIME := 1.5
## "额外造成2次余震" = 本次攻击共3次余震(伤害合并为一次3倍余震)
const SKILL1_AFTERSHOCK_TIMES := 3

## 技能2 饱和复仇
var skill2_active := false
var skill2_is_overload := false
const SKILL2_DURATION := 25.0
## 过载时机: 方舟术语"过载"= 技能持续时间后半段进入过载(25s 持续 → 12.5s 时进入)
const SKILL2_OVERLOAD_AFTER := SKILL2_DURATION * 0.5
const SKILL2_ATK_MULT := 1.35
const SKILL2_TARGET_COUNT := 3
const SKILL2_OVERLOAD_COUNT := 4
const SKILL2_OVERLOAD_MULT := 0.8
const SKILL2_ATTACK_CD := 1.4

## 技能3 爆裂黎明
var skill3_active := false
const SKILL3_AMMO := 6
## 攻击力+180% 且 攻击时攻击力提升至220%: 当次伤害倍率 = (1+1.8)*2.2
const SKILL3_ATK_MULT := (1.0 + 1.8) * 2.2
const SKILL3_ATTACK_CD := 5.0
const SKILL3_MAX_SHADOW := 3
## 三技能期间可对空(空中=8)
const ZOMBIE_STATUS_AIR := 8

## 场上魂灵之影(撤退/死亡时全部消失)
var all_shadows: Array[Summon000Base] = []

func _ready() -> void:
	super()

## 初始化正常出战角色(技能组件配置/天赋2召唤魂灵之影)
func ready_norm():
	super()
	## 按所选技能配置技能组件(SP上限/初始/回复方式/自动触发)
	_apply_skill_config()
	## 天赋2 死魂灵的余息: 部署动画结束后在攻击范围内召唤1个魂灵之影(初始0技力)
	if operator_skill_id != E_Skill.Skill3:
		_spawn_shadow_later(0.9, 0)

## 创建后由 hm_character 写入所选技能并重配技能组件(ready_norm 前 operator_skill_id 尚未赋值)
func apply_operator_skill(skill_id: int):
	operator_skill_id = skill_id
	_apply_skill_config()

## 按 operator_skill_id 配置技能组件参数
func _apply_skill_config():
	match operator_skill_id:
		E_Skill.Skill1:
			skill_component.max_sp = 2
			skill_component.initial_sp = 0
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Attack
			skill_component.sp_gain_per_attack = 1
			skill_component.is_auto_trigger = true
			skill_component.is_sustain_skill = false
		E_Skill.Skill2:
			skill_component.max_sp = 25
			skill_component.initial_sp = 15
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
			skill_component.sp_regen_per_sec = 1.0
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = true
		E_Skill.Skill3:
			skill_component.max_sp = 50
			skill_component.initial_sp = 40
			skill_component.sp_recovery_type = SkillComponent.E_SpRecoveryType.Time
			skill_component.sp_regen_per_sec = 1.0
			skill_component.is_auto_trigger = false
			skill_component.is_sustain_skill = false
	## 重置技能点与技能条(组件 _ready 时使用的是默认配置)
	skill_component.curr_sp = mini(skill_component.initial_sp, skill_component.max_sp)
	skill_component.is_skill_ready = skill_component.curr_sp >= skill_component.max_sp
	skill_component.is_skill_active = false
	skill_component.update_skill_bar()

## 攻击范围形状(投掷手精英2大范围)
func get_attack_range_shape() -> Array[Vector2i]:
	return WISADEL_RANGE_SHAPE

#region 攻击参数(每次攻击发射前由攻击组件调用)
## 攻击动画开始时回调(component_attack_operator 播放攻击动画后调用):
## 先发"瞄准"音效, 再在发射延迟后由炮弹播发射音(用户要求时序: 瞄准->发射)
func on_attack_anim_start() -> void:
	if skill3_active:
		SoundManager.play_character_SFX(&"WisdelSkill3AnimStart")
	else:
		SoundManager.play_character_SFX(&"WisdelAttackAnimStart")

func get_attack_paras() -> Dictionary:
	## 瞄准音在动画开始时播(on_attack_anim_start), 此处只返回攻击参数
	var multiplier := 1.0
	var count := 1
	var targets: Array = []
	## 技能2 饱和复仇: 多目标 / 过载连发; 炮弹从天而降
	if skill2_active:
		multiplier = SKILL2_ATK_MULT
		if skill2_is_overload:
			## 过载: 4次攻击分别随机索敌(可重复), 每次攻击力80%; 不再同时攻击3目标
			## 攻击组件对 targets 每元素发射 count 发: count=1 + targets=4个独立随机目标 → 4发各打随机目标
			multiplier = SKILL2_OVERLOAD_MULT
			targets = _get_overload_targets(SKILL2_OVERLOAD_COUNT)
		else:
			targets = get_nearest_targets_in_range(SKILL2_TARGET_COUNT)
	## 技能3 爆裂黎明: 攻击力+180% × 攻击时220%
	elif skill3_active:
		multiplier = SKILL3_ATK_MULT
	## 技能1 定点清算: 本次攻击的溅射参数(余震120%×3次/溅射扩大/眩晕)在 splash_paras 中
	var splash: Dictionary = _get_splash_paras()
	return {"count": count, "multiplier": multiplier, "targets": targets, "splash_paras": splash}

## 返回当前攻击应使用的子弹类型(子类覆盖, 如维什戴尔二技能用天降炮弹)
func get_attack_bullet_type(default_type: BulletRegistry.BulletType) -> BulletRegistry.BulletType:
	if skill2_active:
		return BulletRegistry.BulletType.Bullet103WisdelSkill2Shell
	return default_type

## 本次攻击的溅射/天赋参数(传给炮弹)
func _get_splash_paras() -> Dictionary:
	var paras := {
		"splash_radius_px": SPLASH_RADIUS_CELL_NORM * CELL_PX_PER_GRID,
		"after_shock_mult": AFTERSHOCK_MULT_NORM,
		"main_target_mult": TALENT_MAIN_TARGET_MULT,
		"talent_explode_chance": curr_explode_chance,
		"talent_explode_damage": int(round(BASE_ATTACK * TALENT_EXPLODE_DAMAGE_MULT)),
		"talent_explode_stun": TALENT_EXPLODE_STUN,
		"stun_time": 0.0,
	}
	## 技能1 定点清算: 溅射略微扩大, 余震伤害120%且共3次, 命中目标晕眩1.5秒
	if skill1_pending:
		paras["splash_radius_px"] = SPLASH_RADIUS_CELL_SKILL1 * CELL_PX_PER_GRID
		paras["after_shock_mult"] = AFTERSHOCK_MULT_SKILL1 * SKILL1_AFTERSHOCK_TIMES
		paras["stun_time"] = SKILL1_STUN_TIME
	## 技能3 爆裂黎明: 溅射范围大幅扩大(2.5格), 天赋概率100%, 命中播放樱桃炸弹爆炸特效
	if skill3_active:
		paras["splash_radius_px"] = SPLASH_RADIUS_CELL_SKILL3 * CELL_PX_PER_GRID
		paras["is_skill3"] = true
	return paras

## 获取攻击范围内最近的 n 个目标(技能2 多目标)
func get_nearest_targets_in_range(count: int) -> Array:
	var all: Array = get_targets_in_range()
	all.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	return all.slice(0, count)

## 获取攻击范围内随机 n 个目标(技能2 过载)
func get_random_targets_in_range(count: int) -> Array:
	var all: Array = get_targets_in_range()
	all.shuffle()
	return all.slice(0, count)

## 过载索敌: 每次攻击独立随机一个目标(可重复, 共 count 次), 对应 wiki "4次攻击分别随机索敌"
func _get_overload_targets(count: int) -> Array:
	var all: Array = get_targets_in_range()
	var result: Array = []
	for i in count:
		if all.is_empty():
			break
		result.append(all.pick_random())
	return result
#endregion

## 每次攻击发射完一轮后的回调(攻击回复技能点 + 技能1标记清除 + 技能3弹药消耗)
func _on_operator_shoot():
	## 技能1 定点清算: 本次攻击已发射, 清除"下次攻击"标记
	if skill1_pending:
		skill1_pending = false
	## 技能3 爆裂黎明: 每发弹药扣一格, 耗尽则技能结束(技能条橙色小格逐发熄灭)
	if skill3_active:
		if skill_component.consume_ammo():
			_end_skill3()
	super()

## 技能释放(经基类 signal_skill_use 统一触发)
func _on_skill_use():
	match operator_skill_id:
		E_Skill.Skill1:
			_skill1_activate()
			## 技能1 一次性动画(Skill_1) → 待机
			_play_skill_spine("Skill_1")
		E_Skill.Skill2:
			_skill2_activate()
			## 技能2 开启: Begin → Idle(循环, 技能持续期间循环播放)
			_play_skill_spine("Skill_2_Begin", "Skill_2_Idle")
		E_Skill.Skill3:
			_skill3_activate()
			## 技能3 开启: Begin → Idle(循环)
			_play_skill_spine("Skill_3_Begin", "Skill_3_Idle")

## 播放技能 Spine 动画: 开启动画(一次性) → 循环动画(持续期间)
## 不传循环动画时播完自动接待机(技能1/收尾用)
func _play_skill_spine(begin_anim: String, loop_anim: String = ""):
	var spine: OperatorSpineSprite = get_operator_spine()
	if not is_instance_valid(spine):
		return
	if loop_anim.is_empty():
		spine.play_spine_sequence(begin_anim, spine.get_anim_name("idle"))
	else:
		spine.play_spine_sequence(begin_anim, loop_anim)

## 播放技能结束动画: End → 待机
func _play_skill_end(end_anim: String):
	_play_skill_spine(end_anim)

#region 技能1 定点清算(攻击回复·自动触发)
func _skill1_activate():
	## 下次攻击: 额外2次余震+全体晕眩1.5s+溅射略微扩大+余震120%(参数在 get_attack_paras 中)
	skill1_pending = true

func _process(_delta: float) -> void:
	## 技能2 饱和复仇: 技能组件在前段耗尽后自动设 is_overload, 干员同步进入过载状态并播动画
	if skill2_active and not skill2_is_overload and skill_component.is_overload:
		skill2_is_overload = true
		_play_skill_spine("Skill_2_Overload_Begin", "Skill_2_Overload_Idle")
#endregion

#region 技能2 饱和复仇(自动回复·手动触发·可随时关闭)
func _skill2_activate():
	skill2_active = true
	skill2_is_overload = false
	skill_component.is_overload = false
	## 技能条前段橙色条 12.5s 耗尽到 0, 随后重新充满变 #bd3f00 进入过载(共 25s)
	skill_component.start_sustain(SKILL2_OVERLOAD_AFTER)
	skill_component.overload_duration = SKILL2_OVERLOAD_AFTER
	## 攻击间隔缩短(-0.7): 2.1 -> 1.4
	_set_attack_cd(SKILL2_ATTACK_CD)
	## 持续技能结束(提前关闭/计时结束)时恢复
	if not skill_component.signal_skill_ended.is_connected(_end_skill2):
		skill_component.signal_skill_ended.connect(_end_skill2)

func _end_skill2():
	if not skill2_active:
		return
	## 播放技能结束动画 → 待机
	_play_skill_end("Skill_2_End")
	skill2_active = false
	skill2_is_overload = false
	skill_component.is_overload = false
	skill_component.overload_duration = 0.0
	skill_component.update_skill_bar()
	_set_attack_cd(BASE_ATTACK_CD)
#endregion

#region 技能3 爆裂黎明(自动回复·手动触发)
func _skill3_activate():
	skill3_active = true
	## 三技能启动音效(用户选定 p_atk_chngun_h)
	SoundManager.play_character_SFX(&"WisdelSkill3Start")
	## 技能条分成6个橙色小格(组件管理弹药, 每发消耗一格)
	skill_component.start_ammo(SKILL3_AMMO)
	## 攻击间隔大幅增大(+2.9): 2.1 -> 5.0
	_set_attack_cd(SKILL3_ATTACK_CD)
	## 第一天赋发动概率提高至100%
	curr_explode_chance = 1.0
	## 普通攻击/溅射均可对空(检测组件+攻击组件同步)
	var detect: DetectComponentOperator = get_node_or_null("AttackComponent/DetectComponent") as DetectComponentOperator
	if is_instance_valid(detect):
		detect.can_attack_zombie_status |= ZOMBIE_STATUS_AIR
		attack_component.can_attack_zombie_status |= ZOMBIE_STATUS_AIR
	## 立刻召唤2个魂灵之影(最多3个, 技能结束后保留; 初始技力3sp优先与0sp)
	_spawn_shadow_later(0.0, 3)
	_spawn_shadow_later(0.1, 0)
	## 持续技能结束(6发打完/手动停止)时恢复
	if not skill_component.signal_skill_ended.is_connected(_end_skill3):
		skill_component.signal_skill_ended.connect(_end_skill3)

func _end_skill3():
	if not skill3_active:
		return
	## 播放技能结束动画 → 待机
	_play_skill_end("Skill_3_End")
	skill3_active = false
	_set_attack_cd(BASE_ATTACK_CD)
	curr_explode_chance = TALENT_EXPLODE_CHANCE
	var detect: DetectComponentOperator = get_node_or_null("AttackComponent/DetectComponent") as DetectComponentOperator
	if is_instance_valid(detect):
		detect.can_attack_zombie_status &= ~ZOMBIE_STATUS_AIR
		attack_component.can_attack_zombie_status &= ~ZOMBIE_STATUS_AIR
#endregion

## 技能激活期间的攻击动画(技能循环动作, 空=普通攻击): 三技能弹药由组件管理, 攻击播技能动画
func get_skill_attack_anim() -> String:
	if skill2_active:
		return "Skill_2_Loop"
	if skill3_active:
		return "Skill_3_Loop"
	return ""

## 技能攻击后的待机动画(技能持续期间的待机动作)
func get_skill_idle_anim() -> String:
	if skill2_active:
		return "Skill_2_Idle"
	if skill3_active:
		return "Skill_3_Idle"
	return ""

## 设置攻击间隔并重启攻击计时器(技能激活时立即按新间隔重排攻击节奏)
## 攻击组件为 one-shot 计时器 + 周期守卫: 周期进行中触发会快速重试, 周期结束后按新间隔自然衔接
func _set_attack_cd(cd: float):
	if not is_instance_valid(attack_component):
		return
	attack_component.attack_cd = cd
	if is_instance_valid(attack_component.bullet_attack_cd_timer):
		attack_component.bullet_attack_cd_timer.start(cd)

#region 魂灵之影(天赋2/技能3召唤)
## 延迟召唤魂灵之影(部署动画结束后/技能释放时)
func _spawn_shadow_later(delay: float, initial_sp: int):
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self) or is_death:
		return
	_spawn_shadow(initial_sp)

## 在攻击范围内召唤1个魂灵之影(最多 SKILL3_MAX_SHADOW 个); 无空格则跳过
func _spawn_shadow(initial_sp: int) -> Summon000Base:
	if all_shadows.size() >= SKILL3_MAX_SHADOW:
		return null
	var cell: PlantCell = _find_shadow_cell()
	if not is_instance_valid(cell):
		return null
	var shadow: Summon000Base = SHADOW_SCENE.instantiate()
	var para: Dictionary = {
		"owner_operator": self,
		"plant_cell": cell,
		"is_can_retreat": true,
		"is_can_manual_skill": false,
	}
	shadow.init_summon(para)
	## 登记到植物格(可被僵尸攻击)并注册死亡回调
	cell.plant_container_node[CharacterRegistry.PlacePlantInCell.Norm].add_child(shadow)
	cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm] = shadow
	shadow.signal_character_death.connect(_on_shadow_death.bind(shadow))
	all_shadows.append(shadow)
	if initial_sp > 0:
		shadow.skill_component.add_sp(initial_sp)
	return shadow

## 魂灵之影死亡
func _on_shadow_death(shadow: Summon000Base):
	all_shadows.erase(shadow)

## 在攻击范围内找可部署魂灵之影的空格(方舟规则简化: 距离自身最近 > 下方行 > 左侧列)
func _find_shadow_cell() -> PlantCell:
	if not is_instance_valid(plant_cell) or not is_instance_valid(Global.main_game):
		return null
	var total: Vector2i = Global.main_game.plant_cell_manager.row_col
	var all_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	var rc: Vector2i = plant_cell.row_col
	var best_cell: PlantCell = null
	var best_score := INF
	for offset: Vector2i in get_attack_range_shape():
		var target_rc: Vector2i = rc + DetectComponentOperator.rotate_offset(offset, attack_direction)
		if target_rc.x < 0 or target_rc.y < 0 or target_rc.x >= total.x or target_rc.y >= total.y:
			continue
		var cell: PlantCell = all_cells[target_rc.x][target_rc.y]
		if is_instance_valid(cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm]):
			continue
		var score: float = cell.global_position.distance_to(global_position) + target_rc.x * 10.0 - target_rc.y * 5.0
		if score < best_score:
			best_score = score
			best_cell = cell
	return best_cell

## 撤退/死亡时所有魂灵之影消失
func _remove_all_shadows():
	if not all_shadows.is_empty():
		## 魂灵撤退音效(用户选定)
		SoundManager.play_character_SFX(&"ShadowRetreat")
	for shadow in all_shadows:
		if not is_instance_valid(shadow):
			continue
		var cell: Node = shadow.plant_cell
		if is_instance_valid(cell) and cell.has_method("one_plant_free"):
			cell.call("one_plant_free", shadow)
		shadow.queue_free()
	all_shadows.clear()

func retreat():
	## 撤退音效(非死亡, 用户选定)
	SoundManager.play_character_SFX(&"WisdelRetreat")
	_remove_all_shadows()
	super()

func character_death():
	_remove_all_shadows()
	super()
#endregion
