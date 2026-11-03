shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// مباني المدينة: كل مبنى مجسّم صندوقي، والنوافذ والأبواب والأسطح تُرسم هنا بإحداثيات العالم.
// لون المثيل = لون الجدار، وقيمته الشفافة (a) تحدد النمط: <0.3 بيت، <0.8 عمارة، غير ذلك برج زجاجي.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 720.0;
varying vec3 wpos;
varying vec3 wn;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wall = COLOR.rgb;
	float style = COLOR.a;
	float is_wall = step(abs(wn.y), 0.5);
	float u = abs(wn.x) > 0.5 ? wpos.z : wpos.x;
	float cw = style < 0.3 ? 2.6 : (style < 0.8 ? 2.1 : 1.6);
	float ch = style < 0.3 ? 2.7 : (style < 0.8 ? 3.1 : 2.4);
	vec2 g = vec2(u / cw, (wpos.y - 1.0) / ch);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float ww = style < 0.8 ? 0.58 : 0.86;
	float win = step((1.0 - ww) * 0.5, f.x) * step(f.x, 1.0 - (1.0 - ww) * 0.5) * step(0.22, f.y) * step(f.y, 0.8);
	float on = step(0.62, hash(id + floor(wpos.xz * 0.37)));
	vec3 glass_dark = vec3(0.09, 0.15, 0.22);
	vec3 glass_lit = vec3(0.55, 0.74, 0.88);
	vec3 glass = mix(glass_dark, glass_lit, 0.25 + 0.5 * hash(id * 1.7) + on * 0.25);
	float curtain = step(0.8, style);
	vec3 c = wall * (0.9 + 0.12 * hash(id));
	// الأبراج الزجاجية: واجهة زجاجية كاملة بفواصل معدنية رفيعة
	c = mix(c, glass, win * is_wall * mix(0.85, 1.0, curtain));
	// أشرطة الطوابق
	float band = step(0.93, f.y) * is_wall;
	c *= 1.0 - 0.18 * band;
	// الجزء السفلي أغمق قليلاً
	c *= mix(0.78, 1.0, smoothstep(0.5, 3.0, wpos.y));
	// الأسطح: خرسانة رمادية داكنة مع بقع
	float roof = step(0.5, wn.y);
	vec3 roof_c = vec3(0.34, 0.34, 0.36) * (0.9 + 0.2 * hash(floor(wpos.xz * 1.5)));
	c = mix(c, roof_c, roof);
	float v = texture(fog_tex, wpos.xz / map_size).r;
	c *= mix(0.05, 1.0, v);
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.35, win * is_wall * curtain);
	SPECULAR = 0.25;
	METALLIC = 0.0;
}
