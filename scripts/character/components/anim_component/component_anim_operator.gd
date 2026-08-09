extends AnimComponentPlayer
class_name AnimComponentOperator
## 干员动画组件: 基于AnimationPlayer的命名动画接口
## 固定动画名约定: idle / attack / skill / die
## 后续接入 spine-godot 插件播放真实骨骼动画时, 保持该接口不变, 替换内部播放实现

## 播放待机动画
func play_idle():
	play_anim(&"idle")

## 播放攻击动画
func play_attack():
	play_anim(&"attack")

## 播放技能动画
func play_skill():
	play_anim(&"skill")

## 播放死亡动画
func play_die():
	play_anim(&"die")

## 播放指定动画, 动画不存在时容错(跳过)
func play_anim(anim_name:StringName):
	if not is_instance_valid(animation_player) or not animation_player.has_animation(anim_name):
		return
	animation_player.play(anim_name)
