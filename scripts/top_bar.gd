class_name TopBar
extends PanelContainer
## اللوحة العلوية الاحترافية: الذهب (برقم متحرك) والشاحنات وعدد الجيش ونمط اللعب.
## الأيقونات مرسومة بالكود (عملة، شاحنة، درع) بلا ملفات صور.

const GOLD := Color(0.96, 0.78, 0.26)
const GOLD_L := Color(1.0, 0.92, 0.62)
const INK := Color(0.035, 0.055, 0.08, 0.93)
const SOFT := Color(0.66, 0.74, 0.76)

var lbl_gold: Label
var lbl_trucks: Label
var lbl_army: Label
var lbl_mode: Label
var shown_gold := -1.0
var target_gold := 0
var last_gold := -1
var gold_box: Control
var flash_t := 0.0
var flash_col := Color(1, 1, 1)


# أيقونة مرسومة: coin عملة ذهبية، truck شاحنة، shield درع الجيش
class Icon extends Control:
	var kind := "coin"

	func _init(k := "coin") -> void:
		kind = k
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		match kind:
			"coin":
				draw_circle(c + Vector2(0, 2), 17.0, Color(0, 0, 0, 0.35))
				draw_circle(c, 17.0, Color(0.62, 0.4, 0.06))
				draw_circle(c, 15.2, Color(0.97, 0.78, 0.22))
				draw_circle(c, 11.5, Color(0.86, 0.62, 0.1))
				draw_circle(c, 10.2, Color(0.99, 0.84, 0.35))
				var d := 6.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(0.78, 0.52, 0.06))
				draw_arc(c, 13.0, 3.4, 4.5, 10, Color(1, 1, 0.9, 0.85), 2.0)
			"truck":
				draw_rect(Rect2(c.x - 17, c.y - 9, 20, 16), Color(0.52, 0.55, 0.52))
				draw_rect(Rect2(c.x - 17, c.y - 9, 20, 4), Color(0.72, 0.75, 0.72))
				draw_colored_polygon(PackedVector2Array([Vector2(c.x + 4, c.y - 5), Vector2(c.x + 12, c.y - 5), Vector2(c.x + 17, c.y + 2), Vector2(c.x + 17, c.y + 7), Vector2(c.x + 4, c.y + 7)]), Color(0.95, 0.72, 0.18))
				draw_rect(Rect2(c.x + 7, c.y - 3, 5, 4), Color(0.55, 0.8, 0.92))
				for wx in [-10.0, 0.0, 11.0]:
					draw_circle(Vector2(c.x + wx, c.y + 8), 4.2, Color(0.08, 0.08, 0.08))
					draw_circle(Vector2(c.x + wx, c.y + 8), 1.7, Color(0.7, 0.7, 0.7))
			"shield":
				var pts := PackedVector2Array([c + Vector2(0, -17), c + Vector2(15, -11), c + Vector2(13, 6), c + Vector2(0, 17), c + Vector2(-13, 6), c + Vector2(-15, -11)])
				draw_colored_polygon(pts, Color(0.6, 0.45, 0.1))
				var inner := PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, -9), c + Vector2(10.5, 5), c + Vector2(0, 14), c + Vector2(-10.5, 5), c + Vector2(-12, -9)])
				draw_colored_polygon(inner, Color(0.13, 0.2, 0.28))
				draw_line(c + Vector2(-6, 0), c + Vector2(0, -6), Color(0.97, 0.78, 0.26), 3.0)
				draw_line(c + Vector2(0, -6), c + Vector2(6, 0), Color(0.97, 0.78, 0.26), 3.0)
				draw_line(c + Vector2(-6, 6), c + Vector2(0, 0), Color(0.97, 0.78, 0.26), 3.0)
				draw_line(c + Vector2(0, 0), c + Vector2(6, 6), Color(0.97, 0.78, 0.26), 3.0)


func setup() -> TopBar:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = INK
	st.border_color = GOLD
	st.border_width_left = 2
	st.border_width_right = 2
	st.border_width_top = 2
	st.border_width_bottom = 4
	st.set_corner_radius_all(16)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 7
	st.content_margin_bottom = 8
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 10
	st.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	var g1 := _stat("coin", "الذهب", 30, GOLD_L)
	lbl_gold = g1[1]
	gold_box = g1[0]
	hb.add_child(g1[0])
	hb.add_child(_divider())
	var g2 := _stat("truck", "الشاحنات", 24, Color(0.93, 0.95, 0.92))
	lbl_trucks = g2[1]
	hb.add_child(g2[0])
	hb.add_child(_divider())
	var g3 := _stat("shield", "الجيش", 24, Color(0.93, 0.95, 0.92))
	lbl_army = g3[1]
	hb.add_child(g3[0])
	hb.add_child(_divider())
	lbl_mode = Label.new()
	lbl_mode.add_theme_font_size_override("font_size", 17)
	lbl_mode.add_theme_color_override("font_color", SOFT)
	lbl_mode.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl_mode.add_theme_constant_override("outline_size", 3)
	lbl_mode.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_mode.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lbl_mode)
	return self


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(0.96, 0.78, 0.26, 0.35)
	d.custom_minimum_size = Vector2(2, 34)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


# بطاقة معلومة: أيقونة + رقم كبير + عنوان صغير. ترجع [العقدة، تسمية الرقم]
func _stat(kind: String, caption: String, fs: int, col: Color) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Icon.new(kind))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val := Label.new()
	val.text = "0"
	val.add_theme_font_size_override("font_size", fs)
	val.add_theme_color_override("font_color", col)
	val.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0, 0.95))
	val.add_theme_constant_override("outline_size", 5)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(val)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", SOFT)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	h.add_child(v)
	return [h, val]


static func fmt(n: int) -> String:
	var s: String = str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func set_stats(gold: int, trucks: int, army: int, mode_name: String) -> void:
	target_gold = gold
	if shown_gold < 0.0:
		shown_gold = float(gold)
		last_gold = gold
	elif gold != last_gold:
		flash_t = 0.5
		flash_col = Color(0.55, 1.0, 0.6) if gold > last_gold else Color(1.0, 0.5, 0.45)
		last_gold = gold
	lbl_trucks.text = str(trucks)
	lbl_army.text = str(army)
	lbl_mode.text = mode_name


func _process(delta: float) -> void:
	if shown_gold < 0.0:
		return
	if absf(shown_gold - float(target_gold)) > 0.5:
		shown_gold = lerpf(shown_gold, float(target_gold), clampf(delta * 9.0, 0.0, 1.0))
	else:
		shown_gold = float(target_gold)
	lbl_gold.text = fmt(int(round(shown_gold)))
	if flash_t > 0.0:
		flash_t -= delta
		var k: float = clampf(flash_t / 0.5, 0.0, 1.0)
		lbl_gold.self_modulate = Color(1, 1, 1).lerp(flash_col, k)
	else:
		lbl_gold.self_modulate = Color(1, 1, 1)
