shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرضية صحراوية جميلة وخفيفة على الأجهزة المتوسطة: رمل بتدرجات دافئة وباردة، تموجات رياح وكثبان مرئية بالإضاءة،
// تربة جافة متشققة، وحصى متناثر. التفاصيل الدقيقة تظهر قرب الكاميرا فقط (detail: 0 منخفض، 1 متوسط، 2 عالٍ).
// الدوال لا تستخدم sin() في التجزئة: هواتف أندرويد تفقد الدقة فيها فتظهر الأرض مبقّعة.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 720.0;
uniform int detail = 2;
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
	float nf = 1.0 - smoothstep(40.0, 125.0, dist);
	float fine = (detail >= 1) ? nf : 0.0;

	// تدرجات واسعة: رمل فاتح وأغمق مع ميل دافئ/بارد
	float big = vnoise(p * 0.018);
	float mid = vnoise(p * 0.09);
	float tint = vnoise(p * 0.045 + 21.0);
	vec3 c = base * (0.8 + 0.4 * big + 0.16 * (mid - 0.5));
	c *= mix(vec3(1.04, 0.98, 0.9), vec3(0.97, 1.0, 1.04), tint);

	// تربة جافة داكنة على بقع واسعة
	float pan = smoothstep(0.52, 0.72, vnoise(p * 0.03 + 7.0));
	c = mix(c, c * vec3(0.8, 0.68, 0.54), pan * 0.7);

	// تموجات رياح وكثبان عريضة (خطوط واضحة قرب الكاميرا)
	float sandness = smoothstep(0.55, 0.8, base.r) * smoothstep(0.42, 0.62, base.g);
	float dir = dot(p, vec2(0.86, 0.5));
	float ph = dir * 2.2 + big * 14.0 + mid * 5.0;
	float rip = sin(ph) * 0.5 + 0.5;
	c *= 1.0 - 0.15 * sandness * rip * (0.3 + 0.7 * nf);
	float dune = sin(dir * 0.16 + big * 9.0) * 0.5 + 0.5;
	c *= 1.0 - 0.1 * sandness * dune;

	if (fine > 0.0) {
		// تشققات التربة الجافة
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(vnoise(p * 0.55 + 11.0) - 0.5));
		c *= 1.0 - 0.3 * crack * pan * fine;
		// حبيبات الرمل
		c *= 0.94 + 0.12 * vnoise(p * 2.3) * fine;
		// حصى متناثر
		vec2 cell = floor(p * 2.4);
		vec2 off = vec2(hash(cell), hash(cell + 17.3)) * 0.6 + 0.2;
		float dd = length(fract(p * 2.4) - off);
		float stone = (1.0 - smoothstep(0.07, 0.13, dd)) * step(0.8, hash(cell + 3.7)) * fine;
		c = mix(c, c * 0.62, stone);
		c += 0.05 * stone * (1.0 - smoothstep(0.0, 0.07, dd));
	}

	// منحدرات الشواطئ والجسور: صخر طبقي
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	if (slope > 0.2) {
		float strata = sin(wpos.y * 3.0 + mid * 2.5) * 0.5 + 0.5;
		vec3 rock = mix(vec3(0.5, 0.39, 0.29), vec3(0.68, 0.54, 0.4), strata);
		c = mix(c, rock, smoothstep(0.2, 0.5, slope));
	}

	// رمل مبلل قرب خط الماء
	float wet = 1.0 - smoothstep(-0.1, 0.5, wpos.y);
	c = mix(c, c * vec3(0.58, 0.54, 0.46), wet);

	// إضاءة التموجات والكثبان بالتعتيم الاتجاهي (الأرض نفسها مستوية)
	if (detail >= 1 && nf > 0.05) {
		float rc = cos(ph) * 0.3 * sandness;
		float dc = cos(dir * 0.16 + big * 9.0) * 0.06 * sandness;
		vec3 bump = vec3(-(rc + dc) * 0.86, 0.0, -(rc + dc) * 0.5) * nf;
		if (detail >= 2) {
			float h0 = vnoise(p * 3.1);
			float hx = vnoise((p + vec2(0.12, 0.0)) * 3.1) - h0;
			float hz = vnoise((p + vec2(0.0, 0.12)) * 3.1) - h0;
			bump += vec3(-hx, 0.0, -hz) * nf;
		}
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	}

	float v = texture(fog_tex, p / map_size).r;
	c *= mix(0.05, 1.0, v);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.7, wet);
	SPECULAR = 0.12;
}
