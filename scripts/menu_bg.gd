class_name MenuBg
extends Control
## خلفية حربية متحركة للقائمة وشاشة التحميل: سماء زرقاء مشرقة بغيوم وكشافات، جبال بعيدة، وأرض عليها دبابات تتحرك
## وتطلق النار أحياناً، ومقاتلات تعبر السماء بذيول دخان، ومروحيات بمراوح دوّارة، وقاذفة كبيرة بطيئة.
## كل الرسم خلف النصوص مباشرة، وفوقه تظليل علوي وسفلي حتى تبقى الكتابة واضحة تماماً.

var t := 0.0
var stars: Array = []
var clouds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in range(40):
		stars.append(Vector3(randf(), randf() * 0.5, randf() * TAU))
	for i in range(7):
		clouds.append(Vector3(randf(), 0.06 + randf() * 0.34, 0.6 + randf() * 0.9))


func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		queue_redraw()


# تحويل نقطة محلية إلى الشاشة: origin موضع، sc مقياس، dir اتجاه الحركة (+1 يميناً، -1 يساراً)
func _tf(pts: Array, o: Vector2, sc: float, dir: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var v: Vector2 = p
		out.append(o + Vector2(v.x * dir, v.y) * sc)
	return out


func _draw() -> void:
	var s := size
	if s.x < 10.0 or s.y < 10.0:
		return
	_sky(s)
	_mountains(s)
	_ground(s)
	_planes(s)
	_tanks(s)
	_vignette(s)


func _sky(s: Vector2) -> void:
	var top := Color(0.02, 0.06, 0.2)
	var mid := Color(0.06, 0.2, 0.46)
	var hor := Color(0.2, 0.52, 0.82)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.6), Vector2(0, s.y * 0.6)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.6), Vector2(s.x, s.y * 0.6), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([mid, mid, hor, hor]))
	# نجوم خفيفة في أعلى السماء
	for st in stars:
		var v: Vector3 = st
		var a: float = 0.25 + 0.35 * (0.5 + 0.5 * sin(t * 1.6 + v.z))
		draw_rect(Rect2(v.x * s.x, v.y * s.y, 2, 2), Color(0.85, 0.93, 1.0, a))
	# توهج الشمس عند الأفق
	var sun := Vector2(s.x * 0.8, s.y * 0.72)
	for k in range(5):
		draw_circle(sun, 170.0 - float(k) * 28.0, Color(1.0, 0.86, 0.5, 0.035 + 0.012 * float(k)))
	# غيوم بطيئة
	for cl in clouds:
		var v2: Vector3 = cl
		var cx: float = fposmod(v2.x * s.x + t * 9.0 * v2.z, s.x + 400.0) - 200.0
		var cy: float = v2.y * s.y
		var sc: float = 30.0 * v2.z
		for q in range(5):
			draw_circle(Vector2(cx + float(q) * sc * 0.9, cy + sin(float(q) * 1.7) * sc * 0.25), sc * (0.8 + 0.25 * sin(float(q) * 2.3)), Color(0.85, 0.92, 1.0, 0.1))
	# كشافان يمسحان السماء
	for k in range(2):
		var bx: float = s.x * (0.18 + 0.62 * float(k))
		var by: float = s.y * 0.8
		var ang: float = -PI * 0.5 + sin(t * 0.5 + float(k) * 2.4) * 0.5
		var d: Vector2 = Vector2(cos(ang), sin(ang))
		var n: Vector2 = Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx, by) + d * s.y * 0.9 + n * 46.0, Vector2(bx, by) + d * s.y * 0.9 - n * 46.0]), Color(0.8, 0.92, 1.0, 0.07))


func _mountains(s: Vector2) -> void:
	var base: float = s.y * 0.8
	var far := PackedVector2Array([Vector2(0, s.y)])
	var near := PackedVector2Array([Vector2(0, s.y)])
	var n := 24
	for i in range(n + 1):
		var x: float = s.x * float(i) / float(n)
		far.append(Vector2(x, base - 40.0 - 36.0 * (0.5 + 0.5 * sin(float(i) * 0.9 + 1.0)) - 20.0 * sin(float(i) * 2.1)))
		near.append(Vector2(x, base - 4.0 - 24.0 * (0.5 + 0.5 * sin(float(i) * 1.3 + 4.0))))
	far.append(Vector2(s.x, s.y))
	near.append(Vector2(s.x, s.y))
	draw_colored_polygon(far, Color(0.1, 0.24, 0.5, 0.95))
	draw_colored_polygon(near, Color(0.07, 0.17, 0.38, 1.0))


func _ground(s: Vector2) -> void:
	var gy: float = s.y * 0.86
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.05, 0.12, 0.27))
	draw_rect(Rect2(0, gy, s.x, 3), Color(0.35, 0.6, 0.95, 0.55))
	# خطوط طريق تتحرك
	var off: float = fposmod(t * 60.0, 60.0)
	for i in range(int(s.x / 60.0) + 2):
		draw_rect(Rect2(float(i) * 60.0 - off, gy + (s.y - gy) * 0.55, 30, 3), Color(0.5, 0.7, 1.0, 0.25))


func _planes(s: Vector2) -> void:
	# قاذفة كبيرة بطيئة عالية
	var bx: float = fposmod(t * 38.0, s.x + 600.0) - 300.0
	_bomber(Vector2(bx, s.y * 0.13 + sin(t * 0.7) * 6.0), 1.5, 1.0)
	# مقاتلات بسرعات واتجاهات مختلفة
	for k in range(3):
		var sp: float = 150.0 + 55.0 * float(k)
		var dir: float = 1.0 if k % 2 == 0 else -1.0
		var span: float = s.x + 500.0
		var px: float = fposmod(t * sp + float(k) * 430.0, span) - 250.0
		if dir < 0.0:
			px = s.x - px
		var py: float = s.y * (0.2 + 0.09 * float(k)) + sin(t * 1.3 + float(k) * 2.0) * 9.0
		_jet_shape(Vector2(px, py), 1.0 - 0.1 * float(k), dir, t * (1.0 + float(k)))
	# مروحيتان
	for k in range(2):
		var dir2: float = -1.0 if k == 0 else 1.0
		var span2: float = s.x + 400.0
		var hx: float = fposmod(t * (62.0 + 18.0 * float(k)) + float(k) * 600.0, span2) - 200.0
		if dir2 < 0.0:
			hx = s.x - hx
		var hy: float = s.y * (0.5 + 0.06 * float(k)) + sin(t * 1.8 + float(k)) * 7.0
		_heli_shape(Vector2(hx, hy), 0.95, dir2)


func _jet_shape(o: Vector2, sc: float, dir: float, tm: float) -> void:
	# ذيل دخان خلف المقاتلة
	for i in range(14):
		var f: float = float(i) / 14.0
		draw_circle(o + Vector2(-dir * (30.0 + f * 190.0) * sc, sin(tm * 3.0 + f * 6.0) * 2.0), (4.0 + f * 9.0) * sc, Color(0.9, 0.95, 1.0, 0.2 * (1.0 - f)))
	var body: Array = [Vector2(40, 0), Vector2(16, -5), Vector2(-26, -4), Vector2(-34, 0), Vector2(-26, 4), Vector2(16, 5)]
	draw_colored_polygon(_tf(body, o, sc, dir), Color(0.62, 0.7, 0.8))
	var wing: Array = [Vector2(10, 2), Vector2(-14, 2), Vector2(-30, 22), Vector2(-14, 22)]
	draw_colored_polygon(_tf(wing, o, sc, dir), Color(0.42, 0.5, 0.62))
	var tail: Array = [Vector2(-22, -3), Vector2(-34, -17), Vector2(-28, -3)]
	draw_colored_polygon(_tf(tail, o, sc, dir), Color(0.5, 0.58, 0.7))
	draw_colored_polygon(_tf([Vector2(14, -4), Vector2(2, -9), Vector2(-4, -4)], o, sc, dir), Color(0.4, 0.8, 1.0, 0.9))
	var fl: float = 14.0 + 7.0 * sin(tm * 30.0)
	draw_colored_polygon(_tf([Vector2(-34, -2), Vector2(-34 - fl, 0), Vector2(-34, 2)], o, sc, dir), Color(1.0, 0.7, 0.25, 0.95))


func _bomber(o: Vector2, sc: float, dir: float) -> void:
	for i in range(10):
		var f: float = float(i) / 10.0
		draw_circle(o + Vector2(-dir * (60.0 + f * 220.0) * sc, 0), (5.0 + f * 12.0) * sc, Color(0.85, 0.92, 1.0, 0.12 * (1.0 - f)))
	var wing: Array = [Vector2(30, 0), Vector2(-10, -3), Vector2(-60, -2), Vector2(-60, 2), Vector2(-10, 3)]
	draw_colored_polygon(_tf(wing, o, sc, dir), Color(0.3, 0.36, 0.5))
	var span: Array = [Vector2(10, 0), Vector2(-36, 26), Vector2(-52, 26), Vector2(-30, 0), Vector2(-52, -26), Vector2(-36, -26)]
	draw_colored_polygon(_tf(span, o, sc, dir), Color(0.24, 0.3, 0.44, 0.96))
	draw_circle(o + Vector2(10.0 * dir, -1) * sc, 3.0 * sc, Color(0.5, 0.85, 1.0, 0.9))


func _heli_shape(o: Vector2, sc: float, dir: float) -> void:
	draw_colored_polygon(_tf([Vector2(24, 0), Vector2(14, -12), Vector2(-8, -12), Vector2(-14, -4), Vector2(-12, 8), Vector2(10, 10)], o, sc, dir), Color(0.4, 0.5, 0.36))
	draw_colored_polygon(_tf([Vector2(-10, -6), Vector2(-52, -4), Vector2(-52, -1), Vector2(-10, 2)], o, sc, dir), Color(0.34, 0.44, 0.3))
	draw_colored_polygon(_tf([Vector2(-48, -4), Vector2(-56, -16), Vector2(-50, -16), Vector2(-44, -4)], o, sc, dir), Color(0.3, 0.4, 0.28))
	draw_colored_polygon(_tf([Vector2(22, -2), Vector2(14, -10), Vector2(6, -10), Vector2(8, -1)], o, sc, dir), Color(0.5, 0.8, 1.0, 0.85))
	draw_line(o + Vector2(0, -14) * sc, o + Vector2(0, -19) * sc, Color(0.2, 0.25, 0.2), 3.0)
	var rl: float = (52.0 + 8.0 * sin(t * 40.0)) * sc
	draw_line(o + Vector2(-rl, -19.0 * sc), o + Vector2(rl, -19.0 * sc), Color(0.85, 0.92, 1.0, 0.55), 3.0)
	var tr: float = 9.0 * sc * sin(t * 36.0)
	draw_line(o + Vector2(-54.0 * dir * sc, -11.0 * sc - tr), o + Vector2(-54.0 * dir * sc, -11.0 * sc + tr), Color(0.85, 0.92, 1.0, 0.6), 2.0)


func _tanks(s: Vector2) -> void:
	var gy: float = s.y * 0.86
	# صف بعيد أصغر ثم صف قريب
	for k in range(5):
		var near: bool = k >= 2
		var sc: float = 1.15 if near else 0.7
		var y: float = gy + (s.y - gy) * (0.62 if near else 0.2)
		var sp: float = (46.0 if near else 30.0) + float(k) * 4.0
		var dir: float = 1.0 if k % 2 == 0 else -1.0
		var span: float = s.x + 400.0
		var x: float = fposmod(t * sp + float(k) * 310.0, span) - 200.0
		if dir < 0.0:
			x = s.x - x
		_tank_shape(Vector2(x, y), sc, dir, float(k))


func _tank_shape(o: Vector2, sc: float, dir: float, seed_v: float) -> void:
	# غبار خلف الدبابة
	for i in range(7):
		var f: float = float(i) / 7.0
		draw_circle(o + Vector2(-dir * (34.0 + f * 70.0) * sc, -4.0 * sc - f * 10.0), (5.0 + f * 9.0) * sc, Color(0.7, 0.82, 1.0, 0.14 * (1.0 - f)))
	var bob: float = sin(t * 9.0 + seed_v) * 0.8 * sc
	var oo: Vector2 = o + Vector2(0, bob)
	# جنزير وعجلات
	draw_colored_polygon(_tf([Vector2(-34, 0), Vector2(34, 0), Vector2(30, 12), Vector2(-30, 12)], oo, sc, dir), Color(0.08, 0.12, 0.2))
	for i in range(6):
		draw_circle(oo + Vector2((-26.0 + float(i) * 10.4) * dir, 7.0) * sc, 4.6 * sc, Color(0.22, 0.3, 0.44))
		draw_circle(oo + Vector2((-26.0 + float(i) * 10.4) * dir, 7.0) * sc, 1.8 * sc, Color(0.5, 0.62, 0.8))
	# الهيكل والبرج والمدفع
	draw_colored_polygon(_tf([Vector2(-32, 0), Vector2(32, 0), Vector2(26, -12), Vector2(-28, -12)], oo, sc, dir), Color(0.34, 0.46, 0.42))
	draw_colored_polygon(_tf([Vector2(-14, -12), Vector2(14, -12), Vector2(10, -24), Vector2(-10, -24)], oo, sc, dir), Color(0.4, 0.54, 0.48))
	var rec: float = 0.0
	var cyc: float = fposmod(t * 0.35 + seed_v * 0.37, 1.0)
	if cyc < 0.06:
		rec = 5.0
		draw_circle(oo + Vector2((60.0) * dir, -19.0) * sc, 11.0 * sc, Color(1.0, 0.85, 0.4, 0.8))
	draw_colored_polygon(_tf([Vector2(10 - rec, -22), Vector2(58 - rec, -20), Vector2(58 - rec, -17), Vector2(10 - rec, -16)], oo, sc, dir), Color(0.28, 0.38, 0.36))
	draw_line(oo + Vector2(-32.0 * dir, -12) * sc, oo + Vector2(32.0 * dir, -12) * sc, Color(0.7, 0.88, 0.8, 0.5), 1.5)


func _vignette(s: Vector2) -> void:
	var dark := Color(0.0, 0.03, 0.1, 0.62)
	var clear := Color(0.0, 0.03, 0.1, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.2), Vector2(0, s.y * 0.2)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.78), Vector2(s.x, s.y * 0.78), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([clear, clear, dark, dark]))
