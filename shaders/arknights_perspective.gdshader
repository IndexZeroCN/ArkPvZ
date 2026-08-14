shader_type canvas_item;
// 明日方舟主界面菜单 3D 效果（等价 CSS `perspective(30em) rotateY(±10deg)` + 鼠标跟随 3D 摆动）
// 用法：挂到菜单根 Control 的 material，并对其全部后代设置 use_parent_material = true
// u_center 需随菜单移动（视差）每帧更新为菜单的世界中心
// 分析：原项目菜单的 3D 效果 = 静态倾角(rotateY) + 鼠标移动时面板在 3D 空间轻微旋转跟随光标
// 此处用 mouse_x/mouse_y（归一化 -1..1）驱动 Y 轴水平摆动与 X 轴俯仰，实现同款动态 3D 效果

uniform float angle_deg = 10.0;      // Y 轴基础倾角（左菜单 +10、右菜单 -10）
uniform float tilt_deg = 0.0;        // X 轴基础倾角
uniform float mouse_x = 0.0;         // 鼠标归一化 x (-1..1)，驱动 Y 轴摆动
uniform float mouse_y = 0.0;         // 鼠标归一化 y (-1..1)，驱动 X 轴俯仰
uniform float mouse_range = 5.0;     // 鼠标摆动幅度（度）
uniform float focal = 460.0;
uniform vec2 u_center = vec2(0.0, 0.0);

void vertex() {
	float a = radians(angle_deg + mouse_x * mouse_range);
	float t = radians(tilt_deg + mouse_y * mouse_range * 0.6);
	float cos_a = cos(a);
	float sin_a = sin(a);
	float cos_t = cos(t);
	float sin_t = sin(t);
	// 顶点转世界坐标，绕菜单中心做 Y 轴旋转（水平）+ X 轴旋转（俯仰）+ 透视
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - u_center;
	float xr = p.x * cos_a;
	float zr = p.x * sin_a;
	float yr = p.y * cos_t;
	float zr2 = -p.y * sin_t;
	float z = zr + zr2;
	float s = focal / (focal - z);
	vec2 new_world = u_center + vec2(xr, yr) * s;
	vec4 new_local = inverse(MODEL_MATRIX) * vec4(new_world, 0.0, 1.0);
	VERTEX = new_local.xy;
}
