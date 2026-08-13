extends BombEffectBase
class_name BombEffectCherryBomb

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2d_2: GPUParticles2D = $GPUParticles2D2
## 爆炸文字("破"), 部分特效场景(如维什戴尔三技能)无此节点, 用 get_node_or_null 兼容
@onready var explosive_font: Sprite2D = get_node_or_null("ExplosiveFont")

## 樱桃炸弹爆炸特效
func activate_bomb_effect():
	super()
	gpu_particles_2d.emitting = true
	gpu_particles_2d_2.emitting = true

	if is_instance_valid(explosive_font):
		await get_tree().create_timer(gpu_particles_2d.lifetime/2).timeout
		explosive_font.queue_free()
	await gpu_particles_2d.finished
	queue_free()
