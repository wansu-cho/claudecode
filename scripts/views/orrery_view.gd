extends Control
## 1층 창고(실습실)의 지구 공전 모형입니다.
## 달(1월~12월)을 바꾸고 자전축 기울기(23.5° / 0°)를 바꾸면,
## 북위 34° 섬에서의 '한낮의 해 높이', '낮의 길이', '태양까지 거리'가 나옵니다.
##   한낮의 해 높이 = 90° − 위도 + 태양의 적위
##   낮의 길이 = 2 × arccos(−tan 위도 × tan 적위) ÷ 15° (+ 대기 굴절로 약 8분)
##   거리 = 1억 4,960만 km × (1 − 0.0167 × cos(근일점 1월 3일부터 지난 각도))
##   햇빛이 퍼지는 넓이 = 1 ÷ sin(한낮의 해 높이)  → 해가 낮으면 같은 햇빛이 넓게 퍼져 땅이 덜 데워짐
## 알게 되는 것
##   tilt_seasons: 23.5°로 6월과 12월을 보고, 0°로도 한 번 보기
##   perihelion: 1월과 7월의 거리를 보기

signal closed

const LAT := 34.0
const MONTH_DAY := [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349]   # 각 달 15일의 날짜 번호
const CENTER := Vector2(188, 182)
const ORBIT := Vector2(136, 29.3)           # 비스듬히 본 궤도 고리 (그림 속 고리 크기)
const BASE_SIZE := Vector2(272, 149)        # 받침대 그림 크기와 그 안의 고리 가운데
const BASE_RING := Vector2(136, 29.9)
const SUN := Vector2(188, 172)              # 받침 기둥 위 태양 가운데
const SUN_R := 30.0
const EARTH_SIZE := Vector2(30, 60.5)       # 지구 그림 (자전축 막대 포함)
const EARTH_R := 15.0
const VIEW_UP := Vector2(0, 29.3 / 136.0)      # 고리가 납작한 비율 (위에서 비스듬히 내려다본 정도)

var month := 12
var _ring: Texture2D = load("res://assets/views/orrery_ring.png")
var _pedestal: Texture2D = load("res://assets/views/orrery_pedestal.png")
var _sun: Texture2D = load("res://assets/views/orrery_sun.png")
var _earth: Texture2D = load("res://assets/views/orrery_earth.png")
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
			_status = "6월엔 해가 높고 햇빛이 좁게 모인다. 12월엔 해가 낮고 햇빛이 넓게 퍼진다. 축을 세우면 1년 내내 똑같다. 무슨 뜻일까? (나가서 생각해 보자)"
	if _rec["dist"].has(1) and _rec["dist"].has(7):
		if Game.add_fact("perihelion"):
			_status = "1월에 태양과 가장 가깝고, 7월에 가장 멀다. 1월은 우리나라의 한겨울인데… 무슨 뜻일까? (나가서 생각해 보자)"
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
	draw_string(font, Vector2(10, 16), "1층 창고 · 지구 공전 모형", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	# 공전 모형: 나무 받침대와 금속 궤도 고리(비스듬히 본 모습), 받침 기둥 위의 태양
	# 겹치는 순서: 고리 뒤쪽 → (뒤쪽 지구) → 받침대 → 태양 → 고리 앞쪽 → (앞쪽 지구)
	var frame := Rect2(CENTER - BASE_RING, BASE_SIZE)
	var split := BASE_RING.y / BASE_SIZE.y                 # 고리 가운데 높이에서 앞뒤를 나눔
	var rw := _ring.get_width()
	var rh := _ring.get_height()
	draw_texture_rect_region(_ring, Rect2(frame.position, Vector2(BASE_SIZE.x, BASE_RING.y)), Rect2(0, 0, rw, rh * split))
	var ang := _orbit_angle(month)
	var e := CENTER + Vector2(cos(ang) * ORBIT.x, sin(ang) * ORBIT.y)
	var far := sin(ang) < 0.0                         # 고리 뒤쪽이면 태양에 가려짐
	if far:
		_draw_earth(e)
	draw_texture_rect(_pedestal, frame, false)
	draw_circle(SUN, SUN_R + 10.0, Color(1, 0.8, 0.4, 0.12))
	draw_texture_rect(_sun, Rect2(SUN - Vector2(SUN_R, SUN_R), Vector2(SUN_R, SUN_R) * 2.0), false)
	draw_texture_rect_region(_ring, Rect2(frame.position + Vector2(0, BASE_RING.y), Vector2(BASE_SIZE.x, BASE_SIZE.y - BASE_RING.y)),
			Rect2(0, rh * split, rw, rh * (1.0 - split)))   # 고리 앞쪽은 태양 받침 기둥보다 앞에
	if not far:
		_draw_earth(e)
	for mo in [3, 6, 9, 12]:                          # 계절의 가운데 달만 고리 둘레에 (고리가 납작해 다 쓰면 겹침)
		if mo == month:
			continue
		var a := _orbit_angle(mo)
		var p := CENTER + Vector2(cos(a) * (ORBIT.x + 30.0), sin(a) * (ORBIT.y + (26.0 if sin(a) < 0.0 else 52.0)))
		draw_string(font, p - Vector2(10, -4), "%d월" % mo, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(font, e + Vector2(16, -18), "%d월" % month, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)   # 지금 지구가 있는 달

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
	# 한낮의 햇빛: 같은 굵기의 햇빛 다발이 땅에 닿는 넓이 (해가 낮을수록 넓게 퍼짐)
	var alt := noon_alt()
	var spread := 1.0 / sin(deg_to_rad(alt))
	var g := Vector2(x + 10, r.end.y - 30)
	draw_line(g, g + Vector2(220, 0), Color8(120, 160, 110), 2)
	var hit := g + Vector2(120, 0)
	var beam := 22.0                                   # 햇빛 다발의 굵기 (픽셀)
	var patch := beam * spread
	var sun_dir := Vector2.from_angle(-deg_to_rad(alt))
	draw_rect(Rect2(hit.x - patch / 2.0, g.y - 2, patch, 3), Color8(255, 200, 90))
	for i in 5:
		var gp := hit + Vector2(-patch / 2.0 + patch * i / 4.0, 0)
		draw_line(gp, gp + sun_dir * 52.0, Color(1, 0.85, 0.4, 0.55), 1)
	draw_circle(hit + sun_dir * 60.0, 6, Color8(255, 210, 100))
	draw_string(font, Vector2(x, g.y - 62), "한낮의 햇빛 · 퍼지는 넓이 ×%.1f" % spread, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(font, Vector2(x, g.y + 16), "땅 한 곳이 받는 햇빛: %d%%" % roundi(100.0 / spread), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, Pal.SMALL, Pal.GOLD)

	var hint := "달을 바꾸고 자전축을 바꿔 보자. (← → 달, T 자전축)" if _status == "" else _status
	var sr := Rect2(380, 252, 250, 72)
	draw_rect(sr, Pal.PANEL)
	draw_multiline_string(font, sr.position + Vector2(6, 14), hint, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 12, Pal.SMALL, 4, Pal.TEXT)


## 지구 그림: 자전축은 1년 내내 같은 쪽(오른쪽)으로 기울어 있고, 태양 반대쪽 절반은 밤
func _draw_earth(e: Vector2) -> void:
	var font := get_theme_default_font()
	draw_set_transform(e, deg_to_rad(tilt), Vector2.ONE)
	draw_texture_rect(_earth, Rect2(-EARTH_SIZE.x / 2.0, -EARTH_SIZE.y * 0.506, EARTH_SIZE.x, EARTH_SIZE.y), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 밤쪽: 공 모양 지구에서 태양을 등진 반쪽. 비스듬히 내려다보므로 낮과 밤의 경계(명암 경계선)가 곡선으로 보임
	var ang := _orbit_angle(month)
	var sun3 := Vector3(-cos(ang), 0.0, -sin(ang))     # 지구에서 태양 쪽 (x 오른쪽, y 위, z 보는 사람 쪽)
	var ce := VIEW_UP.y                               # 보는 눈높이: 고리 납작한 비율 = sin(올려다본 각)
	var down := Vector3(0.0, -sqrt(1.0 - ce * ce), ce) # 화면 아래 방향
	var look := Vector3(0.0, ce, sqrt(1.0 - ce * ce))  # 보는 사람 쪽
	var step := 1.0
	var y := -EARTH_R
	while y < EARTH_R:
		var x := -EARTH_R
		while x < EARTH_R:
			var u := x / EARTH_R
			var v := y / EARTH_R
			var r2 := u * u + v * v
			if r2 <= 1.0:
				var n := Vector3(u, 0, 0) + down * v + look * sqrt(1.0 - r2)
				var lit := n.dot(sun3)
				if lit < 0.0:
					draw_rect(Rect2(e + Vector2(x, y), Vector2(step, step)), Color(0.02, 0.02, 0.12, 0.72 * clampf(-lit * 8.0, 0.0, 1.0)))
			x += step
		y += step
	var axis := Vector2.from_angle(-PI / 2.0 + deg_to_rad(tilt))
	draw_string(font, e + axis * 36.0 + Vector2(-3, 0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)


## 북쪽에서 내려다본 공전 (시계 반대 방향). 하지(6월 21일) = 태양 왼쪽
func _orbit_angle(mo: int) -> float:
	return PI - TAU * (MONTH_DAY[mo - 1] - 172) / 365.25


## 백만 km 단위 → "1억 4,710만 km"
static func _korean_km(mkm: float) -> String:
	var man := roundi(mkm * 100.0)                # 만 km 단위
	var eok := man / 10000
	var rest := man % 10000
	return "%d억 %d,%03d만 km" % [eok, rest / 1000, rest % 1000]
