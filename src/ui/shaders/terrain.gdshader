shader_type canvas_item;
// 山门地面与河流：整张地图一次画完。
// mask 的 R 通道是"水的浓度"（程序按地图里的河流格子生成并模糊过），
// 用它做出圆润的河岸、岸边的泥地、浅深变化的水色、流动的水纹和岸边白沫。

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 map_cells = vec2(12.0, 8.0);
uniform float time = 0.0;

uniform vec3 grass_a : source_color = vec3(0.16, 0.26, 0.12);
uniform vec3 grass_b : source_color = vec3(0.26, 0.37, 0.16);
uniform vec3 dry     : source_color = vec3(0.40, 0.38, 0.20);
uniform vec3 mud     : source_color = vec3(0.29, 0.23, 0.15);
uniform vec3 shallow : source_color = vec3(0.22, 0.48, 0.58);
uniform vec3 deep    : source_color = vec3(0.06, 0.19, 0.31);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 w = UV * map_cells;   // 以"格"为单位的坐标

	// --- 地面：深浅不一的草地，夹着干枯发黄的区域 ---
	float n1 = fbm(w * 1.25);
	float n2 = fbm(w * 4.5 + 11.0);
	vec3 col = mix(grass_a, grass_b, n1);
	col = mix(col, dry, smoothstep(0.55, 0.78, fbm(w * 0.8 + 5.0)) * 0.6);
	col *= 0.90 + 0.20 * n2;
	col *= 0.93 + 0.14 * fbm(w * vec2(38.0, 13.0));   // 细碎的草丝

	// --- 河岸：靠近水的地方变成湿润的泥地 ---
	float m = texture(mask, UV).r;
	float wet = smoothstep(0.10, 0.44, m);
	col = mix(col, mud * (0.85 + 0.3 * n2), wet * 0.9);

	// --- 河水 ---
	float water = smoothstep(0.47, 0.53, m);
	float depth = smoothstep(0.55, 0.95, m);
	vec3 wcol = mix(shallow, deep, depth);
	vec2 flow = vec2(time * 0.30, time * 0.10);
	float r1 = fbm(w * vec2(4.0, 7.0) + flow);
	float r2 = fbm(w * vec2(9.0, 13.0) - flow * 1.7 + 3.0);
	wcol += (r1 - 0.5) * 0.18;
	wcol += smoothstep(0.64, 0.80, r2) * 0.20;                    // 水面的亮纹

	// 岸边白沫
	float band = smoothstep(0.48, 0.53, m) * (1.0 - smoothstep(0.54, 0.66, m));
	float foam = band * smoothstep(0.30, 0.80, fbm(w * 7.0 + vec2(time * 0.35, 0.0)));
	wcol = mix(wcol, vec3(0.80, 0.90, 0.94), foam * 0.55);

	col = mix(col, wcol, water);

	// 整体的轻微暗角，让画面向中间聚拢
	vec2 c = UV - 0.5;
	col *= 1.0 - dot(c, c) * 0.35;

	COLOR = vec4(col, 1.0);
}
