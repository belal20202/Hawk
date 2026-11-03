shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرضية مدينة حديثة: شبكة شوارع أسفلتية بخطوط وعبّارات مشاة، أرصفة مبلّطة، ساحات خرسانية وحدائق خضراء.
// الشوارع تتكرر كل 52 وحدة (26 خلية) بعرض 8 وحدات (4 خلايا)، وتطابق ثوابت City في scripts/city.gd.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 720.0;
uniform int detail = 2;   // 0 منخفض، 1 متوسط، 2 عالٍ
const float PER = 52.0;
const float ST = 8.0;
varying vec3 wpos;
varying vec3 wn;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 base = COLOR.rgb;
	float dist = length(VERTEX);
	float nf = 1.0 - smoothstep(50.0, 150.0, dist);
	float pw = max(fwidth(p.x), fwidth(p.y)) + 0.0005;

	float mx = max(base.r, max(base.g, base.b));
	float grassy = smoothstep(0.03, 0.12, base.g - base.r);
	float road_v = 1.0 - smoothstep(0.22, 0.34, mx);

	vec2 m = mod(p, vec2(PER));
	float sx = 1.0 - smoothstep(ST - pw, ST + pw, m.x);
	float sz = 1.0 - smoothstep(ST - pw, ST + pw, m.y);
	float street = max(max(sx, sz), road_v);
	float inter = sx * sz;

	// أرصفة على جانبي الشارع
	float ax = (1.0 - smoothstep(ST + 1.6 - pw, ST + 1.6 + pw, m.x)) + smoothstep(PER - 1.6 - pw, PER - 1.6 + pw, m.x);
	float az = (1.0 - smoothstep(ST + 1.6 - pw, ST + 1.6 + pw, m.y)) + smoothstep(PER - 1.6 - pw, PER - 1.6 + pw, m.y);
	float walk = clamp(max(ax, az), 0.0, 1.0) * (1.0 - street) * (1.0 - grassy);

	// المباني تُرى بوضوح فوق الأرضية: الخرسانة والحدائق بتدرجات واضحة
	float big = vnoise(p * 0.02);
	float mid = vnoise(p * 0.13);
	vec3 ground = base * (0.86 + 0.26 * big + 0.1 * (mid - 0.5));
	vec2 pv = abs(fract(p / 3.0) - 0.5);
	float joint = 1.0 - smoothstep(0.455, 0.5, max(pv.x, pv.y));
	ground *= mix(1.0, 0.9 + 0.1 * joint, (1.0 - grassy) * nf);
	float mow = 0.5 + 0.5 * sin(p.x * 1.3 + p.y * 0.4 + mid * 6.0);
	ground = mix(ground, ground * (0.9 + 0.2 * mow), grassy * nf);
	ground *= 0.95 + 0.1 * vnoise(p * 2.7) * nf;

	// الرصيف: بلاط صغير
	vec3 sidewalk = vec3(0.64, 0.62, 0.58) * (0.92 + 0.12 * vnoise(p * 0.3));
	vec2 tv = abs(fract(p / 1.2) - 0.5);
	sidewalk *= 0.9 + 0.1 * (1.0 - smoothstep(0.44, 0.5, max(tv.x, tv.y)));
	vec3 c = mix(ground, sidewalk, walk);

	// الأسفلت
	vec3 asphalt = vec3(0.16, 0.165, 0.18) * (0.88 + 0.22 * vnoise(p * 0.5));
	asphalt *= 0.96 + 0.08 * hash(floor(p * 7.0)) * nf;
	// بقع زيت وإصلاحات خفيفة
	asphalt = mix(asphalt, asphalt * 0.8, smoothstep(0.62, 0.8, vnoise(p * 0.09 + 5.0)) * 0.5);
	c = mix(c, asphalt, street);

	// علامات الشوارع (خارج التقاطعات)
	float lane = 1.0 - inter;
	float cl_x = 1.0 - smoothstep(0.1 - pw, 0.1 + pw, abs(m.x - ST * 0.5));
	float cl_z = 1.0 - smoothstep(0.1 - pw, 0.1 + pw, abs(m.y - ST * 0.5));
	float dash_z = step(0.42, fract(p.y / 6.0));
	float dash_x = step(0.42, fract(p.x / 6.0));
	float yellow = max(cl_x * sx * dash_z * (1.0 - sz), cl_z * sz * dash_x * (1.0 - sx));
	float e1x = 1.0 - smoothstep(0.07 - pw, 0.07 + pw, abs(m.x - 0.55));
	float e2x = 1.0 - smoothstep(0.07 - pw, 0.07 + pw, abs(m.x - (ST - 0.55)));
	float e1z = 1.0 - smoothstep(0.07 - pw, 0.07 + pw, abs(m.y - 0.55));
	float e2z = 1.0 - smoothstep(0.07 - pw, 0.07 + pw, abs(m.y - (ST - 0.55)));
	float edge_l = max(max(e1x, e2x) * sx * (1.0 - sz), max(e1z, e2z) * sz * (1.0 - sx));
	// عبّارات المشاة عند مداخل التقاطعات
	float zz = step(ST + 0.3, m.y) * (1.0 - step(ST + 2.4, m.y)) + step(PER - 2.4, m.y) * (1.0 - step(PER - 0.3, m.y));
	float zx = step(ST + 0.3, m.x) * (1.0 - step(ST + 2.4, m.x)) + step(PER - 2.4, m.x) * (1.0 - step(PER - 0.3, m.x));
	float cross_w = max(zz * sx * step(0.5, fract(p.x * 0.8)), zx * sz * step(0.5, fract(p.y * 0.8)));
	float marks = max(yellow, max(edge_l, cross_w)) * lane * (1.0 - road_v) * nf;
	vec3 mark_col = mix(vec3(0.92, 0.9, 0.86), vec3(0.95, 0.76, 0.18), yellow);
	c = mix(c, mark_col, marks * 0.9);

	// منحدرات الشواطئ والجسور: حجر رمادي طبقي
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float strata = sin(wpos.y * 3.0 + mid * 2.5) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.45, 0.44, 0.42), vec3(0.62, 0.6, 0.57), strata);
	c = mix(c, rock, smoothstep(0.2, 0.5, slope));

	// رصيف مبلل قرب خط الماء
	float wet = 1.0 - smoothstep(-0.1, 0.5, wpos.y);
	c = mix(c, c * vec3(0.6, 0.62, 0.64), wet);

	// اضطراب خفيف في الإضاءة يُظهر خشونة الأسفلت والعشب
	if (detail >= 1) {
		float h0 = vnoise(p * 1.7);
		float gx = vnoise((p + vec2(0.25, 0.0)) * 1.7) - h0;
		float gz = vnoise((p + vec2(0.0, 0.25)) * 1.7) - h0;
		vec3 bump = vec3(-gx, 0.0, -gz) * 0.9 * nf;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	}

	float v = texture(fog_tex, p / map_size).r;
	c *= mix(0.05, 1.0, v);
	ALBEDO = c;
	ROUGHNESS = mix(0.92, 0.65, wet);
	SPECULAR = 0.1;
}
