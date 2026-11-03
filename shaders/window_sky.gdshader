shader_type spatial;
render_mode unshaded, cull_disabled;
// 窗外景色：天空漸層、太陽、有月相的月亮、星星、遠方屋頂剪影（夜晚會亮燈）。
// 若有 GPT 生成的窗景圖 (use_tex)，會依時段混合白天/夜晚兩張圖。

uniform vec3 top_col : source_color = vec3(0.35, 0.55, 0.85);
uniform vec3 hor_col : source_color = vec3(0.85, 0.85, 0.80);
uniform vec2 sun_pos = vec2(0.0, 0.5);
uniform float sun_vis = 1.0;
uniform vec2 moon_pos = vec2(0.0, -2.0);
uniform float moon_vis = 0.0;
uniform float moon_phase = 0.5;   // 0 新月, 0.5 滿月
uniform float night = 0.0;        // 0 白天 ~ 1 深夜
uniform sampler2D day_tex : source_color, hint_default_black;
uniform sampler2D night_tex : source_color, hint_default_black;
uniform bool use_tex = false;
uniform float aspect = 1.7;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.y = -uv.y;
	vec3 col = mix(hor_col, top_col, smoothstep(-0.5, 0.9, uv.y));
	// 星星
	vec2 g = floor(UV * vec2(220.0, 130.0));
	float h = hash(g);
	if (h > 0.995) col += vec3(night * (h - 0.995) * 180.0);
	// 太陽
	float ds = length((uv - sun_pos) * vec2(aspect, 1.0));
	col += vec3(1.0, 0.9, 0.65) * sun_vis * (smoothstep(0.09, 0.07, ds) * 1.5 + 0.45 * exp(-ds * 5.0));
	// 月亮（以偏移的陰影圓表現月相）
	vec2 mv = (uv - moon_pos) * vec2(aspect, 1.0);
	float disc = smoothstep(0.065, 0.055, length(mv));
	float k = 1.0 - abs(moon_phase * 2.0 - 1.0);
	float off = (moon_phase < 0.5 ? -1.0 : 1.0) * 0.13 * k;
	float shadow = smoothstep(0.065, 0.055, length(mv - vec2(off, 0.0)));
	col = mix(col, vec3(0.92, 0.93, 1.0) * 1.2, disc * (1.0 - shadow) * moon_vis);
	col += vec3(0.25, 0.3, 0.4) * moon_vis * exp(-length(mv) * 6.0) * k;
	// 遠方屋頂剪影
	float cell = floor((uv.x + 1.0) * 7.0);
	float bh = -0.45 + hash(vec2(cell, 3.0)) * 0.3;
	float hill = -0.62 + 0.06 * sin(uv.x * 2.7 + 1.0);
	vec3 sil = mix(hor_col * 0.35, vec3(0.03, 0.035, 0.06), night);
	if (uv.y < bh) {
		col = sil;
		// 窗戶燈光
		vec2 wcell = floor(vec2((uv.x + 1.0) * 60.0, uv.y * 40.0));
		vec2 wf = fract(vec2((uv.x + 1.0) * 60.0, uv.y * 40.0));
		if (hash(wcell) > 0.72 && wf.x > 0.3 && wf.x < 0.7 && wf.y > 0.3 && wf.y < 0.75 && uv.y < bh - 0.04)
			col += vec3(1.0, 0.75, 0.4) * night * 0.9;
	}
	if (uv.y < hill) col = sil * 0.8;
	if (use_tex) {
		vec3 d = texture(day_tex, UV).rgb;
		vec3 n = texture(night_tex, UV).rgb;
		col = mix(d * mix(vec3(1.0), hor_col * 1.3, 0.3), n, night);
	}
	ALBEDO = col;
}
