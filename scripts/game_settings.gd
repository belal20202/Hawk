class_name GameSettings
extends RefCounted
## إعدادات الصورة والجودة والإطارات (تُحفظ في user://graphics.cfg وتُطبَّق فوراً وفعلياً على المحرك).
## الجودة: 0 منخفضة، 1 متوسطة، 2 عالية، 3 تلقائية (تضبط دقة العرض حسب سرعة الهاتف).

const PATH := "user://graphics.cfg"
const QUALITY_NAMES := ["منخفضة", "متوسطة", "عالية", "تلقائية"]
const QUALITY_HINTS := [
	"منخفضة: بلا ظلال، دقة العرض 92٪، ومؤثرات أقل. للهواتف الضعيفة جداً.",
	"متوسطة: ظلال خفيفة، دقة العرض 100٪، وحواف مصقولة. توازن بين الجمال والسرعة.",
	"عالية: ظلال كاملة، دقة العرض 100٪، حواف ناعمة وماء بأعلى تفاصيله. للهواتف القوية.",
	"تلقائية: تبدأ متوسطة ثم ترفع دقة العرض أو تخفضها حسب أداء هاتفك لتثبيت الإطارات.",
]
const FPS_VALUES := [30, 60, 0]
const FPS_NAMES := ["30", "60", "أقصى"]
const FPS_HINTS := [
	"30 إطاراً: أقل استهلاكاً للبطارية وحرارة أقل.",
	"60 إطاراً: حركة سلسة.",
	"أقصى: بلا حد، ويتبع معدل تحديث الشاشة.",
]
const SCALES := [0.92, 1.0, 1.0]
const CFG_VER := 2
const FX := [0.4, 0.75, 1.0]
const VEG := [0.5, 0.78, 1.0]
const ATLAS := [1024, 1024, 2048]
const SHADOW_DIST := [0.0, 60.0, 95.0]

static var quality := 1
static var brightness := 1.0   # 0.7 .. 1.3
static var contrast := 1.0     # 0.8 .. 1.3
static var saturation := 1.0   # 0.5 .. 1.5
static var fps := 60           # 30 / 45 / 60 / 0 (بلا حد)
static var show_fps := false
static var loaded := false
static var auto_scale := 0.85
static var _acc := 0.0
static var _last_p := -1


# جودة مقترحة حسب قوة الجهاز (عدد أنوية المعالج) عند أول تشغيل
static func auto_quality() -> int:
	var cores: int = OS.get_processor_count()
	if cores <= 4:
		return 1
	return 2


# الإعداد الفعلي المستخدم: التلقائية تعمل على أساس المتوسطة مع دقة متغيرة
static func preset() -> int:
	return 1 if quality >= 3 else quality


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
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		# إعداد الجودة المحفوظ من نسخة قديمة (غالباً «منخفضة») يُتجاهل مرة واحدة
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
	vp.msaa_3d = Viewport.MSAA_4X if p == 2 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	Engine.max_fps = fps
	if p != _last_p:
		_last_p = p
		RenderingServer.directional_shadow_atlas_set_size(int(ATLAS[p]), true)
		var sq: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW]
		RenderingServer.directional_soft_shadow_filter_set_quality(sq[p])
	for c in main.get_children():
		if c is DirectionalLight3D:
			var sun: DirectionalLight3D = c
			sun.shadow_enabled = p > 0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if p == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = maxf(float(SHADOW_DIST[p]), 10.0)
		elif c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env != null:
				env.adjustment_enabled = true
				env.adjustment_brightness = brightness
				env.adjustment_contrast = 1.1 * contrast
				env.adjustment_saturation = 1.12 * saturation
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
			# الأرض تحتفظ بتفاصيلها (تموجات وحصى) حتى على الجودة المنخفضة
			tr.terr_mat.set_shader_parameter("detail", maxi(p, 1))


# الجودة التلقائية: كل ثانيتين نقيس الإطارات ونرفع أو نخفض دقة العرض بخطوات صغيرة
static func tick(main: Main, delta: float) -> void:
	if quality < 3:
		return
	_acc += delta
	if _acc < 2.0:
		return
	_acc = 0.0
	var cur: float = Engine.get_frames_per_second()
	var target: float = float(fps) if fps > 0 else 60.0
	var old: float = auto_scale
	if cur < target * 0.85:
		auto_scale = maxf(0.6, auto_scale - 0.07)
	elif cur >= target * 0.97:
		auto_scale = minf(1.0, auto_scale + 0.04)
	if absf(auto_scale - old) > 0.001:
		main.get_viewport().scaling_3d_scale = auto_scale
