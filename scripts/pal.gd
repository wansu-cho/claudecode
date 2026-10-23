class_name Pal
## 게임 전체에서 쓰는 색, 글자 크기, 자주 쓰는 화면 부품입니다.

const BG := Color("05060f")
const PANEL := Color(0.05, 0.05, 0.12, 0.92)
const LINE := Color("4a4470")
const TEXT := Color("ecebf7")
const DIM := Color("8e8aae")
const CYAN := Color("82ecf6")
const GOLD := Color("ffd76e")
const PINK := Color("ff8fb0")
const STAR := Color("f6f2e2")

const SMALL := 12
const BIG := 24
const SCREEN := Vector2(640, 360)


static func label(text: String, size := SMALL, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box_style(bg := PANEL, border := LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.anti_aliasing = false
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func button(text: String, size := SMALL) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box_style())
	b.add_theme_stylebox_override("hover", box_style(PANEL, CYAN))
	b.add_theme_stylebox_override("pressed", box_style(Color(0.15, 0.14, 0.3, 0.95), GOLD))
	b.add_theme_stylebox_override("disabled", box_style(Color(0.05, 0.05, 0.1, 0.7), Color(0.2, 0.2, 0.3)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	return b


## 점선을 픽셀 단위로 그립니다.
static func dotted(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, gap := 3) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	var d := 0.0
	while d <= length:
		ci.draw_rect(Rect2((from + dir * d).floor(), Vector2.ONE), color)
		d += gap


## 네모난 선택 고리
static func ring(ci: CanvasItem, center: Vector2, r: int, color: Color) -> void:
	var c := center.floor()
	ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2 + 1, r * 2 + 1)), color, false, 1.0)


## 십자 반짝임 별
static func sparkle(ci: CanvasItem, p: Vector2, arm: int, color: Color) -> void:
	var c := p.floor()
	ci.draw_rect(Rect2(c, Vector2.ONE), Color.WHITE)
	for k in range(1, arm + 1):
		var a := color
		a.a *= 1.0 - float(k) / (arm + 1)
		for dpos in [Vector2(k, 0), Vector2(-k, 0), Vector2(0, k), Vector2(0, -k)]:
			ci.draw_rect(Rect2(c + dpos, Vector2.ONE), a)
