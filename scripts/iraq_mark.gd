class_name IraqMark
extends Control
## علامة «صنع في العراق» المميزة أسفل شاشة اللعب: لوحة داكنة بإطار ذهبي مزدوج وشريط ألوان العلم،
## ونص ذهبي كبير بلمعة تمر عليه، وعبارة MADE IN IRAQ صغيرة. لا تعترض اللمس.

const GOLD := Color(0.96, 0.74, 0.22)
const GOLD_L := Color(1.0, 0.92, 0.62)

var sweep := -0.3
var phase := 0.0


func setup() -> IraqMark:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(268, 74)
	size = custom_minimum_size
	clip_contents = true
	var lbl := Label.new()
	lbl.text = "صنع في العراق"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(62, 8)
	lbl.size = Vector2(200, 40)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", GOLD_L)
	lbl.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.02, 1.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	add_child(lbl)
	var sub := Label.new()
	sub.text = "MADE  IN  IRAQ"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(62, 46)
	sub.size = Vector2(200, 20)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.78, 0.84, 0.82))
	add_child(sub)
	return self


func _process(delta: float) -> void:
	phase += delta
	sweep = fmod(phase * 0.28, 1.6) - 0.3
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# اللوحة
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.035, 0.05, 0.07, 0.9))
	draw_rect(Rect2(2, 2, w - 4, h - 4), GOLD, false, 2.5)
	draw_rect(Rect2(7, 7, w - 14, h - 14), Color(GOLD.r, GOLD.g, GOLD.b, 0.55), false, 1.0)
	# شريط ألوان العلم (أحمر، أبيض، أسود) داخل إطار ذهبي
	var fx := 14.0
	var fy := 16.0
	var fw := 40.0
	var fh := 42.0
	draw_rect(Rect2(fx - 2, fy - 2, fw + 4, fh + 4), GOLD)
	draw_rect(Rect2(fx, fy, fw, fh / 3.0), Color(0.81, 0.07, 0.15))
	draw_rect(Rect2(fx, fy + fh / 3.0, fw, fh / 3.0), Color(0.97, 0.97, 0.95))
	draw_rect(Rect2(fx, fy + fh * 2.0 / 3.0, fw, fh / 3.0), Color(0.03, 0.03, 0.03))
	for k in range(3):
		var sx: float = fx + 9.0 + float(k) * 11.0
		var sy: float = fy + fh / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - 4.5), Vector2(sx + 3.8, sy + 3.0), Vector2(sx - 3.8, sy + 3.0)]), Color(0.1, 0.5, 0.25))
	# لمعة متحركة
	var sx2: float = sweep * w
	var sk := 26.0
	draw_colored_polygon(PackedVector2Array([Vector2(sx2, 0), Vector2(sx2 + 22.0, 0), Vector2(sx2 + 22.0 - sk, h), Vector2(sx2 - sk, h)]), Color(1, 1, 0.9, 0.16))
