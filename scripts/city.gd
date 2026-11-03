class_name City
extends RefCounted
## مدينة عراقية متكاملة تغطي الخريطة: شوارع وكتل سكنية، بيوت وعمارات وأبراج وناطحات سحاب، حدائق، ومعالم من الحضارة العراقية
## (زقورة أور، ملوية سامراء، بوابة عشتار، المنارة الحدباء، طاق كسرى، قبة ذهبية، قلعة أربيل، أسد بابل).
## plan() تُخطّط المدينة قبل بناء سطح الأرض (لتلوين الحدائق)، وspawn() تُنشئ المجسمات وتجعلها عوائق.
## ثوابت الشوارع تطابق shaders/terrain.gdshader: دورة 26 خلية، شارع بعرض 4 خلايا.

const PER := 26
const ST := 4
const BASE_EXCL := 38.0
const MINE_EXCL := 13.0

# [النوع، x، y (بإحداثيات الخريطة 256)، العرض بالخلايا، العمق بالخلايا، التناظر: x أو y أو xy أو p (نقطي)]
const LANDMARKS := [
	["ziggurat", 66, 128, 9, 9, "x"],
	["ishtar", 128, 66, 10, 4, "y"],
	["ctesiphon", 128, 100, 12, 6, "y"],
	["dome", 100, 112, 10, 10, "p"],
	["citadel", 156, 112, 12, 12, "p"],
	["malwiya", 88, 62, 4, 4, "xy"],
	["hadba", 54, 92, 3, 3, "xy"],
	["lion", 116, 40, 4, 4, "xy"],
]


# ---------------------------------------------------------------- التخطيط
static func plan(t, seed_val: int) -> void:
	var n: int = t.n
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 4242
	var sat: PackedInt32Array = _water_sat(t)
	var occ := PackedByteArray()
	occ.resize(n * n)
	occ.fill(0)
	var out: Array = []
	t.park_mask = PackedByteArray()
	t.park_mask.resize(n * n)
	t.park_mask.fill(0)
	for lm in LANDMARKS:
		var lw: int = int(lm[3])
		var lh: int = int(lm[4])
		for pos in _mirrors(lm):
			var c: Vector2i = _find_spot(t, sat, occ, pos, lw, lh)
			if c.x < 0:
				continue
			_mark(occ, n, c.x, c.y, lw, lh)
			out.append({"k": str(lm[0]), "x": c.x, "y": c.y, "w": lw, "h": lh, "lm": true})
	var nz := FastNoiseLite.new()
	nz.seed = seed_val + 313
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.014
	for by in range(0, n - PER, PER):
		for bx in range(0, n - PER, PER):
			_block(t, sat, occ, rng, nz, out, bx + ST, by + ST, PER - ST)
	t.city_plan = out


static func _mirrors(lm: Array) -> Array:
	var K: float = Data.K
	var x: float = float(lm[1]) * K
	var y: float = float(lm[2]) * K
	var mx: float = float(Data.MAP - 1) - x
	var my: float = float(Data.MAP - 1) - y
	match str(lm[5]):
		"x":
			return [Vector2(x, y), Vector2(mx, y)]
		"y":
			return [Vector2(x, y), Vector2(x, my)]
		"p":
			return [Vector2(x, y), Vector2(mx, my)]
		"xy":
			return [Vector2(x, y), Vector2(mx, y), Vector2(x, my), Vector2(mx, my)]
	return [Vector2(x, y)]


static func _water_sat(t) -> PackedInt32Array:
	var n: int = t.n
	var w: int = n + 1
	var s := PackedInt32Array()
	s.resize(w * w)
	s.fill(0)
	for y in range(1, w):
		var row := 0
		for x in range(1, w):
			var tp: int = t.types[(y - 1) * n + (x - 1)]
			if tp == 3 or tp == 4:
				row += 1
			s[y * w + x] = s[(y - 1) * w + x] + row
	return s


static func _water_in(s: PackedInt32Array, n: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var w: int = n + 1
	var ax: int = clampi(x0, 0, n)
	var bx: int = clampi(x1, 0, n)
	var ay: int = clampi(y0, 0, n)
	var by: int = clampi(y1, 0, n)
	return s[by * w + bx] - s[ay * w + bx] - s[by * w + ax] + s[ay * w + ax]


static func _mark(occ: PackedByteArray, n: int, x: int, y: int, w: int, h: int) -> void:
	for cy in range(y, y + h):
		for cx in range(x, x + w):
			occ[cy * n + cx] = 1


# هل يصلح هذا المستطيل لمبنى؟ (يابسة، بعيد عن الماء والقواعد والمناجم والطرق، وفارغ)
static func _ok(t, sat: PackedInt32Array, occ: PackedByteArray, x: int, y: int, w: int, h: int, margin: int) -> bool:
	var n: int = t.n
	if x - margin < 4 or y - margin < 4 or x + w + margin > n - 4 or y + h + margin > n - 4:
		return false
	if _water_in(sat, n, x - 3, y - 3, x + w + 3, y + h + 3) > 0:
		return false
	for cy in range(y - margin, y + h + margin):
		for cx in range(x - margin, x + w + margin):
			if occ[cy * n + cx] != 0:
				return false
	for cy in range(y, y + h):
		for cx in range(x, x + w):
			var i: int = cy * n + cx
			var tp: int = t.types[i]
			if tp != 0 and tp != 1:
				return false
			if t.road_w[i] > 0.03 or t.build_block[i] != 0:
				return false
	var mxc: float = float(x) + float(w) * 0.5
	var myc: float = float(y) + float(h) * 0.5
	for b in Data.BASES:
		if absf(mxc - float(b.x + 1)) < BASE_EXCL and absf(myc - float(b.y + 1)) < BASE_EXCL:
			return false
	for m in Data.MINES:
		if absf(mxc - float(m.x)) < MINE_EXCL + float(w) * 0.5 and absf(myc - float(m.y)) < MINE_EXCL + float(h) * 0.5:
			return false
	return true


# أقرب موضع صالح حول الإحداثية المطلوبة (بحلقات متسعة)
static func _find_spot(t, sat: PackedInt32Array, occ: PackedByteArray, pos: Vector2, w: int, h: int) -> Vector2i:
	var cx: int = int(pos.x - float(w) * 0.5)
	var cy: int = int(pos.y - float(h) * 0.5)
	for r in range(0, 34, 2):
		for dy in range(-r, r + 1, 2):
			for dx in range(-r, r + 1, 2):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if _ok(t, sat, occ, cx + dx, cy + dy, w, h, 2):
					return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)


static func _try(t, sat: PackedInt32Array, occ: PackedByteArray, rng: RandomNumberGenerator, out: Array, x0: int, y0: int, sz: int, kind: String, w: int, h: int) -> bool:
	for _k in range(14):
		var x: int = x0 + rng.randi_range(0, sz - w)
		var y: int = y0 + rng.randi_range(0, sz - h)
		if _ok(t, sat, occ, x, y, w, h, 1):
			_mark(occ, int(t.n), x, y, w, h)
			out.append({"k": kind, "x": x, "y": y, "w": w, "h": h, "ht": _height(rng, kind), "col": _color(rng, kind)})
			return true
	return false


static func _height(rng: RandomNumberGenerator, kind: String) -> float:
	match kind:
		"house":
			return rng.randf_range(3.4, 5.4) if rng.randf() > 0.2 else rng.randf_range(6.2, 7.6)
		"apt":
			return rng.randf_range(8.0, 12.5)
		"tower":
			return rng.randf_range(15.0, 22.0)
	return rng.randf_range(26.0, 36.0)


# لون الجدار، وقيمته الشفافة تحدد نمط النوافذ في الشيدر (بيت، عمارة، برج زجاجي)
static func _color(rng: RandomNumberGenerator, kind: String) -> Color:
	match kind:
		"house":
			var hp: Array = [Color(0.86, 0.78, 0.64, 0.2), Color(0.93, 0.89, 0.8, 0.2), Color(0.78, 0.62, 0.46, 0.2), Color(0.88, 0.84, 0.76, 0.2), Color(0.72, 0.6, 0.5, 0.2), Color(0.95, 0.93, 0.88, 0.2)]
			return hp[rng.randi() % hp.size()]
		"apt":
			var ap: Array = [Color(0.82, 0.8, 0.76, 0.55), Color(0.74, 0.72, 0.7, 0.55), Color(0.88, 0.82, 0.7, 0.55), Color(0.7, 0.74, 0.78, 0.55), Color(0.8, 0.66, 0.54, 0.55)]
			return ap[rng.randi() % ap.size()]
		"tower":
			var tp: Array = [Color(0.45, 0.56, 0.68, 1.0), Color(0.52, 0.6, 0.66, 1.0), Color(0.4, 0.5, 0.56, 1.0), Color(0.6, 0.64, 0.7, 1.0)]
			return tp[rng.randi() % tp.size()]
	var sp: Array = [Color(0.3, 0.42, 0.58, 1.0), Color(0.38, 0.5, 0.62, 1.0), Color(0.25, 0.36, 0.5, 1.0), Color(0.55, 0.6, 0.64, 1.0)]
	return sp[rng.randi() % sp.size()]


static func _block(t, sat: PackedInt32Array, occ: PackedByteArray, rng: RandomNumberGenerator, nz: FastNoiseLite, out: Array, x0: int, y0: int, sz: int) -> void:
	var n: int = t.n
	var cx: float = float(x0) + float(sz) * 0.5
	var cy: float = float(y0) + float(sz) * 0.5
	var half: float = float(n) * 0.5
	var dcen: float = Vector2(cx - half, cy - half).length() / half
	var d: float = clampf(nz.get_noise_2d(cx, cy) * 0.5 + 0.5 + (0.7 - dcen) * 0.35, 0.0, 1.0)
	if d > 0.74:
		_try(t, sat, occ, rng, out, x0, y0, sz, "sky", 6, 6)
		for _i in range(rng.randi_range(1, 3)):
			_try(t, sat, occ, rng, out, x0, y0, sz, "tower", 5, 5)
		for _i in range(rng.randi_range(0, 2)):
			_try(t, sat, occ, rng, out, x0, y0, sz, "apt", 4, 4)
	elif d > 0.5:
		for _i in range(rng.randi_range(3, 5)):
			_try(t, sat, occ, rng, out, x0, y0, sz, "apt", 4, 4)
		for _i in range(rng.randi_range(0, 2)):
			_try(t, sat, occ, rng, out, x0, y0, sz, "house", 3, 3)
	elif d > 0.28:
		for _i in range(rng.randi_range(5, 8)):
			_try(t, sat, occ, rng, out, x0, y0, sz, "house", 3, 3 if rng.randf() > 0.4 else 4)
	elif rng.randf() < 0.6:
		_park(t, sat, occ, x0, y0, sz)


# حديقة: تُلوَّن خضراء ويكثر فيها الشجر (النخيل خصوصاً)
static func _park(t, sat: PackedInt32Array, occ: PackedByteArray, x0: int, y0: int, sz: int) -> void:
	if not _ok(t, sat, occ, x0 + 1, y0 + 1, sz - 2, sz - 2, 0):
		return
	var n: int = t.n
	for cy in range(y0 + 1, y0 + sz - 1):
		for cx in range(x0 + 1, x0 + sz - 1):
			t.types[cy * n + cx] = 1
			t.park_mask[cy * n + cx] = 1
			occ[cy * n + cx] = 2


# ---------------------------------------------------------------- الإنشاء
static func spawn(t) -> void:
	var n: int = t.n
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/city.gdshader")
	t.city_mat = mat
	var bodies := {}
	var roofs := {}
	var masts := {}
	for e in t.city_plan:
		var x: int = int(e["x"])
		var y: int = int(e["y"])
		var w: int = int(e["w"])
		var h: int = int(e["h"])
		var wx: float = (float(x) + float(w) * 0.5) * Data.CELL
		var wz: float = (float(y) + float(h) * 0.5) * Data.CELL
		var fp: Vector2 = t.footprint(Vector2i(x, y), maxi(w, h))
		if e.has("lm"):
			var root := Node3D.new()
			root.name = "LM_" + str(e["k"])
			root.position = Vector3(wx, fp.x - 0.3, wz)
			_build_landmark(str(e["k"]), root)
			Models._bake(root)
			t.add_child(root)
			_solid(t, x, y, w, h, 2)
			continue
		var base_y: float = fp.x - 0.6
		var top: float = fp.y + float(e["ht"])
		var total: float = top - base_y
		var bw: float = float(w) * Data.CELL - 0.7
		var bd: float = float(h) * Data.CELL - 0.7
		var col: Color = e["col"]
		t._add_inst(bodies, wx, wz, Transform3D(Basis.from_scale(Vector3(bw, total, bd)), Vector3(wx, base_y + total * 0.5, wz)), col)
		t._add_inst(roofs, wx, wz, Transform3D(Basis.from_scale(Vector3(bw + 0.5, 0.55, bd + 0.5)), Vector3(wx, top + 0.1, wz)), Color(0.4, 0.39, 0.37, 0.0))
		if str(e["k"]) == "tower" or str(e["k"]) == "sky":
			t._add_inst(masts, wx, wz, Transform3D(Basis.from_scale(Vector3(0.3, 9.0, 0.3)), Vector3(wx, top + 4.5, wz)), Color(0.75, 0.75, 0.78))
		_solid(t, x, y, w, h, 1)
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	t._flush(bodies, box, mat, 420.0)
	t._flush(roofs, box, mat, 420.0)
	t._flush(masts, box, t._veg_mat(false), 300.0, false)


# خلايا المبنى عائق صلب (نوع 6) ويُمنع البناء حولها بهامش
static func _solid(t, x: int, y: int, w: int, h: int, ring: int) -> void:
	var n: int = t.n
	for cy in range(y - ring, y + h + ring):
		for cx in range(x - ring, x + w + ring):
			if cx < 0 or cy < 0 or cx >= n or cy >= n:
				continue
			var i: int = cy * n + cx
			t.build_block[i] = 1
			if cx >= x and cx < x + w and cy >= y and cy < y + h:
				t.types[i] = 6


static func _build_landmark(kind: String, root: Node3D) -> void:
	match kind:
		"ziggurat":
			_ziggurat(root)
		"ishtar":
			_ishtar(root)
		"ctesiphon":
			_ctesiphon(root)
		"dome":
			_dome(root)
		"citadel":
			_citadel(root)
		"malwiya":
			_malwiya(root)
		"hadba":
			_hadba(root)
		"lion":
			_lion(root)


# زقورة أور: ثلاث مصاطب متدرجة من الطوب اللبن ومعبد علوي وسلالم أمامية
static func _ziggurat(root: Node3D) -> void:
	var mud: Color = Models.BRICK.lightened(0.1)
	Models.box(root, Vector3(15.6, 2.8, 15.6), Vector3(0, 1.0, 0), mud, 0.95)
	Models.box(root, Vector3(11.4, 2.8, 11.4), Vector3(0, 3.8, 0), mud.lightened(0.05), 0.95)
	Models.box(root, Vector3(7.4, 2.8, 7.4), Vector3(0, 6.6, 0), mud.lightened(0.1), 0.95)
	Models.box(root, Vector3(4.4, 2.6, 4.4), Vector3(0, 9.3, 0), Models.SAND, 0.9)
	Models.box(root, Vector3(4.9, 0.4, 4.9), Vector3(0, 10.8, 0), Models.GOLD.darkened(0.1), 0.5, 0.4)
	for k in range(3):
		var sz: float = 15.7 - float(k) * 4.2
		Models.box(root, Vector3(sz, 0.3, sz), Vector3(0, 0.6 + float(k) * 2.8, 0), mud.darkened(0.12), 0.95)
	Models.box(root, Vector3(2.8, 0.4, 3.9), Vector3(0, 1.2, 8.9), Models.SAND.lightened(0.05), 0.9, 0.0, Vector3(deg_to_rad(36.0), 0, 0))
	Models.box(root, Vector3(2.4, 0.4, 3.0), Vector3(0, 3.9, 5.9), Models.SAND.lightened(0.05), 0.9, 0.0, Vector3(deg_to_rad(36.0), 0, 0))
	Models.box(root, Vector3(2.0, 0.4, 2.6), Vector3(0, 6.6, 3.6), Models.SAND.lightened(0.05), 0.9, 0.0, Vector3(deg_to_rad(36.0), 0, 0))


# ملوية سامراء: برج حلزوني يتناقص قطره صعوداً ومنحدر لولبي ظاهر
static func _malwiya(root: Node3D) -> void:
	var c: Color = Models.SAND.darkened(0.05)
	Models.box(root, Vector3(7.4, 1.0, 7.4), Vector3(0, 0.0, 0), Models.STONE, 0.95)
	Models.cyl(root, 3.3, 3.5, 3.2, Vector3(0, 2.2, 0), c, 0.95)
	var y := 3.8
	var r := 3.2
	for i in range(8):
		var r2: float = r - 0.3
		Models.cyl(root, r2, r, 1.6, Vector3(0, y + 0.8, 0), c.lightened(0.02 * float(i)), 0.95)
		y += 1.6
		r = r2
	for i in range(46):
		var a: float = float(i) * 0.42
		var rr: float = lerpf(3.5, 1.5, float(i) / 46.0)
		var yy: float = 1.2 + float(i) * 0.33
		Models.box(root, Vector3(1.1, 0.3, 0.8), Vector3(cos(a) * rr, yy, sin(a) * rr), c.darkened(0.15), 0.95, 0.0, Vector3(0, -a, 0))
	Models.cyl(root, 0.9, 1.1, 1.4, Vector3(0, 17.6, 0), c, 0.9)
	Models.sph(root, 1.0, Vector3(0, 18.8, 0), c.lightened(0.1), Vector3(1, 0.8, 1), 0.8)


# بوابة عشتار: برجان بالطابوق الأزرق المزجّج وزخارف الثيران والتنانين الذهبية وباب خشبي مقوّس
static func _ishtar(root: Node3D) -> void:
	var blue := Color(0.1, 0.27, 0.58)
	var blue2 := Color(0.14, 0.34, 0.68)
	var cream := Color(0.88, 0.8, 0.6)
	for sx in [-1, 1]:
		var cx: float = 6.9 * float(sx)
		Models.box(root, Vector3(5.6, 11.0, 6.0), Vector3(cx, 5.0, 0), blue, 0.4, 0.15)
		Models.box(root, Vector3(5.9, 0.5, 6.3), Vector3(cx, 10.7, 0), cream, 0.7)
		for k in range(3):
			for sz in [-1, 1]:
				Models.box(root, Vector3(1.0, 1.0, 1.0), Vector3(cx + (float(k) - 1.0) * 1.9, 11.4, 2.6 * float(sz)), cream, 0.7)
		for r in range(3):
			for c in range(2):
				for sz in [-1, 1]:
					Models.box(root, Vector3(1.5, 1.0, 0.15), Vector3(cx + (float(c) - 0.5) * 2.5, 2.3 + float(r) * 2.6, 3.08 * float(sz)), Models.GOLD, 0.4, 0.5)
	Models.box(root, Vector3(8.4, 4.0, 6.0), Vector3(0, 8.9, 0), blue2, 0.4, 0.15)
	Models.box(root, Vector3(8.7, 0.5, 6.3), Vector3(0, 11.0, 0), cream, 0.7)
	for k in range(5):
		Models.box(root, Vector3(1.3, 0.9, 0.15), Vector3((float(k) - 2.0) * 1.7, 9.0, 3.08), Models.GOLD, 0.4, 0.5)
		Models.box(root, Vector3(1.3, 0.9, 0.15), Vector3((float(k) - 2.0) * 1.7, 9.0, -3.08), Models.GOLD, 0.4, 0.5)
	Models.box(root, Vector3(8.0, 6.8, 0.6), Vector3(0, 3.4, 0), Models.WOOD, 0.8)
	for k in range(4):
		Models.box(root, Vector3(8.1, 0.15, 0.7), Vector3(0, 1.0 + float(k) * 1.6, 0), Models.IRON, 0.5, 0.4)


# المنارة الحدباء: منارة مائلة بأحزمة زخرفية وقمة ذهبية
static func _hadba(root: Node3D) -> void:
	var br: Color = Models.SAND.lightened(0.06)
	Models.box(root, Vector3(5.6, 0.9, 5.6), Vector3(0, 0.0, 0), Models.STONE, 0.95)
	Models.cyl(root, 1.2, 1.5, 1.4, Vector3(0, 1.1, 0), br, 0.9)
	var y := 1.8
	for i in range(11):
		var off: float = 0.016 * float(i * i)
		var r0: float = lerpf(1.15, 0.7, float(i) / 11.0)
		var r1: float = lerpf(1.15, 0.7, float(i + 1) / 11.0)
		Models.cyl(root, r1, r0, 1.5, Vector3(off, y + 0.75, 0), br if i % 2 == 0 else br.darkened(0.07), 0.9)
		Models.cyl(root, r0 + 0.08, r0 + 0.08, 0.12, Vector3(off, y + 0.05, 0), Models.BRICK.lightened(0.1), 0.9)
		y += 1.5
	var offt: float = 0.016 * 121.0
	Models.cyl(root, 0.55, 0.7, 1.0, Vector3(offt, y + 0.5, 0), br.lightened(0.06), 0.9)
	Models.sph(root, 0.6, Vector3(offt, y + 1.3, 0), Models.GOLD, Vector3(1, 0.9, 1), 0.3, 0.6)
	Models.cyl(root, 0.03, 0.05, 1.0, Vector3(offt, y + 2.2, 0), Models.GOLD, 0.3, 0.6)


# طاق كسرى (طيسفون): واجهة طوبية ضخمة بقوس مكافئ شاهق
static func _ctesiphon(root: Node3D) -> void:
	var br: Color = Models.BRICK.lightened(0.12)
	var depth := 7.0
	for hh in range(13):
		var half: float = 5.4 * sqrt(maxf(0.0, 1.0 - float(hh) / 12.2))
		var wlen: float = 11.4 - half
		if wlen > 0.1:
			for sx in [-1, 1]:
				Models.box(root, Vector3(wlen, 1.0, depth), Vector3(float(sx) * (half + wlen * 0.5), float(hh) + 0.5, 0), br.darkened(0.04 * float(hh % 2)), 0.95)
	Models.box(root, Vector3(22.8, 1.2, depth), Vector3(0, 13.0, 0), br, 0.95)
	for r in range(2):
		for k in range(3):
			for sx in [-1, 1]:
				Models.box(root, Vector3(1.0, 2.0, 0.2), Vector3(float(sx) * (7.4 + float(k) * 1.5), 3.0 + float(r) * 4.2, 3.55), Models.SAND_D, 0.95)
	Models.box(root, Vector3(10.0, 0.5, 6.4), Vector3(0, 0.0, 0), Models.STONE, 0.95)


# قبة ذهبية بأربع مآذن وصحن واسع (طراز العتبات المقدسة)
static func _dome(root: Node3D) -> void:
	var white := Color(0.9, 0.88, 0.82)
	var teal := Color(0.1, 0.5, 0.55)
	var gold: Color = Models.GOLD
	Models.box(root, Vector3(19.0, 0.6, 19.0), Vector3(0, -0.1, 0), Models.STONE.lightened(0.1), 0.9)
	for s in [-1, 1]:
		Models.box(root, Vector3(19.0, 1.6, 0.6), Vector3(0, 1.0, 9.0 * float(s)), white, 0.9)
		Models.box(root, Vector3(0.6, 1.6, 19.0), Vector3(9.0 * float(s), 1.0, 0), white, 0.9)
	Models.box(root, Vector3(8.4, 6.0, 8.4), Vector3(0, 3.5, 0), white, 0.8)
	Models.box(root, Vector3(8.8, 0.5, 8.8), Vector3(0, 6.7, 0), teal, 0.5, 0.2)
	Models.cyl(root, 3.6, 3.6, 2.8, Vector3(0, 8.3, 0), teal, 0.5, 0.2)
	Models.sph(root, 3.6, Vector3(0, 9.7, 0), gold, Vector3(1.0, 1.0, 1.0), 0.25, 0.7)
	Models.cyl(root, 0.05, 0.12, 2.2, Vector3(0, 14.4, 0), gold, 0.3, 0.6)
	Models.box(root, Vector3(4.2, 3.6, 0.5), Vector3(0, 2.6, 4.45), teal, 0.5, 0.2)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var px: float = 8.2 * float(sx)
			var pz: float = 8.2 * float(sz)
			Models.cyl(root, 0.5, 0.65, 10.0, Vector3(px, 5.5, pz), white, 0.8)
			Models.cyl(root, 0.85, 0.85, 0.35, Vector3(px, 8.6, pz), gold, 0.4, 0.5)
			Models.cyl(root, 0.4, 0.5, 1.2, Vector3(px, 10.6, pz), teal, 0.5, 0.2)
			Models.sph(root, 0.45, Vector3(px, 11.5, pz), gold, Vector3(1, 1.1, 1), 0.3, 0.6)


# قلعة أربيل: تلّ مرتفع بسور دائري وبيوت داخلية وبرج مركزي
static func _citadel(root: Node3D) -> void:
	var earth: Color = Models.SAND.darkened(0.08)
	Models.cyl(root, 10.4, 11.4, 4.6, Vector3(0, 1.6, 0), earth, 0.95)
	for k in range(30):
		var a: float = float(k) * TAU / 30.0
		Models.box(root, Vector3(2.4, 2.0, 0.9), Vector3(cos(a) * 10.0, 4.9, sin(a) * 10.0), Models.SAND.lightened(0.05), 0.95, 0.0, Vector3(0, -a + PI / 2.0, 0))
		if k % 2 == 0:
			Models.box(root, Vector3(1.0, 0.7, 1.0), Vector3(cos(a) * 10.0, 6.2, sin(a) * 10.0), Models.SAND.lightened(0.1), 0.95)
	for k in range(9):
		var a2: float = float(k) * 0.7 + 0.3
		var rr: float = 3.6 + float(k % 3) * 2.2
		var hh: float = 2.0 + float(k % 3) * 0.6
		Models.box(root, Vector3(2.6, hh, 2.4), Vector3(cos(a2) * rr, 3.9 + hh * 0.5, sin(a2) * rr), Models.CANVAS if k % 2 == 0 else Models.SAND, 0.9, 0.0, Vector3(0, a2, 0))
	Models.box(root, Vector3(3.4, 5.0, 3.4), Vector3(0, 6.4, 0), Models.SAND.lightened(0.1), 0.9)
	Models.box(root, Vector3(3.8, 0.5, 3.8), Vector3(0, 9.1, 0), Models.GOLD.darkened(0.1), 0.5, 0.4)


# أسد بابل: تمثال بازلتي على قاعدة حجرية
static func _lion(root: Node3D) -> void:
	var st := Color(0.26, 0.25, 0.23)
	Models.box(root, Vector3(7.2, 1.6, 4.0), Vector3(0, 0.3, 0), Models.STONE, 0.9)
	Models.box(root, Vector3(4.6, 1.7, 1.7), Vector3(0, 2.0, 0), st, 0.8)
	Models.sph(root, 1.0, Vector3(2.4, 2.9, 0), st, Vector3.ONE, 0.8)
	Models.sph(root, 1.25, Vector3(1.6, 2.7, 0), st.lightened(0.05), Vector3(0.8, 1.0, 1.1), 0.8)
	for dx in [-1.6, 1.6]:
		for dz in [-0.55, 0.55]:
			Models.box(root, Vector3(0.5, 1.4, 0.5), Vector3(float(dx), 1.1, float(dz)), st, 0.8)
	Models.limb(root, Vector3(-2.3, 2.3, 0), Vector3(-3.3, 3.3, 0), 0.12, 0.1, st, 0.8, 0.0)
