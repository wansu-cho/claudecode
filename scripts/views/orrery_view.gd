extends Control
## 1층 로비의 지구 공전 모형입니다.
## 달(1월~12월)을 바꾸고 자전축 기울기(23.5° / 0°)를 바꾸면,
## 북위 34° 섬에서의 '한낮의 해 높이', '낮의 길이', '태양까지 거리'가 나옵니다.
##   한낮의 해 높이 = 90° − 위도 + 태양의 적위
##   낮의 길이 = 2 × arccos(−tan 위도 × tan 적위) ÷ 15° (+ 대기 굴절로 약 8분)
##   거리 = 1억 4,960만 km × (1 − 0.0167 × cos(근일점 1월 3일부터 지난 각도))
## 알게 되는 것
##   tilt_seasons: 23.5°로 6월과 12월을 보고, 0°로도 한 번 보기
##   perihelion: 1월과 7월의 거리를 보기

signal closed

const LAT := 34.0
const MONTH_DAY := [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349]   # 각 달 15일의 날짜 번호
const CENTER := Vector2(188, 182)
const ORBIT := Vector2(136, 104)

var month := 12
var tilt := 23.5
var _rec: Dictionary
var _status := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rec = Game.night.get("orrery", {"tilt": {}, "flat": false, "dist": {}})
	Game.night["orrery"] = _rec
	var row := HBoxContainer.new()
	row.position = Vector2(14, 330)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var prev := Pal.button("◀ 이전 달")
	prev.pressed.connect(func(): set_month(month - 1))
	row.add_child(prev)
	var next := Pal.button("다음 달 ▶")
	next.pressed.connect(func(): set_month(month + 1))
	row.add_child(next)
	var tb := Pal.button("자전축 바꾸기")
	tb.pressed.connect(func(): set_tilt(0.0 if tilt > 0.0 else 23.5))
	row.add_child(tb)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	set_month(12)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				close()
			KEY_LEFT, KEY_A:
				get_viewport().set_input_as_handled()
				set_month(month - 1)
			KEY_RIGHT, KEY_D:
				get_viewport().set_input_as_handled()
				set_month(month + 1)
			KEY_T:
				get_viewport().set_input_as_handled()
				set_tilt(0.0 if tilt > 0.0 else 23.5)


func set_month(mo: int) -> void:
	month = wrapi(mo, 1, 13)
	_record()


func set_tilt(t: float) -> void:
	tilt = t
	_record()


func declination() -> float:
	return -tilt * cos(TAU * (MONTH_DAY[month - 1] + 10) / 365.25)


func noon_alt() -> float:
	return 90.0 - LAT + declination()


func day_hours() -> float:
	var x := -tan(deg_to_rad(LAT)) * tan(deg_to_rad(declination()))
	return 2.0 * rad_to_deg(acos(clampf(x, -1.0, 1.0))) / 15.0 + 0.13


func distance_mkm() -> float:
	return 149.6 * (1.0 - 0.0167 * cos(TAU * (MONTH_DAY[month - 1] - 3) / 365.25))


func _record() -> void:
	if tilt > 0.0:
		_rec["tilt"][month] = true
	else:
		_rec["flat"] = true
	_rec["dist"][month] = true
	_status = ""
	if _rec["tilt"].has(6) and _rec["tilt"].has(12) and _rec["flat"]:
		if Game.add_fact("tilt_seasons"):
			_status = "자전축이 기울면 여름엔 해가 높고 낮이 길고, 겨울엔 해가 낮고 낮이 짧다. 축을 세우면 계절이 없다! (관측 일지에 기록)"
	if _rec["dist"].has(1) and _rec["dist"].has(7):
		if Game.add_fact("perihelion"):
			_status = "1월에 태양과 가장 가깝고 7월에 가장 멀다. 가장 가까운 1월이 한겨울이라니! (관측 일지에 기록)"
	queue_redraw()


func _season() -> String:
	if tilt == 0.0:
		return "계절 변화 없음"
	if month in [12, 1, 2]:
		return "겨울"
	if month in [3, 4, 5]:
		return "봄"
	if month in [6, 7, 8]:
		return "여름"
	return "가을"


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color8(20, 18, 34))
	draw_string(font, Vector2(10, 16), "1층 로비 · 지구 공전 모형", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	# 궤도와 태양
	var pts := PackedVector2Array()
	for i in 49:
		pts.append(CENTER + Vector2.from_angle(TAU * i / 48.0) * ORBIT)
	draw_polyline(pts, Color(0.7, 0.7, 1.0, 0.4), 1.0)
	draw_circle(CENTER, 18, Color8(255, 200, 90))
	draw_circle(CENTER, 26, Color(1, 0.8, 0.4, 0.15))
	for mo in range(1, 13):
		var a := _orbit_angle(mo)
		var p := CENTER + Vector2.from_angle(a) * ORBIT * 1.18
		draw_string(font, p - Vector2(8, -4), "%d월" % mo, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD if mo == month else Pal.DIM)
	# 지구: 자전축 방향은 1년 내내 그대로 (오른쪽으로 기울어 있음)
	# 6월(하지)에는 지구가 태양 왼쪽에 있어 북극이 태양 쪽으로, 12월에는 반대쪽으로 기웁니다.
	var ang := _orbit_angle(month)
	var e := CENTER + Vector2.from_angle(ang) * ORBIT
	draw_circle(e, 12, Color8(40, 70, 140))
	var to_sun := (CENTER - e).normalized()
	for i in 13:                                     # 해를 향한 반쪽은 밝게
		var a2 := to_sun.angle() - PI / 2.0 + PI * i / 12.0
		draw_line(e, e + Vector2.from_angle(a2) * 12.0, Color8(90, 150, 230), 2)
	var axis := Vector2.from_angle(-PI / 2.0 + deg_to_rad(tilt))
	draw_line(e - axis * 18.0, e + axis * 18.0, Color8(240, 240, 255), 1)
	draw_string(font, e + axis * 20.0 + Vector2(-3, 0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)

	# 오른쪽 정보판
	var r := Rect2(380, 34, 250, 210)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	var x := r.position.x + 10
	var hours := day_hours()
	var lines := [
		["%d월 · %s" % [month, _season()], Pal.GOLD],
		["자전축 기울기: %.1f°" % tilt, Pal.TEXT],
		["태양까지 거리: %s" % _korean_km(distance_mkm()), Pal.TEXT],
		["북위 34° 한낮의 해 높이: %.0f°" % noon_alt(), Pal.TEXT],
		["낮의 길이: 약 %d시간 %02d분" % [int(hours), roundi(fmod(hours, 1.0) * 60.0 / 10.0) * 10 % 60], Pal.TEXT],
	]
	for i in lines.size():
		draw_string(font, Vector2(x, r.position.y + 20 + i * 18), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, Pal.SMALL, lines[i][1])
	# 한낮의 해 높이 그림
	var g := Vector2(x + 30, r.end.y - 18)
	draw_line(g, g + Vector2(200, 0), Color8(120, 160, 110), 2)
	draw_string(font, g + Vector2(-26, 4), "땅", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	var sun_dir := Vector2.from_angle(-deg_to_rad(noon_alt()))
	draw_line(g + Vector2(100, 0), g + Vector2(100, 0) + sun_dir * 70.0, Color(1, 0.85, 0.4, 0.7), 1)
	draw_circle(g + Vector2(100, 0) + sun_dir * 74.0, 6, Color8(255, 210, 100))
	draw_arc(g + Vector2(100, 0), 22, -deg_to_rad(noon_alt()), 0, 12, Pal.GOLD, 1.0)

	var hint := "달을 바꾸고 자전축을 바꿔 보자. (← → 달, T 자전축)" if _status == "" else _status
	var sr := Rect2(380, 252, 250, 72)
	draw_rect(sr, Pal.PANEL)
	draw_multiline_string(font, sr.position + Vector2(6, 14), hint, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 12, Pal.SMALL, 4, Pal.TEXT)


## 북쪽에서 내려다본 공전 (시계 반대 방향). 하지(6월 21일) = 태양 왼쪽
func _orbit_angle(mo: int) -> float:
	return PI - TAU * (MONTH_DAY[mo - 1] - 172) / 365.25


## 백만 km 단위 → "1억 4,710만 km"
static func _korean_km(mkm: float) -> String:
	var man := roundi(mkm * 100.0)                # 만 km 단위
	var eok := man / 10000
	var rest := man % 10000
	return "%d억 %d,%03d만 km" % [eok, rest / 1000, rest % 1000]
