class_name Ai
extends Node
## ذكاء جيش الحاسوب (عدو أو حليف): يجمع الذهب بالشاحنات، يبني مقرات وقواعد، ويرسل موجات هجوم، ويدافع عن فريقه.
## يوجد جسم واحد لكل جيش حاسوب. slot = رقم الجيش (1..3).

var g: Main
var slot := 1
var t := 0.0
var bt := 10.0
var wt := 0.0
var dt := 0.0
var next_raid := 0.0
var next_full := 0.0
var next_check := 0.0
var raids_done := 0
var last_ang := -10.0


func reset() -> void:
	var cf0: Dictionary = Data.DIFF[g.diff]
	# لا موعد ثابت: أول مفرزة بعد راحة عشوائية، والهجوم الشامل لا يأتي قبل عدة مفارز
	next_raid = float(cf0["gap"]) * randf_range(1.2, 2.2)
	next_full = float(cf0["full_gap"]) * randf_range(1.6, 2.6)
	next_check = 0.0
	raids_done = 0
	last_ang = -10.0
	t = randf() * 3.0
	bt = 10.0
	wt = randf() * 2.0


func tick(delta: float) -> void:
	var cf: Dictionary = Data.DIFF[g.diff]
	t += delta
	if t >= float(cf["every"]):
		t = 0.0
		_train(cf)
	bt += delta
	if bt >= float(cf["bt"]):
		bt = 0.0
		_build(cf)
	wt += delta
	if wt >= 3.0:
		wt = 0.0
		_attack(cf)
	dt += delta
	if dt >= 2.0:
		dt = 0.0
		_defend()


func _def_count(mine_b: Array) -> int:
	return mine_b.filter(func(b): return str(b.def.get("cat", "")) == "def").size()


func _mine_list(ty: String) -> Array:
	return g.blds.filter(func(b): return b.team == slot and not b.dead and b.con >= 1.0 and b.type == ty)


func _pick_vehicle(tech: int) -> String:
	var pool := ["lt", "tank"]
	if tech >= 1:
		pool = ["lt", "tank", "tank", "art", "aa"]
	if tech >= 2:
		pool = ["tank", "heavy", "heavy", "art", "aa", "lt"]
	return pool.pick_random()


func _pick_inf(tech: int) -> String:
	if tech == 0:
		return ["inf", "inf", "inf", "mg"].pick_random()
	if tech == 1:
		return ["inf", "inf", "mg", "rpg"].pick_random()
	return ["inf", "mg", "rpg", "rpg", "sniper", "cmd"].pick_random()


func _train(cf: Dictionary) -> void:
	var tech: int = int(cf["tech"])
	var deps: Array = _mine_list("dep")
	var trucks: int = g.units.filter(func(u): return u.team == slot and u.is_truck and not u.dead).size()
	var queued := 0
	for d in deps:
		queued += d.q.size()
	var gold: float = g.gold[slot]
	if not deps.is_empty() and trucks + queued < int(cf["trucks"]) and gold >= 300.0:
		g.queue_unit(deps.pick_random(), "truck")
		return
	var facs: Array = _mine_list("fac")
	var bars: Array = _mine_list("bar")
	var airs: Array = _mine_list("air")
	var bld = null
	var tp := ""
	if bool(cf["air"]) and not airs.is_empty() and gold >= 800.0 and randf() < 0.4:
		bld = airs.pick_random()
		tp = ["heli", "jet", "jet", "bomber"].pick_random()
	elif not facs.is_empty() and gold >= 450.0 and randf() < 0.55:
		bld = facs.pick_random()
		tp = _pick_vehicle(tech)
	elif not bars.is_empty() and gold >= 100.0:
		bld = bars.pick_random()
		tp = _pick_inf(tech)
	if bld != null and tp != "" and bld.q.size() < 3:
		g.queue_unit(bld, tp)


func _build(cf: Dictionary) -> void:
	var mine_b: Array = g.blds.filter(func(b): return b.team == slot and not b.dead)
	var count := func(ty: String) -> int:
		return mine_b.filter(func(b): return b.type == ty).size()
	var depots: int = count.call("dep")
	var max_f: int = 1
	match g.diff:
		"normal":
			max_f = 2
		"hard":
			max_f = 4
	var gold: float = g.gold[slot]
	if depots < int(cf["depots"]) and gold >= 600.0:
		_place_depot()
	elif bool(cf["air"]) and count.call("air") < 1 and count.call("fac") >= 1 and gold >= 1000.0:
		_auto_place("air")
	elif count.call("fac") < max_f and gold >= 800.0:
		_auto_place("fac")
	elif count.call("bar") < max_f + 1 and gold >= 500.0:
		_auto_place("bar")
	elif _def_count(mine_b) < int(cf["def_max"]) and gold >= 450.0 and randf() < 0.7:
		var kinds: Array = cf["def_kinds"]
		_auto_place(str(kinds.pick_random()))
	elif g.diff == "hard" and count.call("ref") < 1 and count.call("dep") >= 2 and gold >= 1300.0:
		_auto_place("ref")
	elif g.diff != "easy" and count.call("rep") < 1 and count.call("fac") >= 1 and gold >= 900.0:
		_auto_place("rep")


# الهجوم بلا موعد ثابت: العدو يهاجم حين يجهز جيشه، وبميل عشوائي، ومن اتجاه مختلف في كل مرة.
# مفارز صغيرة تلتف إلى جهة عشوائية حول مدينتك ثم تقتحم، وأحياناً هجوم شامل يتوزع على عدة جهات في آن واحد.
func _recycle() -> void:
	# وحدة أنهت مهمتها (لا مسار ولا هدف) تعود صالحة لمفرزة أو هجوم جديد
	for u in g.units:
		if u.team == slot and u.sent and not u.dead and u.path.is_empty() and u.tgt == null and u.route.is_empty():
			u.sent = false


# أهداف العدو مرتبة من الأقرب لمقري
func _targets() -> Array:
	var targets: Array = g.blds.filter(func(b): return g.hostile(b.team, slot) and not b.dead and b.type != "wall")
	var me: Variant = g.find_hq(slot)
	if me != null:
		targets.sort_custom(func(a, b): return Vector2(a.cell).distance_to(Vector2(me.cell)) < Vector2(b.cell).distance_to(Vector2(me.cell)))
	return targets


# زاوية اقتراب جديدة تختلف عن آخر زاوية، فلا تعرف من أين سيأتي الهجوم
func _new_angle() -> float:
	var ang: float = randf() * TAU
	for _i in range(8):
		if absf(angle_difference(ang, last_ang)) > 1.0:
			break
		ang = randf() * TAU
	last_ang = ang
	return ang


# نقطة التفاف حول الهدف بعيدة عنه بعدد من الخلايا
func _approach(tb, ang: float) -> Vector2i:
	var dist: float = randf_range(24.0, 38.0)
	var cc: Vector2 = Vector2(tb.cell) + Vector2(cos(ang), sin(ang)) * dist
	var c := Vector2i(clampi(int(cc.x), 3, Data.MAP - 4), clampi(int(cc.y), 3, Data.MAP - 4))
	return g.nearest_free(c, true, 10)


func _send(group: Array, tb, ang: float) -> void:
	var final_cell: Vector2i = tb.cell + Vector2i(1, 1)
	var wp: Vector2i = _approach(tb, ang)
	for u in group:
		u.sent = true
		u.amove = true
		u.route = []
		if wp.x >= 0:
			u.route = [final_cell]
			u.dest = wp
		else:
			u.dest = final_cell
		u.goto_cell(u.dest)


func _warn(msg: String, tb, loud: bool) -> void:
	# تحذير على الشاشة للاعب (وللحلفاء): بلا ذكر وقت ولا اتجاه
	if tb == null or not g.friendly(tb.team):
		return
	g.hud.toast(msg, 3.2)
	if loud:
		Sfx.play("alert")


func _attack(cf: Dictionary) -> void:
	if g.time < next_check:
		return
	next_check = g.time + 3.0
	_recycle()
	var free: Array = g.units.filter(func(u): return u.team == slot and not u.dead and not u.sent and not u.is_truck)
	if free.is_empty():
		return
	var targets: Array = _targets()
	if targets.is_empty():
		return
	var aggr: float = float(cf["aggr"])
	# 1) الهجوم الشامل: جيش كبير جاهز، يتوزع على 2-3 جهات ويضرب أهدافاً مختلفة في آن واحد
	if free.size() >= int(cf["wave"]) and g.time >= next_full and raids_done >= 2 and randf() < aggr * 0.5:
		next_full = g.time + float(cf["full_gap"]) * randf_range(1.0, 1.7)
		next_raid = g.time + float(cf["gap"]) * randf_range(0.6, 1.0)
		free.shuffle()
		var ng: int = 2 if free.size() < 22 else 3
		var base_ang: float = _new_angle()
		_warn("تحذير! هجوم شامل يتجه نحو مدينتك", targets[0], true)
		for i in range(ng):
			var part: Array = []
			for k in range(free.size()):
				if k % ng == i:
					part.append(free[k])
			var tb: Variant = targets[mini(i, targets.size() - 1)]
			_send(part, tb, base_ang + float(i) * TAU / float(ng) + randf_range(-0.3, 0.3))
		raids_done += 1
		return
	# 2) مفرزة: مجموعة صغيرة تلتف من جهة عشوائية، ويبقى باقي الجيش للدفاع
	var n: int = int(cf["raid"])
	if g.time >= next_raid and free.size() >= n + 2 and randf() < aggr:
		next_raid = g.time + float(cf["gap"]) * randf_range(0.8, 1.6)
		var pool: Array = free.duplicate()
		pool.shuffle()
		var tb2: Variant = targets[mini(randi() % 3, targets.size() - 1)]
		_warn("تنبيه: مفرزة معادية تقترب من مدينتك", tb2, false)
		_send(pool.slice(0, n), tb2, _new_angle())
		raids_done += 1


# دفاع: عند تعرض مبنى لي أو لحليفي للهجوم تتحرك الوحدات الحرة (والقاذفات) إلى مكان الهجوم
func _defend() -> void:
	var th: Variant = Threats.latest(g, slot)
	if th == null:
		return
	var tpos: Vector3 = th["pos"]
	var tc: Vector2i = g.world_to_cell(tpos)
	var own_base: bool = int(th["owner"]) == slot
	for u in g.units:
		if u.team != slot or u.dead or u.is_truck:
			continue
		if u.tgt != null and is_instance_valid(u.tgt) and not u.tgt.dead:
			continue
		if u.sent and not own_base:
			continue
		if Vector2(u.position.x - tpos.x, u.position.z - tpos.z).length() < 16.0:
			continue
		if u.dest.x >= 0 and Vector2(u.dest).distance_to(Vector2(tc)) < 8.0 and (u.amove or not u.path.is_empty()):
			continue
		u.amove = true
		u.dest = tc + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
		u.goto_cell(u.dest)


func _place_depot() -> void:
	var own: Array = g.blds.filter(func(b): return b.team == slot and not b.dead and b.type == "dep")
	var best = null
	var bd := 1e9
	var hq: Variant = g.find_hq(slot)
	if hq == null:
		return
	for m in g.mines:
		if float(m["amount"]) <= 0.0:
			continue
		var near_dep := false
		for d in own:
			if Vector2(d.cell).distance_to(Vector2(m["cell"])) < 16.0 * Data.K:
				near_dep = true
		if near_dep:
			continue
		var dist: float = Vector2(m["cell"]).distance_to(Vector2(hq.cell))
		if dist < bd:
			bd = dist
			best = m
	if best == null or bd > 70.0 * Data.K:
		return
	for i in 40:
		var c: Vector2i = best["cell"] + Vector2i(randi_range(-7, 7), randi_range(-7, 7))
		if g.can_place(slot, "dep", c):
			g.gold[slot] -= float(Data.BUILDINGS["dep"]["cost"])
			g.add_building("dep", slot, c, false)
			return


func _auto_place(type: String) -> void:
	var hq: Variant = g.find_hq(slot)
	if hq == null:
		return
	for i in 40:
		var c := Vector2i(hq.cell.x + randi_range(-12, 12), hq.cell.y + randi_range(-12, 12))
		if g.can_place(slot, type, c):
			g.gold[slot] -= float(Data.BUILDINGS[type]["cost"])
			g.add_building(type, slot, c, false)
			return
