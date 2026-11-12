class_name GameSettings
extends RefCounted
## إعدادات الجودة والإطارات (تُحفظ في user://graphics.cfg وتُطبَّق فوراً وفعلياً على المحرك).
## الجودة: 0 منخفضة، 1 متوسطة، 2 عالية، 3 تلقائية (الأفضل: تكتشف قوة الهاتف وتضبط الرسوميات والدقة لحظياً لتبقى الإطارات بين 40 و100).
## الهاتف الضعيف يبدأ بإعدادات خفيفة سريعة، والمتوسط والقوي يحصلان على رسوميات أعلى وإطارات حتى 100.

const PATH := "user://graphics.cfg"
const QUALITY_NAMES := ["منخفضة", "متوسطة", "عالية", "تلقائية"]
const QUALITY_HINTS := [
	"منخفضة: بلا ظلال ولا تنعيم حواف، دقة العرض 75٪، وتفاصيل أقل. للهواتف الضعيفة.",
	"متوسطة: ظلال خفيفة قريبة، دقة العرض 88٪، وحواف مصقولة. الأنسب لأغلب الهواتف.",
	"عالية: ظلال كاملة للمباني والوحدات، دقة 100٪ وحواف ناعمة. للهواتف القوية.",
	"تلقائية (الأفضل): تكتشف قوة هاتفك وترفع الرسوميات تلقائياً إن كان متوسطاً أو قوياً، وتخفضها إن نزلت الإطارات عن 40.",
]
const FPS_VALUES := [30, 60, 100, 0]
const FPS_NAMES := ["30", "60", "100", "تلقائي"]
const FPS_HINTS := [
	"30 إطاراً: أقل استهلاكاً للبطارية وحرارة أقل.",
	"60 إطاراً: حركة سلسة.",
	"100 إطار: أقصى سلاسة للهواتف القوية.",
	"تلقائي (الأفضل): بين 40 و100 إطار حسب قوة هاتفك ومعدل تحديث شاشتك.",
]
const SCALES := [0.75, 0.88, 1.0]
const CFG_VER := 4
const FX := [0.35, 0.7, 1.0]
const VEG := [0.45, 0.7, 1.0]
const ATLAS := [1024, 1024, 2048]
const SHADOW_DIST := [0.0, 45.0, 70.0]
const AUTO_TARGET := 40.0

static var quality := 3
static var brightness := 1.0   # 0.7 .. 1.3
static var contrast := 1.0     # 0.8 .. 1.3
static var saturation := 1.0   # 0.5 .. 1.5
static var fps := 0            # 30 / 60 / 100 / 0 (تلقائي: حتى 100)
static var show_fps := true
static var tier := 1           # قوة الجهاز: 0 ضعيف، 1 متوسط، 2 قوي
static var auto_level := 1     # إعداد الجودة الفعلي في الوضع التلقائي
static var auto_max := 2
static var _low_n := 0
static var _high_n := 0
static var _lvl_cd := 0.0
static var loaded := false
static var auto_scale := 0.8
static var _acc := 0.0
static var _last_p := -1


# الجودة الافتراضية: التلقائية تناسب كل الأجهزة
static func auto_quality() -> int:
	return 3


# الإعداد الفعلي المستخدم: التلقائية تعمل على أساس المتوسطة (أو المنخفضة مؤقتاً عند ضعف الأداء)
static func preset() -> int:
	if quality >= 3:
		return clampi(auto_level, 0, 2)
	return quality


static func fx_scale() -> float:
	return float(FX[preset()])


static func fps_index() -> int:
	var i: int = FPS_VALUES.find(fps)
	return 3 if i < 0 else i


static func load_cfg() -> void:
	if loaded:
		return
	loaded = true
	quality = auto_quality()
	tier = detect_tier()
	auto_level = tier
	auto_max = 2
	auto_scale = [0.7, 0.85, 1.0][tier]
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		# إعداد الجودة المحفوظ من نسخة قديمة يُتجاهل مرة واحدة (كان غالباً «منخفضة» أو «عالية» بلا قياس)
		if int(cf.get_value("gfx", "ver", 0)) >= CFG_VER:
			quality = clampi(int(cf.get_value("gfx", "quality", quality)), 0, 3)
		if int(cf.get_value("gfx", "ver", 0)) >= CFG_VER:
			fps = int(cf.get_value("gfx", "fps", 0))
			show_fps = bool(cf.get_value("gfx", "show_fps", true))
		if not FPS_VALUES.has(fps):
			fps = 0


static func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "ver", CFG_VER)
	cf.set_value("gfx", "quality", quality)
	cf.set_value("gfx", "fps", fps)
	cf.set_value("gfx", "show_fps", show_fps)
	cf.save(PATH)


static func reset_image() -> void:
	brightness = 1.0
	contrast = 1.0
	saturation = 1.0


# يطبّق كل الإعدادات على المحرك (آمن للاستدعاء في أي وقت، حتى قبل وجود التضاريس)
static func apply(main: Main) -> void:
	load_cfg()
	var p: int = preset()
	var vp: Viewport = main.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = auto_scale if quality >= 3 else float(SCALES[p])
	vp.msaa_3d = Viewport.MSAA_2X if p == 2 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	Engine.max_fps = 100 if fps == 0 else fps
	if p != _last_p:
		_last_p = p
		RenderingServer.directional_shadow_atlas_set_size(int(ATLAS[p]), true)
		var sq: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW]
		RenderingServer.directional_soft_shadow_filter_set_quality(sq[p])
	for c in main.get_children():
		if c is DirectionalLight3D:
			var sun: DirectionalLight3D = c
			sun.shadow_enabled = p > 0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if p < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = maxf(float(SHADOW_DIST[p]), 10.0)
		elif c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env != null:
				# تعديل الألوان تمريرة كاملة للشاشة: نستخدمها في الجودة العالية فقط
				env.adjustment_enabled = p == 2
				env.adjustment_brightness = brightness
				env.adjustment_contrast = 1.1 * contrast
				env.adjustment_saturation = 1.12 * saturation
	apply_shadows(main, p == 2)
	var tr = main.terrain
	if tr != null and is_instance_valid(tr):
		for m in tr.get_children():
			if m is MultiMeshInstance3D:
				if not m.has_meta("vr0"):
					m.set_meta("vr0", m.visibility_range_end)
				m.visibility_range_end = float(m.get_meta("vr0")) * float(VEG[p])
		if tr.water_mat != null:
			tr.water_mat.set_shader_parameter("detail", p)
		if tr.terr_mat != null:
			tr.terr_mat.set_shader_parameter("detail", p)


# المجسمات (وحدات ومبانٍ وأشجار وعمارات المدينة) تلقي ظلالاً في الجودة العالية فقط: توفير كبير في الرسم
static func apply_shadows(main: Main, on: bool) -> void:
	var mode: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for u in main.units:
		if is_instance_valid(u):
			u.set_shadows(on)
	for b in main.blds:
		if is_instance_valid(b):
			b.set_shadows(on)
	var tr = main.terrain
	if tr != null and is_instance_valid(tr):
		for m in tr.get_children():
			if m is MultiMeshInstance3D:
				(m as MultiMeshInstance3D).cast_shadow = mode


# قوة الجهاز من عدد الأنوية والذاكرة ونوع المعالج الرسومي: 0 ضعيف، 1 متوسط، 2 قوي
static func detect_tier() -> int:
	var score := 0
	var cores: int = OS.get_processor_count()
	if cores >= 8:
		score += 2
	elif cores >= 6:
		score += 1
	elif cores <= 4:
		score -= 1
	var mi: Dictionary = OS.get_memory_info()
	var mem: int = int(mi.get("physical", -1))
	if mem > 0:
		var gb: float = float(mem) / 1073741824.0
		if gb >= 7.5:
			score += 2
		elif gb >= 5.5:
			score += 1
		elif gb < 3.5:
			score -= 1
	var gpu: String = RenderingServer.get_video_adapter_name().to_lower()
	var rx := RegEx.new()
	if "adreno" in gpu:
		rx.compile("(\\d{3})")
		var m: RegExMatch = rx.search(gpu)
		if m != null:
			var n: int = int(m.get_string(1))
			if n >= 700:
				score += 2
			elif n >= 640:
				score += 1
			elif n <= 540:
				score -= 1
	elif "mali" in gpu:
		rx.compile("g(\\d+)")
		var m2: RegExMatch = rx.search(gpu)
		if m2 != null:
			var n2: int = int(m2.get_string(1))
			if n2 >= 710:
				score += 2
			elif n2 >= 76:
				score += 1
			elif n2 <= 52:
				score -= 1
		else:
			score -= 2
	elif "apple" in gpu:
		score += 2
	elif OS.has_feature("pc"):
		score += 2
	if score <= 0:
		return 0
	if score <= 2:
		return 1
	return 2


static func fps_cap() -> float:
	return 100.0 if fps == 0 else float(fps)


# الجودة التلقائية: كل ثانية ونصف نقيس الإطارات. أقل من 40 نخفض الدقة ثم الإعداد، وإن فاضت القوة (قرب 90) نرفعهما.
static func tick(main: Main, delta: float) -> void:
	if quality < 3:
		return
	_acc += delta
	if _acc < 1.5:
		return
	_acc = 0.0
	_lvl_cd = maxf(0.0, _lvl_cd - 1.5)
	var cur: float = Engine.get_frames_per_second()
	var cap: float = fps_cap()
	var floor_fps: float = minf(AUTO_TARGET, cap * 0.9)
	var up_fps: float = minf(cap * 0.9, 90.0)
	if cur < floor_fps * 0.95:
		_low_n += 1
		_high_n = 0
	elif cur >= up_fps:
		_high_n += 1
		_low_n = 0
	else:
		_low_n = 0
		_high_n = 0
	var old: float = auto_scale
	if _low_n >= 1:
		if auto_scale > 0.58:
			auto_scale = maxf(0.55, auto_scale - 0.07)
		elif auto_level > 0 and _low_n >= 3 and _lvl_cd <= 0.0:
			auto_level -= 1
			auto_max = auto_level
			auto_scale = 0.75
			_lvl_cd = 30.0
			_low_n = 0
			apply(main)
			return
	elif _high_n >= 3:
		if auto_scale < 1.0:
			auto_scale = minf(1.0, auto_scale + 0.05)
		elif auto_level < auto_max and _high_n >= 6 and _lvl_cd <= 0.0:
			auto_level += 1
			auto_scale = 0.85
			_lvl_cd = 30.0
			_high_n = 0
			apply(main)
			return
	if absf(auto_scale - old) > 0.001:
		main.get_viewport().scaling_3d_scale = auto_scale
