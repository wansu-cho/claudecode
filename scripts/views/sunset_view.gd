extends Control
## 옥상 서쪽 난간에서 본 해넘이입니다. (실제 해 위치, 17:17 무렵 해가 집니다)
## 해가 지기 전에 와서, 해가 수평선 아래로 완전히 사라질 때까지 지켜보면 '서쪽으로 지는 해'를 알게 됩니다.
## 2분마다 해의 위치에 점을 찍어, 해가 오른쪽 아래(북서쪽)로 비스듬히 내려가는 길을 보여 줍니다.

signal closed

const CENTER_AZ := 238.0
## 서남서쪽 고도 5°를 향한 심사 투영 (1°가 약 8픽셀, 지평선 y = 250)
var proj := SkyPainter.gno(CENTER_AZ, 5.0, 458.0, Vector2(320, 210))
const MARK_EVERY := 2.0          # 게임 분
const MARKS_NEEDED := 4          # 해가 지기 전부터 약 6분 이상 지켜보기
const SUN_SET_ALT := -0.3        # 해의 윗부분까지 수평선 아래로

var _marks: Array
var _status := ""
var _watched := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_marks = Game.night.get("sun_marks", [])
	Game.night["sun_marks"] = _marks
	var back := Pal.button("나가기")
	back.position = Vector2(560, 332)
	back.pressed.connect(close)
	add_child(back)
	_watched = Astro.sun_alt(Game.minutes) > SUN_SET_ALT
	if _watched:
		_status = "해가 서쪽 바다로 지고 있다. 해가 어느 쪽으로 움직이는지 끝까지 지켜보자."
	elif Game.has("sunset"):
		_status = "해가 진 자리가 아직 붉다. 해도 별처럼 서쪽으로 비스듬히 졌다."
	else:
		_status = "해는 이미 졌다. 해넘이를 보려면 밤이 시작되자마자 이곳에 와야 한다."


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	var m := Game.minutes
	var sun := _sun(m)
	if _watched and sun.x > SUN_SET_ALT - 0.6:
		if _marks.is_empty() or m - float(_marks[-1]["m"]) >= MARK_EVERY:
			_marks.append({"m": m, "aa": sun})
	if _watched and sun.x <= SUN_SET_ALT:
		_watched = false
		if _marks.size() >= MARKS_NEEDED:
			if Game.add_fact("sunset"):
				_status = "해가 오른쪽 아래로 비스듬히 내려가 바다 아래로 사라졌다. 해도 별들처럼 서쪽으로 진다! (관측 일지에 기록)"
			else:
				_status = "해가 서쪽으로 비스듬히 졌다."
		else:
			_status = "해가 졌다. 그런데 너무 늦게 와서 해가 움직이는 길을 다 보지 못했다. 다음엔 더 일찍 와 보자."
	queue_redraw()


func _sun(m: float) -> Vector2:
	return Astro.altaz(Astro.SUN_RA, Astro.SUN_DEC, m)


func _draw() -> void:
	var font := get_theme_default_font()
	var m := Game.minutes
	SkyPainter.draw(self, m, Pal.SCREEN, proj)
	var hy := SkyPainter.horizon_y(proj)
	var sun := _sun(m)
	var sp := SkyPainter.project(sun, proj)
	if sun.x > SUN_SET_ALT - 1.0:
		draw_circle(sp, 26, Color(1.0, 0.6, 0.3, 0.18))
		draw_circle(sp, 6, Color8(255, 196, 120))
	# 해가 지나온 길
	for i in _marks.size():
		var p := SkyPainter.project(_marks[i]["aa"], proj)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Pal.GOLD)
		if i > 0:
			Pal.dotted(self, SkyPainter.project(_marks[i - 1]["aa"], proj), p, Color(Pal.GOLD, 0.6), 2)
	# 서쪽 바다
	var dark := Astro.darkness(m)
	draw_rect(Rect2(0, hy, Pal.SCREEN.x, Pal.SCREEN.y - hy), Color8(40, 50, 90).lerp(Color8(12, 16, 36), dark))
	draw_rect(Rect2(sp.x - 18, hy + 2, 36, 2), Color(1.0, 0.7, 0.4, 0.5 * (1.0 - dark)))
	draw_line(Vector2(0, hy), Vector2(Pal.SCREEN.x, hy), Color(1, 0.8, 0.7, 0.3), 1)
	for d in [[225.0, "남서"], [270.0, "서"]]:
		var x: float = SkyPainter.project(Vector2(0.0, d[0]), proj).x
		draw_string(font, Vector2(x - 8, hy + 16), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(10, 15), "옥상 서쪽 난간 · 해넘이 · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var r := Rect2(10, 290, 540, 52)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	draw_multiline_string(font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)
