extends Control
## 지하 별지기의 방 (진엔딩). 그림 assets/backgrounds/starkeeper.png 가 있으면 그것을, 없으면 임시로 그립니다.

var piece := false                   # 일곱 번째 조각이 빛나는지
var _t := 0.0
var _bg: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var path := "res://assets/backgrounds/starkeeper.png"
	_bg = load(path) if ResourceLoader.exists(path) else null


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	if _bg:
		var k := maxf(Pal.SCREEN.x / _bg.get_width(), Pal.SCREEN.y / _bg.get_height())
		var sz := Vector2(_bg.get_width(), _bg.get_height()) * k
		draw_texture_rect(_bg, Rect2((Pal.SCREEN - sz) / 2.0, sz), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, Pal.SCREEN), Color8(26, 22, 36))
		for y in range(0, 270, 18):                       # 돌벽
			for x in range(-((y / 18) % 2) * 20, 660, 40):
				draw_rect(Rect2(x + 1, y + 1, 38, 16), Color8(44, 38, 54))
		draw_rect(Rect2(0, 270, 640, 90), Color8(54, 40, 34))     # 나무 바닥
		var chart := Rect2(200, 40, 240, 130)                    # 벽의 옛 별지도
		draw_rect(chart, Color8(210, 190, 150))
		draw_rect(chart, Color8(120, 90, 60), false, 3.0)
		draw_circle(chart.get_center(), 56, Color8(40, 48, 90))
		for i in 40:
			var a := i * 2.39
			var r := fmod(i * 7.3, 54.0)
			draw_circle(chart.get_center() + Vector2.from_angle(a) * r, 1.2, Color(1, 1, 0.85))
		draw_rect(Rect2(150, 220, 340, 14), Color8(110, 74, 50))  # 책상
		draw_rect(Rect2(164, 234, 12, 40), Color8(90, 60, 42))
		draw_rect(Rect2(464, 234, 12, 40), Color8(90, 60, 42))
		draw_rect(Rect2(260, 206, 70, 14), Color8(236, 226, 196))  # 펼친 일지
		draw_line(Vector2(295, 206), Vector2(295, 220), Color8(160, 140, 110), 1)
		draw_rect(Rect2(360, 212, 30, 8), Color8(200, 40, 40))     # 빨간 손전등
		draw_string(font, Vector2(10, 350), "(임시 그림: 별지기의 방)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	if piece:                                                   # 일곱 번째 조각
		var c := Vector2(320, 196)
		var g := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(c, 26 + 6 * g, Color(1, 0.86, 0.45, 0.18))
		draw_circle(c, 10, Color(1, 0.92, 0.6, 0.9))
		for i in 5:
			var a := -PI / 2.0 + TAU * i / 5.0
			draw_line(c, c + Vector2.from_angle(a) * (18 + 4 * g), Color(1, 0.9, 0.6, 0.8), 2)
