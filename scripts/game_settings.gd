class_name GameSettings
extends RefCounted
## إعدادات الجودة والإطارات (تُحفظ في user://graphics.cfg وتُطبَّق فوراً وفعلياً على المحرك).
## الجودة: 0 منخفضة، 1 متوسطة، 2 عالية، 3 تلقائية (الأفضل: تضبط دقة العرض لحظياً لتثبيت 40 إطاراً أو أكثر).
## الهدف: لعبة سلسة على الأجهزة المتوسطة: ظلال ديناميكية قليلة، تنعيم حواف خفيف، وتفاصيل بعيدة أقل.

const PATH := "user://graphics.cfg"
const QUALITY_NAMES := ["منخفضة", "متوسطة", "عالية", "تلقائية"]
const QUALITY_HINTS := [
	"منخفضة: بلا ظلال ولا تنعيم حواف، دقة العرض 75٪، وتفاصيل أقل. للهواتف الضعيفة.",
	"متوسطة: ظلال خفيفة قريبة، دقة العرض 88٪، وحواف مصقولة. الأنسب لأغلب الهواتف.",
	"عالية: ظلال كاملة للمباني والوحدات، دقة 100٪ وحواف ناعمة. للهواتف القوية.",
	"تلقائية (الأفضل): تضبط دقة العرض لحظياً لتثبيت 40 إطاراً أو أكثر على هاتفك.",
]
const FPS_VALUES := [30, 60, 0]
const FPS_NAMES := ["30", "60", "أقصى"]
const FPS_HINTS := [
	"30 إطاراً: أقل استهلاكاً للبطارية وحرارة أقل.",
	"60 إطاراً: حركة سلسة.",
	"أقصى: بلا حد، ويتبع معدل تحديث الشاشة.",
]
const SCALES := [0.75, 0.88, 1.0]
const CFG_VER := 3
const FX := [0.35, 0.7, 1.0]
const VEG := [0.45, 0.7, 1.0]
const ATLAS := [1024, 1024, 2048]
const SHADOW_DIST := [0.0, 45.0, 70.0]
const AUTO_TARGET := 40.0

static var quality := 3
static var brightness := 1.0   # 0.7 .. 1.3
static var contrast := 1.0     # 0.8 .. 1.3
static var saturation := 1.0   # 0.5 .. 1.5
static var fps := 60           # 30 / 60 / 0 (بلا حد)
static var show_fps := false
static var loaded := false
static var auto_scale := 0.8
static var auto_low := false   # في الوضع التلقائي: إيقاف الظلال مؤقتاً إن بقي الأداء ضعيفاً
static var _acc := 0.0
static var _last_p := -1


# الجودة الافتراضية: التلقائية تناسب كل الأجهزة
static func auto_quality() -> int:
	return 3


# الإعداد الفعلي المستخدم: التلقائية تعمل على أساس المتوسطة (أو المنخفضة مؤقتاً عند ضعف الأداء)
static func preset() -> int:
	if quality >= 3:
		return 0 if auto_low else 1
	return quality


static func fx_scale() -> float:
	return float(FX[preset()])


static func fps_index() -> int:
	var i: int = FPS_VALUES.find(fps)
	return 1 if i < 0 else i


static func load_cfg() -> void:
	if loaded:
		return
	loaded = true
	quality = auto_quality()
	auto_scale = 0.7 if OS.get_processor_count() <= 4 else 0.8
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		# إعداد الجودة المحفوظ من نسخة قديمة يُتجاهل مرة واحدة (كان غالباً «منخفضة» أو «عالية» بلا قياس)
		if int(cf.get_value("gfx", "ver", 0)) >= CFG_VER:
			quality = clampi(int(cf.get_value("gfx", "quality", quality)), 0, 3)
		fps = int(cf.get_value("gfx", "fps", 60))
		show_fps = bool(cf.get_value("gfx", "show_fps", false))
		if not FPS_VALUES.has(fps):
			fps = 60


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
	Engine.max_fps = fps
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


# الجودة التلقائية: كل ثانية ونصف نقيس الإطارات ونرفع أو نخفض دقة العرض بخطوات صغيرة
static func tick(main: Main, delta: float) -> void:
	if quality < 3:
		return
	_acc += delta
	if _acc < 1.5:
		return
	_acc = 0.0
	var cur: float = Engine.get_frames_per_second()
	var cap: float = float(fps) if fps > 0 else AUTO_TARGET
	var target: float = minf(AUTO_TARGET, cap)
	var old: float = auto_scale
	if cur < target * 0.92:
		auto_scale = maxf(0.55, auto_scale - 0.07)
	elif cur >= target * 1.25:
		auto_scale = minf(1.0, auto_scale + 0.03)
	# أداء ضعيف رغم أقل دقة: نوقف الظلال مؤقتاً، ونعيدها حين يتحسن الأداء كثيراً
	if not auto_low and auto_scale <= 0.6 and cur < target * 0.85:
		auto_low = true
		apply(main)
		return
	if auto_low and auto_scale >= 0.85 and cur > target * 1.5:
		auto_low = false
		apply(main)
		return
	if absf(auto_scale - old) > 0.001:
		main.get_viewport().scaling_3d_scale = auto_scale
