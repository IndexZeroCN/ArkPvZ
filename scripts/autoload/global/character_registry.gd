extends Node
class_name CharacterRegistry


# 定义枚举
enum CharacterType {Null, Plant, Zombie}

#region 植物
## 植物信息属性
enum PlantInfoAttribute{
	PlantName,
	CoolTime,		## 植物种植冷却时间
	SunCost,		## 阳光消耗
	PlantScenes,	## 植物场景预加载
	PlantConditionResource,	## 植物种植条件资源预加载
	OperatorCardBg,	## 干员完整卡牌图(整卡一体背景, 代替"背景+图案"; 仅干员使用, 新增干员在此登记)
	OperatorDisplayName,	## 干员显示名(中文, 调试工具/界面显示; 仅干员)
	OperatorBulletScene,	## 干员攻击子弹场景(调试工具与出战使用; 仅干员)
	OperatorAttackAnims,	## 干员攻击动画候选名(数组, 素材无单 Attack 时用; 仅干员)
	OperatorAttackModes,	## 干员攻击模式配置(调试工具模拟技能用; 仅干员): {显示名: {count, mult, is_skill3}}
	OperatorSkills,	## 干员可选技能列表(多技能干员选卡技能面板数据; 仅干员): {技能id: {name, desc, icon}}
}

## 植物类型
enum PlantType {
	Null = 0,
	P001PeaShooterSingle = 1,
	P002SunFlower,
	P003CherryBomb,
	P004WallNut,
	P005PotatoMine,
	P006SnowPea,
	P007Chomper,
	P008PeaShooterDouble,

	P009PuffShroom,
	P010SunShroom,
	P011FumeShroom,
	P012GraveBuster,
	P013HypnoShroom,
	P014ScaredyShroom,
	P015IceShroom,
	P016DoomShroom,

	P017LilyPad,
	P018Squash,
	P019ThreePeater,
	P020TangleKelp,
	P021Jalapeno,
	P022Caltrop,
	P023TorchWood,
	P024TallNut,

	P025SeaShroom,
	P026Plantern,
	P027Cactus,
	P028Blover,
	P029SplitPea,
	P030StarFruit,
	P031Pumpkin,
	P032MagnetShroom,

	P033CabbagePult,
	P034FlowerPot,
	P035CornPult,
	P036CoffeeBean,
	P037Garlic,
	P038UmbrellaLeaf,
	P039MariGold,
	P040MelonPult,

	P041GatlingPea,
	P042TwinSunFlower,
	P043GloomShroom,
	P044Cattail,
	P045WinterMelon,
	P046GoldMagnet,
	P047SpikeRock,
	P048CobCannon,

	P049PeaShooterDoubleReverse,

	## 明日方舟干员（50 起）
	P050Kroos = 50,		## 克洛丝（速射手）
	P051Wisadel = 51,	## 维什戴尔（投掷手）
	P052Myrtle = 52,	## 桃金娘（先锋·执旗手）
	P053Crow = 53,		## 羽毛笔（近卫·收割者）

	## 模仿者
	P999Imitater = 999,
	## 发芽
	P1000Sprout = 1000,
	## 保龄球
	P1001WallNutBowling = 1001,
	P1002WallNutBowlingBomb,
	P1003WallNutBowlingBig,
	}


## 植物在格子中的位置
enum PlacePlantInCell{
	Norm,	## 普通位置
	Shell,	## 保护壳位置
	Down,	## 花盆（睡莲）位置
	Float,	## 漂浮位置
	Imitater,## 模仿者位置
}

#region 干员
## 干员植物类型列表（明日方舟干员以 PlantType 形式注册，复用植物种植/卡片/格子管线）
const OperatorPlantType:Array[PlantType] = [
	PlantType.P050Kroos,
	PlantType.P051Wisadel,
	PlantType.P052Myrtle,
	PlantType.P053Crow,
]

## 判断植物类型是否为干员
static func is_operator_type(plant_type:PlantType)->bool:
	return OperatorPlantType.has(plant_type)
#endregion

#endregion

#region 僵尸
## 僵尸类型
enum ZombieType {
	Null = 0,

	Z001Norm = 1,
	Z002Flag,
	Z003Cone,
	Z004PoleVaulter,
	Z005Bucket,

	Z006Paper,
	Z007ScreenDoor,
	Z008Football,
	Z009Jackson,
	Z010Dancer,

	Z011Duckytube,
	Z012Snorkle,
	Z013Zamboni,
	Z014Bobsled,
	Z015Dolphinrider,

	Z016Jackbox,
	Z017Balloon,
	Z018Digger,
	Z019Pogo,
	Z020Yeti,

	Z021Bungi,
	Z022Ladder,
	Z023Catapult,
	Z024Gargantuar,
	Z025Imp,

	Z026RedEye,	## 红眼普通僵尸(血量=普通僵尸10倍, 自创变体)

	Z1001BobsledSingle=1001,	## 单个雪橇车僵尸
	}

## 僵尸行类型
enum ZombieRowType{
	Land,
	Pool,
	Both,
}

## 僵尸信息属性
enum ZombieInfoAttribute{
	ZombieName,
	CoolTime,		## 僵尸冷却时间
	SunCost,		## 阳光消耗
	ZombieScenes,	## 植物场景预加载
	ZombieRowType,	## 僵尸行类型
}


#endregion


## 紫卡植物种植前置植物
@export var AllPrePlantPurple:Dictionary[PlantType, PlantType]= {
	PlantType.P041GatlingPea:PlantType.P008PeaShooterDouble,
	PlantType.P042TwinSunFlower:PlantType.P002SunFlower,
	PlantType.P043GloomShroom:PlantType.P011FumeShroom,
	PlantType.P044Cattail:PlantType.P017LilyPad,
	PlantType.P045WinterMelon:PlantType.P040MelonPult,
	PlantType.P046GoldMagnet:PlantType.P032MagnetShroom,
	PlantType.P047SpikeRock:PlantType.P022Caltrop,
	PlantType.P048CobCannon:PlantType.P035CornPult,
}

const PlantInfo = {
	PlantType.P001PeaShooterSingle: {
		PlantInfoAttribute.PlantName: "PeaShooterSingle",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_001_pea_shooter_single.tscn")
		},
	PlantType.P002SunFlower: {
		PlantInfoAttribute.PlantName: "SunFlower",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_002_sun_flower.tscn")
		},
	PlantType.P003CherryBomb: {
		PlantInfoAttribute.PlantName: "CherryBomb",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_003_cherry_bomb.tscn")
		},
	PlantType.P004WallNut: {
		PlantInfoAttribute.PlantName: "WallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_004_wall_nut.tscn")
		},
	PlantType.P005PotatoMine: {
		PlantInfoAttribute.PlantName: "PotatoMine",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/005_potato_mine.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_005_potato_mine.tscn")
		},
	PlantType.P006SnowPea: {
		PlantInfoAttribute.PlantName: "SnowPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_006_snow_pea.tscn")
		},
	PlantType.P007Chomper: {
		PlantInfoAttribute.PlantName: "Chomper",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_007_chomper.tscn")
		},
	PlantType.P008PeaShooterDouble: {
		PlantInfoAttribute.PlantName: "PeaShooterDouble",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_008_pea_shooter_double.tscn")
		},
		#
	PlantType.P009PuffShroom: {
		PlantInfoAttribute.PlantName: "PuffShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_009_puff.tscn")
		},
	PlantType.P010SunShroom: {
		PlantInfoAttribute.PlantName: "SunShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_010_sun_shroom.tscn")
		},
	PlantType.P011FumeShroom: {
		PlantInfoAttribute.PlantName: "FumeShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_011_fume_shroom.tscn")
		},
	PlantType.P012GraveBuster: {
		PlantInfoAttribute.PlantName: "GraveBuster",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/012_grave_buster.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_012_grave_buster.tscn")
		},
	PlantType.P013HypnoShroom: {
		PlantInfoAttribute.PlantName: "HypnoShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_013_hypno_shroom.tscn")
		},
	PlantType.P014ScaredyShroom: {
		PlantInfoAttribute.PlantName: "ScaredyShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_014_scaredy_shroom.tscn")
		},
	PlantType.P015IceShroom: {
		PlantInfoAttribute.PlantName: "IceShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_015_ice_shroom.tscn")
		},
	PlantType.P016DoomShroom: {
		PlantInfoAttribute.PlantName: "DoomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_016_doom_shroom.tscn")
		},
	PlantType.P017LilyPad: {
		PlantInfoAttribute.PlantName: "LilyPad",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/017_lily_pad.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_017_lily_pad.tscn")
		},
	PlantType.P018Squash: {
		PlantInfoAttribute.PlantName: "Squash",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_018_squash.tscn")
		},
	PlantType.P019ThreePeater: {
		PlantInfoAttribute.PlantName: "ThreePeater",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 325,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_019_three_peater.tscn")
		},
	PlantType.P020TangleKelp: {
		PlantInfoAttribute.PlantName: "TangleKelp",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_020_tanglekelp.tscn")
		},
	PlantType.P021Jalapeno: {
		PlantInfoAttribute.PlantName: "Jalapeno",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_021_jalapeno.tscn")
		},
	PlantType.P022Caltrop: {
		PlantInfoAttribute.PlantName: "Caltrop",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/022_caltrop.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_022_caltrop.tscn")
		},
	PlantType.P023TorchWood: {
		PlantInfoAttribute.PlantName: "TorchWood",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_023_torch_wood.tscn")
		},
	PlantType.P024TallNut: {
		PlantInfoAttribute.PlantName: "TallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_024_tall_nut.tscn")
		},

	PlantType.P025SeaShroom: {
		PlantInfoAttribute.PlantName: "SeaShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_025_sea_shroom.tscn")
		},
	PlantType.P026Plantern: {
		PlantInfoAttribute.PlantName: "Plantern",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_026_plantern.tscn")
		},
	PlantType.P027Cactus: {
		PlantInfoAttribute.PlantName: "Cactus",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_027_cactus.tscn")
		},
	PlantType.P028Blover: {
		PlantInfoAttribute.PlantName: "Blover",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_028_blover.tscn")
		},
	PlantType.P029SplitPea: {
		PlantInfoAttribute.PlantName: "SplitPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_029_split_pea.tscn")
		},
	PlantType.P030StarFruit: {
		PlantInfoAttribute.PlantName: "StarFruit",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_030_star_fruit.tscn")
		},
	PlantType.P031Pumpkin: {
		PlantInfoAttribute.PlantName: "Pumpkin",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/031_Pumpkin.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_031_pumpkin.tscn")
		},
	PlantType.P032MagnetShroom: {
		PlantInfoAttribute.PlantName: "MagnetShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_032_magnet_shroom.tscn")
		},

	PlantType.P033CabbagePult: {
		PlantInfoAttribute.PlantName: "CabbagePult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_033_cabbage_pult.tscn")
		},
	PlantType.P034FlowerPot: {
		PlantInfoAttribute.PlantName: "FlowerPot",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/034_flower_pot.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_034_flower_pot.tscn")
		},
	PlantType.P035CornPult: {
		PlantInfoAttribute.PlantName: "CornPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_035_corn_pult.tscn")
		},
	PlantType.P036CoffeeBean: {
		PlantInfoAttribute.PlantName: "CoffeeBean",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/036_coffee_bean.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_036_coffee_bean.tscn")
		},
	PlantType.P037Garlic: {
		PlantInfoAttribute.PlantName: "Garlic",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_037_garlic.tscn")
		},
	PlantType.P038UmbrellaLeaf: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_038_umbrella_leaf.tscn")
		},
	PlantType.P039MariGold: {
		PlantInfoAttribute.PlantName: "MariGold",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_039_mari_gold.tscn")
		},
	PlantType.P040MelonPult: {
		PlantInfoAttribute.PlantName: "MelonPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_040_melon_pult.tscn")
		},

	PlantType.P041GatlingPea: {
		PlantInfoAttribute.PlantName: "GatlingPea",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_041_gatling_pea.tscn")
		},

	PlantType.P042TwinSunFlower: {
		PlantInfoAttribute.PlantName: "TwinSunFlower",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_042_twin_sun_flower.tscn")
		},

	PlantType.P043GloomShroom: {
		PlantInfoAttribute.PlantName: "GloomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_043_gloom_shroom.tscn")
		},

	PlantType.P044Cattail: {
		PlantInfoAttribute.PlantName: "Cattail",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_044_cattail.tscn")
		},

	PlantType.P045WinterMelon: {
		PlantInfoAttribute.PlantName: "WinterMelon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_045_winter_melon.tscn")
		},

	PlantType.P046GoldMagnet: {
		PlantInfoAttribute.PlantName: "GoldMagnet",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_046_gold_magnet.tscn")
		},

	PlantType.P047SpikeRock: {
		PlantInfoAttribute.PlantName: "SpikeRock",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_047_spike_rock.tscn")
		},

	PlantType.P048CobCannon: {
		PlantInfoAttribute.PlantName: "CobCannon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 500,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/048_cob_cannon.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_048_cob_cannon.tscn")
		},

	PlantType.P049PeaShooterDoubleReverse: {
		PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_049_pea_shooter_double_reverse.tscn")
		},

	## 明日方舟干员
	## 克洛丝: SunCost 为部署费用(消耗部署点数,非阳光), CoolTime 为再部署时间
	## 数值按 wiki 满级(精英1满级+满潜): HP1060/攻击396(375+潜能21)/部署费用8(10-潜能2&6各1)/再部署66s(70-潜能3的4s)/攻击间隔1.0s(见场景与子弹)
	PlantType.P050Kroos: {
		PlantInfoAttribute.PlantName: "Kroos",
		PlantInfoAttribute.OperatorDisplayName: "克洛丝",
		PlantInfoAttribute.CoolTime: 66.0,
		PlantInfoAttribute.SunCost: 8,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/050_kroos_operator.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/operator/operator_001_kroos.tscn"),
		PlantInfoAttribute.OperatorCardBg : preload("res://assets/image/operator/kroos/kroos_card_full.png"),
		PlantInfoAttribute.OperatorBulletScene : preload("res://scenes/bullet/bullet_101_kroos_arrow.tscn"),
		PlantInfoAttribute.OperatorAttackAnims : ["Attack"],
		PlantInfoAttribute.OperatorAttackModes : {
			"普通": {"count": 1, "mult": 1.0},
			"二技能·2连射": {"count": 2, "mult": 1.0},
		},
		},
	## 维什戴尔(投掷手, ★6): 满级(精英2 90)+满潜+信赖加成
	## HP1888/攻击809(687满级+32潜能+90信赖)/部署费用23(25-潜能2&6各1)/再部署70s(基础, 满潜-4=66s, 按需求取70)/攻击间隔2.1s(见场景与子弹)
	PlantType.P051Wisadel: {
		PlantInfoAttribute.PlantName: "Wisadel",
		PlantInfoAttribute.OperatorDisplayName: "维什戴尔",
		PlantInfoAttribute.CoolTime: 70.0,
		PlantInfoAttribute.SunCost: 23,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/051_wisdel_operator.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/operator/operator_002_wisdel.tscn"),
		PlantInfoAttribute.OperatorCardBg : preload("res://assets/image/operator/wisdel/wisdel_card_full.png"),
		PlantInfoAttribute.OperatorBulletScene : preload("res://scenes/bullet/bullet_102_wisdel_shell.tscn"),
		PlantInfoAttribute.OperatorAttackAnims : ["Attack_A", "Attack_B", "Attack_C"],
		PlantInfoAttribute.OperatorAttackModes : {
			"普通": {"count": 1, "mult": 1.0},
			"二技能·3连发": {"count": 3, "mult": 1.35},
			"二技能·过载4连发": {"count": 4, "mult": 0.8},
			"三技能·爆炸": {"count": 1, "mult": (1.0 + 1.8) * 2.2, "is_skill3": true},
		},
		## 选卡技能选择面板数据(desc 每行不超过约20个汉字, 保证面板内完整显示)
		PlantInfoAttribute.OperatorSkills : {
			1: {
				"name": "定点清算",
				"desc": "攻击回复·自动触发\n下次攻击额外2次余震并晕眩1.5秒\n溅射扩大，余震伤害提升至120%",
				"icon": preload("res://assets/image/operator/wisdel/skill_icon_1.png"),
			},
			2: {
				"name": "饱和复仇",
				"desc": "自动回复·手动触发·可随时关闭\n攻击力+35%，攻击间隔缩短，攻击3名敌人\n过载：80%攻击力4连发随机索敌",
				"icon": preload("res://assets/image/operator/wisdel/skill_icon_2.png"),
			},
			3: {
				"name": "爆裂黎明",
				"desc": "自动回复·手动触发·可随时停止\n攻击力+180%，召唤2个魂灵之影\n6发弹药，攻击时攻击力提升至220%",
				"icon": preload("res://assets/image/operator/wisdel/skill_icon_3.png"),
			},
		},
		},
	## 桃金娘(先锋·执旗手, ★4): 满级(精英2 70)+满潜
	## HP1565(精英2满级)/攻击520(精英2满级)/部署费用8(基础10-潜能2&6各1)/再部署66s(70-潜能3的4s)/攻击间隔1.3s(见场景与子弹)
	PlantType.P052Myrtle: {
		PlantInfoAttribute.PlantName: "Myrtle",
		PlantInfoAttribute.OperatorDisplayName: "桃金娘",
		PlantInfoAttribute.CoolTime: 66.0,
		PlantInfoAttribute.SunCost: 8,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/052_myrtle_operator.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/operator/operator_003_myrtle.tscn"),
		PlantInfoAttribute.OperatorCardBg : preload("res://assets/image/operator/myrtle/myrtle_card_full.png"),
		PlantInfoAttribute.OperatorBulletScene : preload("res://scenes/bullet/bullet_104_myrtle_hit.tscn"),
		PlantInfoAttribute.OperatorAttackAnims : ["Attack"],
		PlantInfoAttribute.OperatorAttackModes : {
			"普通": {"count": 1, "mult": 1.0},
		},
		## 选卡技能选择面板数据(desc 每行不超过约20个汉字, 保证面板内完整显示)
		PlantInfoAttribute.OperatorSkills : {
			1: {
				"name": "支援号令·β型",
				"desc": "自动回复·手动触发\n停止攻击，8秒内回复14点部署费用",
				"icon": preload("res://assets/image/operator/myrtle/skill_icon_1.png"),
			},
			2: {
				"name": "治愈之翼",
				"desc": "自动回复·手动触发\n停止攻击，16秒内回复16点部署费用\n并每秒治疗一名友方50%攻击力",
				"icon": preload("res://assets/image/operator/myrtle/skill_icon_2.png"),
			},
		},
		},
	## 羽毛笔(近卫·收割者, ★5): 满级(精英2 80)+满潜
	## HP2250(精英2满级)/攻击650(精英2满级, 信赖+75暂不计入)/部署费用20(基础22-潜能2&6各1)/再部署60s(70-潜能3的4s-潜能5的6s)/攻击间隔1.3s/阻挡数2(见场景与子弹)
	PlantType.P053Crow: {
		PlantInfoAttribute.PlantName: "Crow",
		PlantInfoAttribute.OperatorDisplayName: "羽毛笔",
		PlantInfoAttribute.CoolTime: 60.0,
		PlantInfoAttribute.SunCost: 20,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/053_crow_operator.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/operator/operator_004_crow.tscn"),
		PlantInfoAttribute.OperatorCardBg : preload("res://assets/image/operator/crow/crow_card_full.png"),
		PlantInfoAttribute.OperatorBulletScene : preload("res://scenes/bullet/bullet_105_crow_slash.tscn"),
		PlantInfoAttribute.OperatorAttackAnims : ["Attack"],
		PlantInfoAttribute.OperatorAttackModes : {
			"普通": {"count": 1, "mult": 1.0},
			"一技能·2连击": {"count": 2, "mult": 1.65},
			"二技能·收割": {"count": 1, "mult": 1.7},
		},
		## 选卡技能选择面板数据(desc 每行不超过约20个汉字, 保证面板内完整显示)
		PlantInfoAttribute.OperatorSkills : {
			1: {
				"name": "高速切割",
				"desc": "攻击回复·自动触发\n下次攻击攻击力提升至165%\n并连续攻击两次",
				"icon": preload("res://assets/image/operator/crow/skill_icon_1.png"),
			},
			2: {
				"name": "收割",
				"desc": "自动回复·手动触发\n攻击力+70%，攻击间隔缩短\n对低于50%生命敌人伤害额外+50%",
				"icon": preload("res://assets/image/operator/crow/skill_icon_2.png"),
			},
		},
	},

	## 模仿者
	PlantType.P999Imitater:{
		PlantInfoAttribute.PlantName: "Imitater",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/999_imitater.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_999_imitater.tscn")
		},


	## 发芽
	PlantType.P1000Sprout:{
		PlantInfoAttribute.PlantName: "Sprout",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1000_sprout.tscn")
		},

	## 保龄球
	PlantType.P1001WallNutBowling: {
		PlantInfoAttribute.PlantName: "WallNutBowling",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1001_wall_nut_bowling.tscn")
		},
	PlantType.P1002WallNutBowlingBomb: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1002_wall_nut_bowling.tscn")
		},
	PlantType.P1003WallNutBowlingBig: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_1003_wall_nut_bowling.tscn")
		},
}


## 获取植物属性方法
func get_plant_info(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null:
		print("warning:获取空植物信息")
		return null
	var curr_plant_info = PlantInfo[plant_type]
	return curr_plant_info[info_attribute]

#endregion

#region 僵尸
## 僵尸信息
const ZombieInfo = {
	ZombieType.Z001Norm:{
		ZombieInfoAttribute.ZombieName: "ZombieNorm",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_001_norm.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z002Flag:{
		ZombieInfoAttribute.ZombieName: "ZombieFlag",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_002_flag.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z003Cone:{
		ZombieInfoAttribute.ZombieName: "ZombieCone",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_003_cone.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z004PoleVaulter:{
		ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_004_pole_vaulter.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z005Bucket:{
		ZombieInfoAttribute.ZombieName: "ZombieBucket",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_005_bucket.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	ZombieType.Z006Paper:{
		ZombieInfoAttribute.ZombieName: "ZombiePaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_006_paper.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z007ScreenDoor:{
		ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_007_screendoor.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z008Football:{
		ZombieInfoAttribute.ZombieName: "ZombieFootball",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes: preload("res://scenes/character/zombie/zombie_008_football.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z009Jackson:{
		ZombieInfoAttribute.ZombieName: "ZombieJackson",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_009_jackson.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z010Dancer:{
		ZombieInfoAttribute.ZombieName: "ZombieDancer",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_010_dancer.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z011Duckytube:{
		ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_011_duckytube.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z012Snorkle:{
		ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_012_snorkle.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z013Zamboni:{
		ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_013_zamboni.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z014Bobsled:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_014_bobsled.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z015Dolphinrider:{
		ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_015_dolphinrider.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z016Jackbox:{
		ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_016_jackbox.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z017Balloon:{
		ZombieInfoAttribute.ZombieName: "ZombieBallon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_017_balloon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z018Digger:{
		ZombieInfoAttribute.ZombieName: "ZombieDigger",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_018_digger.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z019Pogo:{
		ZombieInfoAttribute.ZombieName: "ZombiePogo",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_019_pogo.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z020Yeti:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_020_yeti.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z021Bungi:{
		ZombieInfoAttribute.ZombieName: "ZombieBungi",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_021_bungi.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z022Ladder:{
		ZombieInfoAttribute.ZombieName: "ZombieLadder",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_022_ladder.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z023Catapult:{
		ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_023_catapult.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z024Gargantuar:{
		ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_024_gargantuar.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z025Imp:{
		ZombieInfoAttribute.ZombieName: "ZombieImp",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_025_imp.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},

	## 红眼普通僵尸(自创变体): 血量=普通僵尸10倍(2700), 眼睛发红光
	ZombieType.Z026RedEye:{
		ZombieInfoAttribute.ZombieName: "ZombieRedEye",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_026_red_eye.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 单独雪橇僵尸
	ZombieType.Z1001BobsledSingle:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_1001_bobsled_signle.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 获取僵尸属性方法
func get_zombie_info(zombie_type:ZombieType, info_attribute:ZombieInfoAttribute):
	if zombie_type == 0:
		print("warning: 获取空僵尸信息")
		return null
	var curr_zombie_info = ZombieInfo[zombie_type]
	return curr_zombie_info[info_attribute]
