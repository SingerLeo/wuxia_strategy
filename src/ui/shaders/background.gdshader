shader_type canvas_item;
// 窗口背景：暗色宣纸 + 远处层叠的水墨山影 + 暗角。页面里大多数区域是透明的，所以它会在空白处露出来。

uniform vec2 res = vec2(1600.0, 900.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.0, 7.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float asp = res.x / res.y;
	vec2 p = vec2(uv.x * asp, uv.y);

	vec3 col = vec3(0.075, 0.070, 0.060);

	// 纸张的纤维
	float fiber = fbm(p * vec2(70.0, 5.0)) * 0.5 + fbm(p * vec2(5.0, 70.0)) * 0.5;
	col += (fiber - 0.5) * 0.028;
	col += (fbm(p * 2.2) - 0.5) * 0.02;

	// 远山：四层，越远越淡、越近越深
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float base = 0.60 + fi * 0.085;
		float x = p.x * (0.55 + fi * 0.32) + fi * 5.1;
		// 山脊：几个频率的 |sin| 叠加，得到起伏而带尖顶的连绵山形，比噪声平滑稳定
		float peaks = 0.55 * pow(abs(sin(x * 0.9 + fi)), 0.85)
				+ 0.30 * abs(sin(x * 2.1 + fi * 1.7))
				+ 0.15 * abs(sin(x * 4.9 + fi * 2.3));
		float ridge = base - peaks * 0.22 - (fbm(vec2(x * 3.0, fi)) - 0.5) * 0.02;
		float body = smoothstep(ridge - 0.003, ridge + 0.003, uv.y);
		vec3 mc = mix(vec3(0.115, 0.130, 0.135), vec3(0.045, 0.050, 0.050), fi / 3.0);
		col = mix(col, mc, body * (0.50 + 0.10 * fi));
		// 山脚的薄雾
		float mist = (1.0 - smoothstep(ridge, ridge + 0.10, uv.y)) * body;
		col += vec3(0.020, 0.024, 0.024) * mist * 0.7;
	}

	// 暗角
	vec2 c = uv - 0.5;
	col *= 1.0 - dot(c, c) * 0.85;

	COLOR = vec4(col, 1.0);
}
