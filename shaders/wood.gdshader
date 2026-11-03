shader_type spatial;
// 程序化木紋：以「髓心」為中心的同心年輪，沿 x 軸（纖維方向）延伸。
// 若提供 GPT 生成的木紋貼圖 (use_tex = true)，則改用貼圖並保留塗裝/粗糙度效果。

uniform vec3 early_color : source_color = vec3(0.88, 0.74, 0.54);
uniform vec3 late_color : source_color = vec3(0.70, 0.50, 0.30);
uniform float ring_freq = 140.0;        // 每公尺年輪數
uniform vec3 pith_offset = vec3(0.0, -0.15, 0.02); // 髓心位置（板面下方 -> 弦切板）
uniform float roughness_amt = 0.85;     // 表面粗糙（鋸面/刨面/砂磨）
uniform float gloss = 0.0;              // 塗裝光澤 0~1
uniform float oil_darken = 0.0;         // 上油後的加深
uniform float tear_dark = 0.0;          // 撕裂/刮痕造成的不均
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform bool use_tex = false;
uniform float tex_scale = 2.0;

varying vec3 lp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = lp - pith_offset;
	float n = noise(vec2(p.x * 6.0, (p.y + p.z) * 30.0)) * 0.7
	        + noise(vec2(p.x * 25.0, p.z * 160.0)) * 0.2;
	float r = length(p.yz) * ring_freq + n * 2.5;
	float ring = pow(abs(fract(r) - 0.5) * 2.0, 3.0);
	vec3 col = mix(early_color, late_color, ring);
	// 導管/射線細斑
	float fleck = noise(vec2(p.x * 900.0, (p.z + p.y) * 120.0));
	col *= 0.93 + 0.10 * fleck;
	if (use_tex) {
		vec2 uv = vec2(lp.x, lp.z + lp.y) * tex_scale;
		col = texture(albedo_tex, uv).rgb;
	}
	col *= 1.0 - tear_dark * 0.25 * noise(vec2(p.x * 300.0, p.z * 300.0));
	col = mix(col, col * col * 1.15, oil_darken);   // 上油：顏色加深、飽和
	ALBEDO = col;
	ROUGHNESS = mix(roughness_amt, 0.18, gloss);
	SPECULAR = 0.25 + gloss * 0.35;
	CLEARCOAT = gloss;
	CLEARCOAT_ROUGHNESS = 0.3;
}
