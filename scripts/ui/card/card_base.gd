extends Control
class_name CardBase

@onready var card_bg: TextureRect = $CardBg
@onready var cost: Label = $CardBg/Cost
@onready var _cool_mask: ProgressBar = $ProgressBar

## 是否可以点击(原在 card.gd 声明, 移到基类供危机合约禁用状态共用)
var is_can_click := true

## 危机合约「逐出令」词条: 干员卡牌是否被禁用(选卡界面灰显不可选, 不从列表移除)
var is_banned := false

## 设置卡牌禁用状态(危机合约词条用): 置灰 + 不可点击; 与冷却遮罩共用, 不修改冷却时间
func set_card_banned(banned: bool) -> void:
	is_banned = banned
	if banned:
		_cool_mask.max_value = 1.0
		_cool_mask.value = 1.0
		_cool_mask.visible = true
		is_can_click = false
	else:
		_cool_mask.visible = false
		is_can_click = true

enum E_CardBg{
	CB01Norm,	## 普通卡片背景
	CB02Purple,	## 紫卡背景
	CB03Gray,	## 灰卡背景
}

## 卡片背景对应资源
var CradBgMap:Dictionary[E_CardBg, Resource] = {
	E_CardBg.CB01Norm:load("res://assets/image/ui/ui_card/SeedPacket_Larger.png"),
	E_CardBg.CB02Purple:load("res://resources/card_bg/02Purple.tres"),
	E_CardBg.CB03Gray:load("res://resources/card_bg/03Gray.tres")
}

## 卡片索引位置,用于在备选卡槽时确定位置
@export var card_id :int = -1
## 植物卡片类型，植物卡片类型为CharacterRegistry.PlantType.Null时为僵尸卡片
@export var card_plant_type: CharacterRegistry.PlantType
## 僵尸卡片类型
@export var card_zombie_type: CharacterRegistry.ZombieType
## 是否为紫卡
var is_purple_card := false
## 卡片背景,紫卡会自动更换背景
@export var curr_card_gb :E_CardBg = E_CardBg.CB01Norm
## 该植物种植条件,紫卡使用内部方法判断是否可以种植
var plant_condition:ResourcePlantCondition
## 卡片冷却时间
@export var cool_time: float = 7.5:
	set(value):
		cool_time = value
		if _cool_mask:
			_cool_mask.max_value = value

## 卡片阳光消耗
@export var sun_cost: int = 100:
	set(value):
		sun_cost = value
		if cost:
			cost.text = str(int(value))

## 是否为模仿者
@export var is_imitater := false

## 是否为干员卡片(消耗部署点数而非阳光, 由选卡/出战卡槽处理)
@export var is_operator_card := false

## 干员所选技能(选卡时通过技能选择面板选择, 出战时写入干员; 默认一技能)
@export var operator_skill_id: int = 1

## 是否为多技能干员(选卡时点击卡片弹出技能选择面板, 如维什戴尔)
@export var is_multi_skill_operator := false
## 选卡时是否已选择技能(多技能干员未选择技能时点击卡片先弹面板)
var is_skill_choosed := false

func _ready() -> void:
	## 如果是植物,根据是否为紫卡更新背景
	if card_plant_type != 0:
		plant_condition = Global.character_registry.get_plant_info(card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		is_purple_card = plant_condition.is_purple_card
		if is_purple_card:
			curr_card_gb = E_CardBg.CB02Purple
		if is_imitater:
			curr_card_gb = E_CardBg.CB03Gray

		## 干员完整卡牌图优先(整卡一体代替"背景+图案", 如克洛斯桌面卡牌)
		var full_card: Texture2D = get_operator_full_card_texture()
		if full_card != null:
			card_bg.texture = full_card
		else:
			card_bg.texture = CradBgMap[curr_card_gb]

	## 干员卡片部署费用: 与植物卡牌样式一致(黑/字号10/右对齐), 仅向左偏移 2px
	if is_operator_card:
		cost.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		cost.add_theme_font_size_override("font_size", 10)
		cost.anchor_left = 0.05
		cost.anchor_right = 0.65
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost.offset_left -= 2.0

## 干员完整卡牌图(整卡一体, 代替原"背景+图案"组合)
## 数据源: CharacterRegistry.PlantInfo 的 OperatorCardBg 字段(新增干员在此登记, 无需改代码)
func get_operator_full_card_texture() -> Texture2D:
	if CharacterRegistry.is_operator_type(card_plant_type):
		return Global.character_registry.get_plant_info(card_plant_type, CharacterRegistry.PlantInfoAttribute.OperatorCardBg)
	return null

## 卡片初始化参数
enum E_CInitAttr{
	CardId,	## 卡片id,目前没有用到,植物卡片和僵尸卡片单独使用
	SunCost,
	CoolTime,
}

func init_card(card_init_para:Dictionary):
	card_id = card_init_para[E_CInitAttr.CardId]
	cool_time = card_init_para[E_CInitAttr.CoolTime]
	sun_cost = card_init_para[E_CInitAttr.SunCost]

