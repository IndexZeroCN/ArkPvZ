extends ComponentNormBase
class_name SkillComponent
## 干员技能组件
## 管理技能点(SP)与技能条UI, 支持 攻击回复/时间回复, 自动触发/手动触发
## 技能条显示在干员头顶(HP条上方), 常显

## 技能点回复方式
enum E_SpRecoveryType{
	Attack,		## 攻击回复: 每次攻击获得技能点
	Time,		## 时间回复: 随时间自动回复
	None,		## 无回复(手动/其他方式回复)
}

@onready var progress_bar_skill: ProgressBar = %ProgressBarSkill
@onready var label_skill: Label = %LabelSkill

## 技能需要技能点(技能条上限)
@export var max_sp:int = 5
## 每次攻击获得技能点(攻击回复)
@export var sp_gain_per_attack:int = 1
## 每秒回复技能点(时间回复)
@export var sp_regen_per_sec:float = 1.0
## 技能点回复方式
@export var sp_recovery_type:E_SpRecoveryType = E_SpRecoveryType.Attack
## 技能就绪后是否自动触发
@export var is_auto_trigger:bool = true

## 当前技能点
var curr_sp:int = 0
## 技能是否就绪
var is_skill_ready:bool = false

## 技能点变化信号
signal signal_sp_change(curr_sp:int, max_sp:int)
## 技能就绪信号
signal signal_skill_ready
## 技能被使用(触发)信号
signal signal_skill_use

func _ready() -> void:
	super()
	curr_sp = 0
	update_skill_bar()

## 增加技能点(攻击回复或外部调用)
func add_sp(value:int):
	if is_skill_ready:
		return
	curr_sp = mini(curr_sp + value, max_sp)
	update_skill_bar()
	if curr_sp >= max_sp:
		is_skill_ready = true
		signal_skill_ready.emit()
		## 自动触发技能
		if is_auto_trigger:
			use_skill()

func _process(delta: float) -> void:
	## 时间回复
	if sp_recovery_type == E_SpRecoveryType.Time and not is_skill_ready and sp_regen_per_sec > 0:
		curr_sp += delta * sp_regen_per_sec
		if curr_sp >= max_sp:
			curr_sp = max_sp
			update_skill_bar()
			is_skill_ready = true
			signal_skill_ready.emit()
			## 自动触发技能
			if is_auto_trigger:
				use_skill()

## 使用技能, 技能就绪时触发并返回true
func use_skill()->bool:
	if not is_skill_ready:
		return false
	is_skill_ready = false
	curr_sp = 0
	update_skill_bar()
	signal_skill_use.emit()
	return true

## 更新技能条UI
func update_skill_bar():
	if not is_instance_valid(progress_bar_skill):
		return
	progress_bar_skill.value = float(curr_sp) / max_sp
	label_skill.text = str(curr_sp) + "/" + str(max_sp)
	signal_sp_change.emit(curr_sp, max_sp)
