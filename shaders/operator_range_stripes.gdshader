shader_type canvas_item;
// 干员攻击范围预览条纹: 橙色与透明相间的 45° 斜纹(警示带样式, 密集多条纹)
// 条纹在世界坐标(画布坐标)空间计算, 随窗口缩放同步放大缩小——
// 任何分辨率(720p/1080p)下条纹与草坪格子的相对宽度保持一致
// 注意: fragment 里的内置 VERTEX 是"屏幕/视口像素坐标", 在 canvas_items 拉伸下
// 会随窗口缩放(窗口放大后条纹相对草坪变细); 因此这里在 vertex 阶段把顶点本地坐标
// 经 MODEL_MATRIX 换算成世界坐标(编辑器坐标, 与 Polygon2D 顶点/草坪网格同一坐标系),
// 再用 varying 传入 fragment, 与预览节点变换、窗口分辨率解耦。
// 数值: spacing 为条纹周期, count 为周期内条纹数(单条带 = spacing/count),
//       width 为条纹宽(=单条带的一半, 橙/透明各半), speed 为移动速度(单位/秒)

uniform float speed      : hint_range(0.0, 1000.0, 1.0) = 30.0;   // 条纹移动速度(px/s, 缓慢)
uniform float width      : hint_range(1.0, 300.0, 0.5)  = 16.5;   // 单条条纹宽度(px), 与间隔等距
uniform float angle_deg  : hint_range(-90.0, 90.0)     = 45.0;   // 与 X 轴夹角(45° 斜纹)
uniform int   count      : hint_range(1, 20)           = 5;      // 一个周期内同时出现的条纹数
uniform float spacing    : hint_range(1.0, 1200.0, 1.0) = 165.0;  // 条纹周期(px) = count × 2 × width(等距)
uniform vec4  stripe_color : source_color = vec4(1.0, 0.62, 0.1, 0.9); // 橙色(半透明发光感)
uniform vec4  base_color   : source_color = vec4(1.0, 0.72, 0.15, 0.10); // 范围底色(淡橙): 让透明条纹段不露出草坪网格线, 消除缝隙感

// 顶点本地坐标 → 世界坐标(编辑器坐标, 与 Polygon2D 顶点/草坪网格同一坐标系)
varying vec2 world_pos;

void vertex() {
	// 预览节点挂在主场景根且变换为 identity, 但用 MODEL_MATRIX 换算更稳健,
	// 不依赖节点是否 identity; 世界坐标才是与草坪格子一致、且不随窗口拉伸变化的坐标系。
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

/* 将世界坐标投影到"条纹方向"的 1D 坐标轴 */
float world_to_stripe(vec2 pos) {
	float ang = radians(angle_deg);
	vec2 dir = vec2(cos(ang), sin(ang));
	return dot(pos, dir);
}

void fragment() {
	vec2 wp = world_pos; // 世界坐标(经 varying 传入), 与分辨率/窗口缩放解耦

	/* 条纹 1D 坐标 + 随时间推进的相位 */
	float stripe_coord = world_to_stripe(wp);
	float phase = TIME * speed;

	/* 多条条纹遮罩累加(边缘 0.25 单位软边防锯齿) */
	/* 注意: 不要写成 smoothstep(width, width - 0.25, p)——edge0 > edge1 属 GLSL 未定义行为,
	 * 部分驱动下结果不定; 用 1.0 - smoothstep(width - 0.25, width, p) 等价且行为确定 */
	float mask = 0.0;
	for (int i = 0; i < count; i++) {
		float offset = float(i) * spacing / float(count);
		float p = mod(stripe_coord + phase + offset, spacing);
		mask += smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(width - 0.25, width, p));
	}
	mask = clamp(mask, 0.0, 1.0);

	/* 橙色条纹 + 极淡底色(透明段盖住草坪线, 无缝隙感) */
	vec3 final_rgb = mix(base_color.rgb, stripe_color.rgb, mask);
	float final_a = base_color.a + (stripe_color.a - base_color.a) * mask;
	COLOR = vec4(final_rgb, final_a);
}
