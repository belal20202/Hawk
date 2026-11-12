class_name IraqMark
extends Control
## علامة «صنع في العراق» المميزة في شاشة اللعب (بلا علم): لوحة داكنة بإطار ذهبي مزدوج،
## عنوان ذهبي كبير بلمعة تمر عليه وفاصل زخرفي، وتحته «تطوير وتصميم بلال» بجانب صورة مصغرة لولد مصمم.
## لا تعترض اللمس.

const GOLD := Color(1.0, 0.84, 0.3)
const GOLD_L := Color(1.0, 0.94, 0.66)
const W := 300.0
const H := 96.0

var sweep := -0.3
var phase := 0.0


func setup() -> IraqMark:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	clip_contents = true
	var lbl := Label.new()
	lbl.text = "صنع في العراق"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(10, 6)
	lbl.size = Vector2(W - 20.0, 40)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", GOLD_L)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.2, 1.0))
	lbl.add_theme_constant_override("outline_size", 9)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	add_child(lbl)
	var dev := Label.new()
	dev.text = "تطوير وتصميم بلال"
	dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dev.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dev.position = Vector2(8, 56)
	dev.size = Vector2(W - 70.0, 34)
	dev.add_theme_font_size_override("font_size", 20)
	dev.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0))
	dev.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.2, 1.0))
	dev.add_theme_constant_override("outline_size", 6)
	add_child(dev)
	return self


func _process(delta: float) -> void:
	phase += delta
	sweep = fmod(phase * 0.28, 1.6) - 0.3
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# اللوحة
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.02, 0.06, 0.15, 0.9))
	draw_rect(Rect2(2, 2, w - 4, h - 4), GOLD, false, 2.5)
	draw_rect(Rect2(7, 7, w - 14, h - 14), Color(GOLD.r, GOLD.g, GOLD.b, 0.5), false, 1.0)
	# فاصل زخرفي بمعين في المنتصف
	var dy := 50.0
	var cx: float = w * 0.5
	draw_line(Vector2(18, dy), Vector2(cx - 12.0, dy), Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 1.5)
	draw_line(Vector2(cx + 12.0, dy), Vector2(w - 18.0, dy), Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, dy - 5.0), Vector2(cx + 6.0, dy), Vector2(cx, dy + 5.0), Vector2(cx - 6.0, dy)]), GOLD)
	# صورة مصغرة: ولد مصمم بسماعات وقلم
	_draw_designer(Vector2(w - 36.0, 73.0 + sin(phase * 2.0) * 0.8))
	# لمعة متحركة
	var sx2: float = sweep * w
	var sk := 26.0
	draw_colored_polygon(PackedVector2Array([Vector2(sx2, 0), Vector2(sx2 + 22.0, 0), Vector2(sx2 + 22.0 - sk, h), Vector2(sx2 - sk, h)]), Color(1, 1, 0.9, 0.14))


func _draw_designer(ac: Vector2) -> void:
	draw_circle(ac, 20.5, GOLD)
	draw_circle(ac, 19.0, Color(0.18, 0.46, 0.78))
	# القميص
	draw_colored_polygon(PackedVector2Array([ac + Vector2(-11, 14), ac + Vector2(-9, 8), ac + Vector2(-4, 6), ac + Vector2(4, 6), ac + Vector2(9, 8), ac + Vector2(11, 14)]), Color(0.96, 0.5, 0.16))
	# الوجه
	draw_circle(ac + Vector2(0, -2), 8.5, Color(0.98, 0.8, 0.64))
	# الشعر
	draw_colored_polygon(PackedVector2Array([ac + Vector2(-8.5, -3), ac + Vector2(-8, -9), ac + Vector2(-4, -12.5), ac + Vector2(4, -12.5), ac + Vector2(8, -9), ac + Vector2(8.5, -3), ac + Vector2(6, -6), ac + Vector2(0, -8), ac + Vector2(-6, -6)]), Color(0.14, 0.09, 0.07))
	# السماعات
	draw_arc(ac + Vector2(0, -2), 10.0, PI * 1.08, PI * 1.92, 14, Color(0.15, 0.15, 0.2), 2.2)
	draw_circle(ac + Vector2(-9.5, -2), 2.8, GOLD)
	draw_circle(ac + Vector2(9.5, -2), 2.8, GOLD)
	# النظارة والعينان والابتسامة
	draw_arc(ac + Vector2(-3.2, -1), 2.7, 0.0, TAU, 10, Color(1, 1, 1), 1.0)
	draw_arc(ac + Vector2(3.2, -1), 2.7, 0.0, TAU, 10, Color(1, 1, 1), 1.0)
	draw_circle(ac + Vector2(-3.2, -1), 1.0, Color(0.08, 0.08, 0.1))
	draw_circle(ac + Vector2(3.2, -1), 1.0, Color(0.08, 0.08, 0.1))
	draw_arc(ac + Vector2(0, 2.0), 3.2, 0.25, PI - 0.25, 8, Color(0.55, 0.2, 0.15), 1.2)
	# قلم التصميم
	draw_line(ac + Vector2(9, 15), ac + Vector2(17, 6), Color(1.0, 0.95, 0.4), 2.4)
	draw_circle(ac + Vector2(17, 6), 1.4, Color(0.95, 0.3, 0.3))
