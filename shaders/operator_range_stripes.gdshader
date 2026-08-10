shader_type canvas_item;
// 干员攻击范围预览条纹: 橙色与透明相间的 45° 斜纹(警示带样式, 密集多条纹)
// 算法结构参考 spatial 版: 世界坐标投影到条纹方向 + mod + count 条累加 + smoothstep 软边
// 注意: 顶点坐标即世界坐标(预览节点挂在 CanvasLayer 下, 变换为 identity), 不依赖 UV
// 数值参考: width/spacing ≈ 0.15(条纹宽占周期的 15%), count=5(一个周期内同时出现 5 条), speed 慢速移动

uniform float speed      : hint_range(0.0, 1000.0, 1.0) = 30.0;   // 条纹移动速度(px/s, 缓慢)
uniform float width      : hint_range(1.0, 300.0, 0.5)  = 16.5;   // 单条条纹宽度(px), 与间隔等距
uniform float angle_deg  : hint_range(-90.0, 90.0)     = 45.0;   // 与 X 轴夹角(45° 斜纹)
uniform int   count      : hint_range(1, 20)           = 5;      // 一个周期内同时出现的条纹数
uniform float spacing    : hint_range(1.0, 1200.0, 1.0) = 165.0;  // 条纹周期(px) = count × 2 × width(等距)
uniform vec4  stripe_color : source_color = vec4(1.0, 0.62, 0.1, 0.9); // 橙色(半透明发光感)
uniform vec4  base_color   : source_color = vec4(1.0, 0.72, 0.15, 0.10); // 范围底色(淡橙): 让透明条纹段不露出草坪网格线, 消除缝隙感

/* 将世界坐标投影到"条纹方向"的 1D 坐标轴 */
float world_to_stripe(vec2 world_pos) {
	float ang = radians(angle_deg);
	vec2 dir = vec2(cos(ang), sin(ang));
	return dot(world_pos, dir);
}

void fragment() {
	vec2 world_pos = VERTEX; // 局部坐标 = 世界坐标(transform identity)

	/* 条纹 1D 坐标 + 随时间推进的相位 */
	float stripe_coord = world_to_stripe(world_pos);
	float phase = TIME * speed;

	/* 多条条纹遮罩累加(边缘锐化 0.25px 防锯齿, 减少缝隙感) */
	float mask = 0.0;
	for (int i = 0; i < count; i++) {
		float offset = float(i) * spacing / float(count);
		float p = mod(stripe_coord + phase + offset, spacing);
		mask += smoothstep(0.0, 0.25, p) * smoothstep(width, width - 0.25, p);
	}
	mask = clamp(mask, 0.0, 1.0);

	/* 橙色条纹 + 极淡底色(透明段盖住草坪线, 无缝隙感) */
	vec3 final_rgb = mix(base_color.rgb, stripe_color.rgb, mask);
	float final_a = base_color.a + (stripe_color.a - base_color.a) * mask;
	COLOR = vec4(final_rgb, final_a);
}
