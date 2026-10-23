class_name Pal
## 게임 전체에서 쓰는 색과 글자 크기, 자주 쓰는 화면 부품을 모아 둔 곳입니다.
## 색을 바꾸고 싶으면 여기만 고치면 됩니다.

const BG := Color("0b0e1a")          # 밤하늘 바탕
const PANEL := Color("161b2e")       # 글상자 바탕
const LINE := Color("3a4466")        # 테두리
const TEXT := Color("e8ecf5")        # 기본 글자
const DIM := Color("7a849e")         # 흐린 글자 (오답, 안내)
const ACCENT := Color("5fd3e6")      # 강조 (하늘색)
const GOLD := Color("ffd75f")        # 정답, 골든 레코드
const STAR := Color("f4f1e0")        # 별

## 글자 크기는 픽셀 글꼴이 깨지지 않도록 12의 배수만 씁니다.
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
	return l


static func box_style(bg := PANEL, border := LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.anti_aliasing = false
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func button(text: String, size := BIG) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box_style())
	b.add_theme_stylebox_override("hover", box_style())
	b.add_theme_stylebox_override("pressed", box_style(LINE, ACCENT))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", GOLD)
	return b


## 점선을 픽셀 단위로 그립니다. (부드러운 선 대신 픽셀 느낌을 살리기 위해)
static func dotted_line(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, gap := 3) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	var d := 0.0
	while d <= length:
		var p := (from + dir * d).floor()
		ci.draw_rect(Rect2(p, Vector2.ONE), color)
		d += gap


## 픽셀 느낌의 네모난 고리(선택 표시)를 그립니다.
static func ring(ci: CanvasItem, center: Vector2, radius: int, color: Color) -> void:
	var c := center.floor()
	var r := radius
	ci.draw_rect(Rect2(c + Vector2(-r, -r), Vector2(r * 2 + 1, r * 2 + 1)), color, false, 1.0)
