extends RefCounted
class_name ContractTerms

## 危机合约词条数据表与应用逻辑
## 词条定义: id -> {name: 词条名, desc: 说明, group: 互斥分组(同组只能选一个)}
const TERM_INFO := {
	"hp5": {"name": "铁壁", "desc": "僵尸生命值变为5倍", "group": "hp"},
	"hp10": {"name": "磐石", "desc": "僵尸生命值变为10倍", "group": "hp"},
	"speed2": {"name": "疾驰", "desc": "僵尸移动/攻击速度×2"},
	"atk2": {"name": "凶残", "desc": "僵尸攻击力×2"},
	"multy3": {"name": "潮涌", "desc": "每波出怪数量变为3倍"},
	"waves40": {"name": "持久战", "desc": "总波次延长至40波"},
	"fog": {"name": "迷雾封锁", "desc": "战场被浓雾笼罩"},
	"slowdp": {"name": "补给枯竭", "desc": "部署点数回复间隔变为3秒"},
	"lowdp": {"name": "开局受限", "desc": "初始部署点数减半"},
	"nowave": {"name": "断援", "desc": "失去小推车支援"},
	"slots4": {"name": "精简编队", "desc": "出战卡槽减至4个"},
	"slots3": {"name": "极限编队", "desc": "出战卡槽减至3个"},
	"ban_kroos": {"name": "逐出令·速射", "desc": "禁止部署克洛丝", "group": "ban"},
	"ban_wisdel": {"name": "逐出令·投掷", "desc": "禁止部署维什戴尔", "group": "ban"},
	"ban_myrtle": {"name": "逐出令·执旗", "desc": "禁止部署桃金娘", "group": "ban"},
	"ban_crow": {"name": "逐出令·收割", "desc": "禁止部署羽毛笔", "group": "ban"},
}

## 默认不选任何词条时的所有词条 id 列表(供面板展示)
static func get_all_term_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in TERM_INFO:
		ids.append(id)
	return ids

## 应用词条到关卡参数(须在游戏 init_para 之前调用, 且应传 clone 后的参数避免污染 .tres)
static func apply_terms(game_para: ResourceLevelData, selected: Array) -> void:
	for id in selected:
		match id:
			"hp5":
				game_para.zombie_hp_mult = 5.0
			"hp10":
				game_para.zombie_hp_mult = 10.0
			"speed2":
				game_para.zombie_speed_mult = 2.0
			"atk2":
				game_para.zombie_attack_mult = 2.0
			"multy3":
				game_para.zombie_multy = maxi(game_para.zombie_multy, 3)
			"waves40":
				game_para.max_wave = 40
			"fog":
				game_para.is_fog = true
			"slowdp":
				game_para.operator_regen_interval = 3.0
			"lowdp":
				game_para.operator_start_deploy_point = maxi(int(game_para.operator_start_deploy_point / 2.0), 1)
			"nowave":
				game_para.is_lawn_mover = false
			"slots4":
				game_para.max_choosed_card_num = mini(game_para.max_choosed_card_num, 4)
			"slots3":
				game_para.max_choosed_card_num = mini(game_para.max_choosed_card_num, 3)
			"ban_kroos":
				_append_ban(game_para, CharacterRegistry.PlantType.P050Kroos)
			"ban_wisdel":
				_append_ban(game_para, CharacterRegistry.PlantType.P051Wisadel)
			"ban_myrtle":
				_append_ban(game_para, CharacterRegistry.PlantType.P052Myrtle)
			"ban_crow":
				_append_ban(game_para, CharacterRegistry.PlantType.P053Crow)

## 追加被禁止出战的干员(去重)
static func _append_ban(game_para: ResourceLevelData, operator_type: CharacterRegistry.PlantType) -> void:
	if not game_para.ban_operator_types.has(operator_type):
		game_para.ban_operator_types.append(operator_type)
