extends Zombie001Norm
class_name Zombie026RedEye
## 红眼普通僵尸: 外观与普通僵尸完全相同, 只是眼睛发出红光(明显可辨);
## 血量 = 普通僵尸 10 倍(2700, 场景 HpComponent.max_hp 配置)
## 掉手/掉头血量阶段由 HpStageChangeComponent 按 max_hp 比例自动适配, 无需额外配置
##
## 红眼实现: 在头部 Sprite(Anim_head1/Anim_head2) 下挂红色径向渐变光晕 Sprite(加色混合),
## 位置近似眼睛中心(头部贴图坐标, 粗略对齐即可, 不追求像素级精确)
## 作为头部子节点, 光晕随头部动画/缩放/隐藏自动同步

## 眼睛中心在头部贴图中的近似坐标(普通僵尸头 53x48, 眼窝中心约在此处)
const EYE_GLOW_POS := Vector2(39, 25)
## 光晕贴图尺寸(px, 会被头部 0.8 缩放)
const EYE_GLOW_SIZE := 34

func _ready() -> void:
	super()
	for head_path in ["Body/BodyCorrect/Anim_head/Anim_head1", "Body/BodyCorrect/Anim_head2/Anim_head2"]:
		var head: Node2D = get_node_or_null(head_path) as Node2D
		if is_instance_valid(head):
			_add_eye_glow(head)

## 给头部挂红色发光眼(加色混合径向渐变)
func _add_eye_glow(head: Node2D) -> void:
	var glow := Sprite2D.new()
	glow.name = "RedEyeGlow"
	glow.position = EYE_GLOW_POS
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.15, 0.1, 0.95))
	grad.set_color(1, Color(1.0, 0.05, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = EYE_GLOW_SIZE
	tex.height = EYE_GLOW_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	head.add_child(glow)
