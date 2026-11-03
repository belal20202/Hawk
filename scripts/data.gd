extends Node
## بيانات اللعبة: الجيوش والوحدات والمنشآت والأنماط. عدّل الأرقام هنا لتغيير التوازن.

const VERSION := "1.3.0"
const MAP := 360         # عدد الخلايا في كل ضلع (360 = خريطة كبيرة، 256 = أخف على الهواتف الضعيفة)
const K := 1.40625       # نسبة التكبير مقارنة بالخريطة الأساسية (MAP / 256)
const CELL := 2.0        # طول الخلية بالمتر
const MINE_GOLD := 5000.0    # كمية الذهب في كل منجم
const TRUCK_LOAD := 300.0    # حمولة الشاحنة في الرحلة الواحدة
var BASES: Array = []        # أربع قواعد: 0 أسفل اليسار، 1 أعلى اليسار، 2 أعلى اليمين، 3 أسفل اليمين
var MINES: Array = []


func _ready() -> void:
	for p in [Vector2(36, 212), Vector2(36, 44), Vector2(217, 41), Vector2(217, 212)]:
		BASES.append(Vector2i(roundi(p.x * K), roundi(p.y * K)))
	var quad := [Vector2i(46, 196), Vector2i(34, 172), Vector2i(62, 226), Vector2i(74, 200), Vector2i(54, 150), Vector2i(88, 178), Vector2i(30, 140)]
	for q in quad:
		var x: int = roundi(q.x * K)
		var y: int = roundi(q.y * K)
		var mx: int = MAP - 2 - x
		var my: int = MAP - 2 - y
		MINES.append(Vector2i(x, y))
		MINES.append(Vector2i(x, my))
		MINES.append(Vector2i(mx, y))
		MINES.append(Vector2i(mx, my))


# جيوش بأسماء مهيبة. لون كل جيش يظهر على الأعلام والأسقف والأشرطة.
var ARMIES := {
	"red": {"name": "فيلق اللهيب القرمزي", "short": "اللهيب", "color": Color.html("d92b2b"), "desc": "+10٪ صحة لكل الوحدات", "hp": 1.1},
	"blue": {"name": "حرس العاصفة الزرقاء", "short": "العاصفة", "color": Color.html("2b6cde"), "desc": "+15٪ دخل الذهب", "inc": 1.15},
	"yellow": {"name": "جحافل الشمس الذهبية", "short": "الشمس", "color": Color.html("f2c21a"), "desc": "+10٪ ضرر لكل الوحدات", "dmg": 1.1},
	"white": {"name": "حرس الثلج الملكي", "short": "الثلج", "color": Color.html("f4f4f0"), "desc": "+400 ذهب عند البداية", "gold": 400},
}

# أنماط اللعب. players: خانات القواعد المشاركة، teams: رقم الفريق لكل خانة (-1 غير مشاركة)
var MODES := {
	"1v1": {"name": "1 ضد 1", "desc": "مواجهة مباشرة مع جيش واحد", "players": [0, 2], "teams": [0, -1, 1, -1], "boost": 1.0},
	"2v2": {"name": "2 ضد 2", "desc": "أنت وحليف يقوده الحاسوب ضد جيشين متحالفين", "players": [0, 1, 2, 3], "teams": [0, 0, 1, 1], "boost": 1.0},
	"1v2": {"name": "1 ضد 2", "desc": "وحدك ضد جيشين متحالفين. تحدٍّ صعب", "players": [0, 2, 3], "teams": [0, -1, 1, 1], "boost": 1.0},
	"2v1": {"name": "2 ضد 1", "desc": "أنت وحليفك ضد جيش واحد أقوى", "players": [0, 1, 2], "teams": [0, 0, 1, -1], "boost": 1.3},
}

# ثلاثة مستويات حقيقية تختلف في كل شيء: قوة العدو واقتصاده وسلوك هجماته.
# every: ثواني بين قرارات التدريب، gm: مضاعف دخل العدو، bt: ثواني بين قرارات البناء
# hp/dmg: مضاعف صحة وضرر العدو، air: هل يستخدم الطيران، trucks: عدد شاحنات الذهب
# depots: عدد مقرات الذهب، tech: مستوى الوحدات المتقدمة 0..2، gold: ذهب إضافي للعدو عند البداية
# لا يوجد وقت ثابت للهجوم: العدو يهاجم عندما يجهز جيشه، من اتجاه عشوائي، وبلا موعد يمكن توقعه.
# raid: حجم المفرزة، gap: أقل راحة بين المفارز (تُضرب بعشوائية)، wave: أقل عدد للهجوم الشامل،
# full_gap: أقل راحة بين الهجمات الشاملة، aggr: ميل العدو للهجوم كلما جهز جيشه (0..1)
# def_max: أقصى عدد دفاعات يبنيها العدو حول مدينته، def_kinds: أنواع الدفاعات المتاحة له
var DIFF := {
	"easy": {"name": "سهل", "desc": "عدو بطيء، مفارز صغيرة من اتجاهات مختلفة ودفاعات قليلة", "every": 26.0, "gm": 0.55, "bt": 55.0, "hp": 0.75, "dmg": 0.65, "air": false, "trucks": 2, "depots": 1, "tech": 0, "gold": 0, "raid": 3, "gap": 150.0, "wave": 10, "full_gap": 420.0, "aggr": 0.35, "def_max": 3, "def_kinds": ["twr", "cnn"]},
	"normal": {"name": "متوسط", "desc": "عدو متوازن: مفارز متتابعة وهجمات شاملة من عدة جهات ودفاعات متنوعة", "every": 15.0, "gm": 0.9, "bt": 32.0, "hp": 1.0, "dmg": 0.95, "air": false, "trucks": 3, "depots": 2, "tech": 1, "gold": 0, "raid": 5, "gap": 100.0, "wave": 14, "full_gap": 300.0, "aggr": 0.55, "def_max": 7, "def_kinds": ["twr", "cnn", "mor", "aat"]},
	"hard": {"name": "صعب", "desc": "عدو شرس بدبابات ثقيلة وطيران ودفاعات متقدمة، يضرب من كل الجهات", "every": 8.0, "gm": 1.25, "bt": 20.0, "hp": 1.1, "dmg": 1.05, "air": true, "trucks": 5, "depots": 3, "tech": 2, "gold": 400, "raid": 7, "gap": 70.0, "wave": 18, "full_gap": 220.0, "aggr": 0.8, "def_max": 13, "def_kinds": ["twr", "cnn", "mor", "aat", "rkt", "lsr"]},
}

# المسافات (range, vis) بوحدة الخلايا، والسرعة بخلية/ثانية.
# cls: فئة الوحدة (inf مشاة، veh آلية، air طيران). vs: مضاعف الضرر على كل فئة هدف (bld مبنى)
var UNITS := {
	"inf": {"name": "مشاة", "cls": "inf", "hp": 70.0, "speed": 2.4, "range": 4.5, "dmg": 9.0, "cd": 0.7, "cost": 100, "time": 4.0, "vis": 7.0, "air": false, "noair": false, "radius": 0.8, "vs": {"inf": 1.0, "veh": 0.45, "air": 0.4, "bld": 0.5}},
	"rpg": {"name": "قاذف صواريخ", "cls": "inf", "hp": 80.0, "speed": 2.1, "range": 6.0, "dmg": 38.0, "cd": 2.2, "cost": 200, "time": 6.0, "vis": 7.0, "air": false, "noair": true, "radius": 0.8, "vs": {"inf": 0.5, "veh": 1.7, "air": 0.0, "bld": 1.1}},
	"sniper": {"name": "قناص", "cls": "inf", "hp": 55.0, "speed": 2.2, "range": 11.0, "dmg": 55.0, "cd": 3.0, "cost": 250, "time": 7.0, "vis": 10.0, "air": false, "noair": true, "radius": 0.8, "vs": {"inf": 1.5, "veh": 0.15, "air": 0.0, "bld": 0.1}},
	"mg": {"name": "رشّاش", "cls": "inf", "hp": 90.0, "speed": 2.2, "range": 5.5, "dmg": 5.0, "cd": 0.2, "cost": 160, "time": 5.0, "vis": 7.0, "air": false, "noair": false, "radius": 0.8, "vs": {"inf": 1.3, "veh": 0.3, "air": 0.5, "bld": 0.25}},
	"cmd": {"name": "كوماندوز", "cls": "inf", "hp": 150.0, "speed": 2.9, "range": 5.0, "dmg": 13.0, "cd": 0.45, "cost": 330, "time": 8.0, "vis": 8.0, "air": false, "noair": false, "radius": 0.8, "vs": {"inf": 1.3, "veh": 0.6, "air": 0.6, "bld": 1.0}},
	"lt": {"name": "مدرعة خفيفة", "cls": "veh", "hp": 170.0, "speed": 3.2, "range": 5.5, "dmg": 16.0, "cd": 0.9, "cost": 220, "time": 6.0, "vis": 8.0, "air": false, "noair": false, "radius": 1.8, "vs": {"inf": 1.3, "veh": 0.7, "air": 0.5, "bld": 0.6}},
	"tank": {"name": "دبابة", "cls": "veh", "hp": 260.0, "speed": 1.9, "range": 6.5, "dmg": 30.0, "cd": 1.5, "cost": 350, "time": 8.0, "vis": 8.0, "air": false, "noair": true, "radius": 2.2, "vs": {"inf": 0.8, "veh": 1.0, "air": 0.0, "bld": 1.3}},
	"heavy": {"name": "دبابة ثقيلة", "cls": "veh", "hp": 480.0, "speed": 1.4, "range": 7.0, "dmg": 55.0, "cd": 1.9, "cost": 650, "time": 12.0, "vis": 8.0, "air": false, "noair": true, "radius": 2.6, "vs": {"inf": 0.8, "veh": 1.2, "air": 0.0, "bld": 1.5}},
	"art": {"name": "مدفعية", "cls": "veh", "hp": 110.0, "speed": 1.5, "range": 11.0, "dmg": 40.0, "cd": 2.6, "cost": 450, "time": 10.0, "vis": 7.0, "air": false, "noair": true, "radius": 2.2, "vs": {"inf": 1.0, "veh": 0.9, "air": 0.0, "bld": 1.6}},
	"aa": {"name": "مضاد طيران", "cls": "veh", "hp": 150.0, "speed": 2.2, "range": 9.0, "dmg": 12.0, "cd": 0.25, "cost": 400, "time": 8.0, "vis": 9.0, "air": false, "noair": false, "radius": 2.1, "vs": {"inf": 0.3, "veh": 0.2, "air": 2.4, "bld": 0.1}},
	"heli": {"name": "مروحية", "cls": "air", "hp": 150.0, "speed": 3.4, "range": 5.5, "dmg": 14.0, "cd": 0.5, "cost": 500, "time": 10.0, "vis": 9.0, "air": true, "noair": false, "radius": 2.6, "vs": {"inf": 1.2, "veh": 0.9, "air": 0.8, "bld": 0.8}},
	"jet": {"name": "مقاتلة", "cls": "air", "hp": 120.0, "speed": 5.2, "range": 6.0, "dmg": 26.0, "cd": 1.0, "cost": 700, "time": 14.0, "vis": 10.0, "air": true, "noair": false, "radius": 2.2, "vs": {"inf": 0.6, "veh": 1.0, "air": 1.8, "bld": 1.0}},
	"bomber": {"name": "قاذفة", "cls": "air", "hp": 230.0, "speed": 3.6, "range": 2.5, "dmg": 90.0, "cd": 2.8, "cost": 900, "time": 16.0, "vis": 9.0, "air": true, "noair": true, "radius": 3.4, "vs": {"inf": 1.0, "veh": 1.2, "air": 0.0, "bld": 2.2}},
	"truck": {"name": "شاحنة ذهب", "cls": "veh", "hp": 180.0, "speed": 3.0, "range": 0.0, "dmg": 0.0, "cd": 99.0, "cost": 300, "time": 6.0, "vis": 6.0, "air": false, "noair": true, "radius": 2.1, "vs": {"inf": 0.0, "veh": 0.0, "air": 0.0, "bld": 0.0}},
}

# cat: تبويب البناء (main أساسية، eco خدمات واقتصاد، def دفاع، wall أسوار)
# الدفاعات: range بالخلايا، dmg، cd، mode (all الكل، ground أرضي فقط، air جوي فقط)، vs مضاعف الضرر حسب الفئة،
# splash نصف قطر الانفجار بالأمتار، heavy مقذوف كبير، shot اسم صوت الإطلاق، mh/ml ارتفاع وطول فوهة المدفع
var BUILDINGS := {
	"hq": {"name": "مقر القيادة", "size": 3, "hp": 2400.0, "vis": 10.0, "cost": 0, "bt": 1.0, "train": [], "cat": "main"},
	"dep": {"name": "مقر تجميع الذهب", "size": 3, "hp": 1100.0, "vis": 8.0, "cost": 600, "bt": 10.0, "train": ["truck"], "cat": "main", "info": "شاحنات الذهب"},
	"bar": {"name": "ثكنة", "size": 2, "hp": 700.0, "vis": 7.0, "cost": 300, "bt": 8.0, "train": ["inf", "mg", "rpg", "sniper", "cmd"], "cat": "main", "info": "مشاة"},
	"fac": {"name": "مصنع دبابات", "size": 3, "hp": 950.0, "vis": 7.0, "cost": 600, "bt": 12.0, "train": ["lt", "tank", "heavy", "art", "aa"], "cat": "main", "info": "آليات"},
	"air": {"name": "مطار", "size": 3, "hp": 900.0, "vis": 8.0, "cost": 800, "bt": 14.0, "train": ["heli", "jet", "bomber"], "cat": "main", "info": "طيران"},
	"ref": {"name": "مصفاة الذهب", "size": 3, "hp": 1000.0, "vis": 8.0, "cost": 900, "bt": 14.0, "train": [], "cat": "eco", "info": "+12٪ دخل", "income": 0.12},
	"rep": {"name": "ورشة إصلاح", "size": 3, "hp": 850.0, "vis": 8.0, "cost": 550, "bt": 11.0, "train": [], "cat": "eco", "info": "تصلح الآليات", "heal": "veh", "heal_r": 11.0, "heal_rate": 14.0},
	"hos": {"name": "مستشفى ميداني", "size": 2, "hp": 650.0, "vis": 8.0, "cost": 350, "bt": 8.0, "train": [], "cat": "eco", "info": "تعالج الجنود", "heal": "inf", "heal_r": 10.0, "heal_rate": 11.0},
	"rad": {"name": "رادار", "size": 2, "hp": 500.0, "vis": 32.0, "cost": 450, "bt": 9.0, "train": [], "cat": "eco", "info": "يكشف الخريطة"},
	"twr": {"name": "برج رشاش", "size": 1, "hp": 520.0, "vis": 8.0, "cost": 250, "bt": 6.0, "train": [], "cat": "def", "info": "ضد الجنود", "range": 7.5, "dmg": 15.0, "cd": 0.9, "mode": "all", "vs": {"inf": 1.1, "veh": 0.5, "air": 0.6}, "shot": "shot"},
	"cnn": {"name": "مدفع دفاعي", "size": 2, "hp": 800.0, "vis": 9.0, "cost": 450, "bt": 9.0, "train": [], "cat": "def", "info": "ضد الآليات", "range": 10.0, "dmg": 52.0, "cd": 1.7, "mode": "ground", "vs": {"inf": 0.8, "veh": 1.5}, "heavy": true, "shot": "cannon", "mh": 1.5, "ml": 2.2},
	"mor": {"name": "هاون", "size": 2, "hp": 600.0, "vis": 10.0, "cost": 550, "bt": 9.0, "train": [], "cat": "def", "info": "قصف بعيد", "range": 15.0, "dmg": 38.0, "cd": 2.8, "mode": "ground", "vs": {"inf": 1.4, "veh": 0.8}, "splash": 6.0, "heavy": true, "shot": "artillery", "mh": 1.2, "ml": 1.4},
	"aat": {"name": "مضاد طيران", "size": 2, "hp": 650.0, "vis": 11.0, "cost": 400, "bt": 8.0, "train": [], "cat": "def", "info": "ضد الطيران", "range": 12.0, "dmg": 11.0, "cd": 0.22, "mode": "air", "vs": {"air": 2.3}, "shot": "aa", "mh": 1.6, "ml": 1.8},
	"rkt": {"name": "منصة صواريخ", "size": 2, "hp": 700.0, "vis": 10.0, "cost": 750, "bt": 11.0, "train": [], "cat": "def", "info": "صواريخ ثقيلة", "range": 14.0, "dmg": 90.0, "cd": 3.4, "mode": "ground", "vs": {"inf": 0.5, "veh": 1.7}, "heavy": true, "shot": "rocket", "mh": 1.8, "ml": 1.6},
	"lsr": {"name": "برج ليزر", "size": 2, "hp": 900.0, "vis": 10.0, "cost": 900, "bt": 12.0, "train": [], "cat": "def", "info": "يصيب كل شيء", "range": 9.5, "dmg": 20.0, "cd": 0.3, "mode": "all", "vs": {"inf": 1.2, "veh": 1.0, "air": 1.4}, "shot": "heli_gun", "mh": 2.4, "ml": 1.2},
	"wall": {"name": "سور", "size": 1, "hp": 1100.0, "vis": 3.0, "cost": 40, "bt": 2.0, "train": [], "cat": "wall", "info": "يمنع العدو"},
	"gate": {"name": "بوابة", "size": 2, "hp": 1500.0, "vis": 6.0, "cost": 200, "bt": 5.0, "train": [], "cat": "wall", "info": "لجيشك فقط"},
}

# تبويبات قائمة البناء
const BUILD_TABS := [["main", "أساسية"], ["def", "دفاعات"], ["eco", "خدمات"], ["wall", "أسوار"]]
