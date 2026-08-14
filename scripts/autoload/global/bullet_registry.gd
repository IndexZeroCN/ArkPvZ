extends Node
class_name BulletRegistry


enum BulletType{
	Null = 0,

	Bullet001Pea = 1,			## 豌豆
	Bullet002PeaSnow,		## 寒冰豌豆
	Bullet003Puff,			## 小喷孢子
	Bullet004Fume,			## 大喷孢子
	Bullet005PuffLongTime,	## 胆小菇孢子（和小喷孢子一样，不过修改存在持续距离）
	Bullet006PeaFire,		## 火焰豌豆
	Bullet007Cactus,		## 仙人掌尖刺
	Bullet008Star,			## 星星子弹

	Bullet009Cabbage,		## 卷心菜
	Bullet010Corn,			## 玉米
	Bullet011Butter,		## 黄油
	Bullet012Melon,			## 西瓜

	Bullet013Basketball,	## 篮球

	Bullet014CattailBullet,	## 香蒲子弹
	Bullet015WinterMelon,	## 冰瓜子弹

	Bullet016CobCannon,		## 玉米加农炮子弹


	Bullet1001Bowling = 1001,		## 保龄球
	Bullet1002BowlingBomb,	## 爆炸保龄球
	Bullet1003BowlingBig,	## 大保龄球

	Bullet101KroosArrow = 101,	## 克洛丝箭矢（占位，待替换贴图）
	Bullet102WisdelShell = 102,	## 维什戴尔炮弹（投掷手，命中溅射+余震）
	Bullet103WisdelSkill2Shell = 103,	## 维什戴尔二技能炮弹（从天而降）
	Bullet104MyrtleHit = 104,	## 桃金娘近战挥击（无弹体贴图）
	Bullet105CrowSlash = 105,	## 羽毛笔近战斩击（无弹体贴图，命中低血敌人增伤并上报击杀）
}


## 伤害种类
## 普通，穿透，真实
enum AttackMode {
	Norm, 			## 正常 按顺序对二类防具、一类防具、本体造成伤害
	Penetration, 	## 穿透 对二类防具造成伤害同时对一类防具造成伤害
	Real,			## 真实 不对二类防具造成伤害，直接对一类防具造成伤害
	BowlingFront,		## 保龄球正面
	BowlingSide,		## 保龄球侧面
	Hammer,			## 锤子

	}

## 子弹场景路径表（懒加载，避免启动时预加载全部子弹场景）
const BulletTypeMap = {
	BulletType.Bullet001Pea : "res://scenes/bullet/bullet_001_pea.tscn",
	BulletType.Bullet002PeaSnow : "res://scenes/bullet/bullet_002_pea_snow.tscn",
	BulletType.Bullet003Puff : "res://scenes/bullet/bullet_003_puff.tscn",
	BulletType.Bullet004Fume : "res://scenes/bullet/bullet_004_fume.tscn",
	BulletType.Bullet005PuffLongTime : "res://scenes/bullet/bullet_005_puff_long_time.tscn",
	BulletType.Bullet006PeaFire : "res://scenes/bullet/bullet_006_pea_fire.tscn",
	BulletType.Bullet007Cactus : "res://scenes/bullet/bullet_007_cactus.tscn",
	BulletType.Bullet008Star : "res://scenes/bullet/bullet_008_star.tscn",

	BulletType.Bullet009Cabbage :"res://scenes/bullet/bullet_009_cabbage.tscn",
	BulletType.Bullet010Corn :"res://scenes/bullet/bullet_010_corn.tscn",
	BulletType.Bullet011Butter :"res://scenes/bullet/bullet_011_butter.tscn",
	BulletType.Bullet012Melon :"res://scenes/bullet/bullet_012_melon.tscn",

	BulletType.Bullet013Basketball :"res://scenes/bullet/bullet_013_basketball.tscn",

	BulletType.Bullet014CattailBullet :"res://scenes/bullet/bullet_014_cattail_bullet.tscn",
	BulletType.Bullet015WinterMelon :"res://scenes/bullet/bullet_015_winter_melon.tscn",

	BulletType.Bullet016CobCannon :"res://scenes/bullet/bullet_016_cob_cannon.tscn",

	BulletType.Bullet101KroosArrow : "res://scenes/bullet/bullet_101_kroos_arrow.tscn",
	BulletType.Bullet102WisdelShell : "res://scenes/bullet/bullet_102_wisdel_shell.tscn",
	BulletType.Bullet103WisdelSkill2Shell : "res://scenes/bullet/bullet_103_wisdel_skill2_shell.tscn",
	BulletType.Bullet104MyrtleHit : "res://scenes/bullet/bullet_104_myrtle_hit.tscn",
	BulletType.Bullet105CrowSlash : "res://scenes/bullet/bullet_105_crow_slash.tscn",
}

## 子弹场景懒加载缓存
var _bullet_scene_cache: Dictionary = {}

## 获取子弹场景方法
func get_bullet_scenes(bullet_type:BulletType) -> PackedScene:
	if not _bullet_scene_cache.has(bullet_type):
		var scene_path: String = BulletTypeMap.get(bullet_type)
		_bullet_scene_cache[bullet_type] = load(scene_path)
	return _bullet_scene_cache[bullet_type]
