extends Node2D
class_name OperatorDebugTarget
## 干员调试工具测试靶子: 模拟僵尸最小接口(供 速度0直接命中 / 魂灵射线 / 三技能爆炸特效 测试)
## 不依赖 main_game, 无真实僵尸动画/组件; 受击闪白, 停顿闪蓝, 死亡变灰烬消失

const MAX_HP := 2000

## 模拟僵尸字段(炮弹/射线回调访问的最小集合)
var hp := MAX_HP
var is_death := false
var is_hypno := false
var curr_be_attack_status := 1
## 模拟受击盒(位置 = 自身, 供 beam_fx.fire 的 to_pos 取 global_position)
var hurt_box_component: Node2D

var _flash := 0.0
var _stun_left := 0.0
var _dead_t := 0.0

func _ready() -> void:
	hurt_box_component = self

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
	if is_death:
		_dead_t += delta
		if _dead_t > 1.0:
			queue_free()
	queue_redraw()

## 模拟子弹攻击(参数签名对齐 Zombie000Base.be_attacked_bullet)
func be_attacked_bullet(damage: int, _mode = 0, _trigger_sfx = true, _can_die = true) -> void:
	if is_death:
		return
	_flash = 1.0
	hp -= damage
	if hp <= 0:
		hp = 0
		_die()

## 模拟爆炸攻击(樱桃炸弹: 直接大伤害)
func be_bomb(damage: int, _ash = true) -> void:
	if is_death:
		return
	_flash = 1.0
	hp -= damage
	if hp <= 0:
		hp = 0
		_die()

## 停顿(静默, 不显示黄油)
func be_butter(time: float, _show_splat = true) -> void:
	if is_death:
		return
	_stun_left = maxf(_stun_left, time)

func _die() -> void:
	is_death = true
	_dead_t = 0.0

func _draw() -> void:
	if is_death:
		## 灰烬: 变暗缩小直到消失
		var k := clampf(_dead_t / 0.5, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 30.0 * (1.0 - k * 0.5), Color(0.3, 0.3, 0.3, 1.0 - k))
		draw_circle(Vector2.ZERO, 13.0 * (1.0 - k * 0.5), Color(0.12, 0.12, 0.12, 1.0 - k))
		return
	## 僵尸头(绿脸 + 眼 + 嘴), 受击闪白 / 停顿闪蓝
	var body_c := Color(0.65, 0.8, 0.4)
	if _flash > 0.0:
		body_c = body_c.lerp(Color.WHITE, _flash)
	if _stun_left > 0.0:
		body_c = body_c.lerp(Color(0.4, 0.6, 1.0), 0.5)
	draw_circle(Vector2.ZERO, 28.0, body_c)
	draw_circle(Vector2(0, 2), 13.0, Color(0.82, 0.77, 0.62))
	draw_circle(Vector2(-5, -4), 3.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(5, -4), 3.0, Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-6, 6, 12, 3), Color(0.3, 0.2, 0.15))
	## 血条
	var bar_w := 56.0
	var hp_ratio := clampf(float(hp) / MAX_HP, 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5, -52, bar_w, 5), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-bar_w * 0.5, -52, bar_w * hp_ratio, 5), Color(0.2, 0.9, 0.3) if hp_ratio > 0.3 else Color(1.0, 0.3, 0.3))
	## 名称
	draw_string(ThemeDB.fallback_font, Vector2(-28, 62), "测试僵尸", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))
