extends Control
## 옥상 망원경으로 보는 달입니다. (시야 약 1°라 지름 0.5°인 달이 통째로 들어옴)
##   오늘 밤의 개기월식: 부분식 21:22 ~ 22:20, 개기식 22:20 ~ 23:52, 부분식 23:52 ~ 00:50
##   그림자 가장자리가 보이는 부분식 때 20분 이상 간격으로 3장을 찍으면 '언제나 둥근 그림자'
##   오른쪽 '남쪽 하늘' 판: 달은 동 → 남 → 서로 하늘을 지나갑니다. 찍은 사진이 그 길을 따라 쌓여
##   교재 171쪽 같은 월식 연속 사진이 됩니다.

signal closed

const PHOTO_GAP := 20.0          # 사진 사이 최소 간격 (게임 분)
const PHOTOS_NEEDED := 3
const EYE_C := Vector2(160, 162)  # 접안렌즈 시야 가운데
const EYE_R := 92.0
const MOON_PX := 62.0            # 망원경 속 달의 반지름 (픽셀)
const SKY := Rect2(318, 68, 312, 190)   # 남쪽 하늘 판 (왼쪽 동 90°, 가운데 남 180°, 오른쪽 서 270°, 아래 고도 0°, 위 90°)
const PATH_FROM := 18.0 * 60.0   # 달의 길을 그릴 시각 범위 (시계 분)
const PATH_TO := 30.0 * 60.0

var _photos: Array
var _status := ""
var _status_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_photos = Game.night.get("ecl_photos", [])
	Game.night["ecl_photos"] = _photos
	var row := HBoxContainer.new()
	row.position = Vector2(420, 338)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var shot := Pal.button("사진 찍기 (P)")
	shot.pressed.connect(take_photo)
	row.add_child(shot)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)


func close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_status_t = maxf(_status_t - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif event.keycode == KEY_P:
			get_viewport().set_input_as_handled()
			take_photo()


func _moon_status() -> String:
	var m := Game.minutes
	if Astro.moon_altaz(m).x < 3.0:
		return "달이 아직 동쪽 수평선 아래에 있다."
	match Astro.eclipse_phase(m):
		"partial":
			return "달 한쪽이 지구 그림자에 먹혀 들어가 있다! 그림자의 가장자리를 사진으로 남기자."
		"total":
			return "달 전체가 지구 그림자 속에 들어가 붉은 구릿빛으로 보인다. 지금은 그림자 가장자리가 보이지 않는다."
	if m < Game.at(Astro.ECL_MID):
		return "둥글고 밝은 보름달이 동쪽 하늘에 떠 있다. 휘의 말로는 21시 20분 무렵부터 달이 먹히기 시작한다고 했다."
	return "월식이 끝나고 다시 둥근 보름달이 되었다."


## 지금 달의 사진을 찍습니다. 그림자 가장자리가 보이는 부분식 때만 기록이 됩니다.
func take_photo() -> void:
	var m := Game.minutes
	if Astro.moon_altaz(m).x < 3.0:
		_say("달이 보이지 않는다.")
		return
	match Astro.eclipse_phase(m):
		"none":
			_say("찰칵! 둥근 보름달이다. 그림자가 달에 닿았을 때 찍어야 그림자 모양을 알 수 있다.")
			return
		"total":
			_say("찰칵! 달 전체가 붉다. 그림자의 가장자리가 안 보여서 모양을 알 수 없다. 부분식일 때 찍자.")
			return
	if not _photos.is_empty() and m - float(_photos[-1]["m"]) < PHOTO_GAP:
		_say("앞 사진과 시간이 너무 가깝다. 그림자가 더 움직인 뒤(20분쯤 뒤)에 다시 찍자.")
		return
	_photos.append({"m": m})
	if _photos.size() < PHOTOS_NEEDED:
		_say("찰칵! %s, 그림자의 가장자리는 둥근 곡선이다. (사진 %d/%d)" % [Game.clock(m), _photos.size(), PHOTOS_NEEDED])
	elif Game.add_fact("eclipse_round"):
		_say("세 장 모두, 달을 가린 그림자의 가장자리가 둥글게 휘어 있다. 무슨 뜻일까? (나가서 생각해 보자)")
	else:
		_say("찰칵! 이번에도 둥근 그림자다.")


func _say(text: String) -> void:
	_status = text
	_status_t = 5.0


# ---- 그리기 ----

func _draw() -> void:
	var font := get_theme_default_font()
	var m := Game.minutes
	draw_rect(Rect2(Vector2.ZERO, size), Color8(8, 8, 18))
	# 접안렌즈 시야
	draw_circle(EYE_C, EYE_R + 4, Color8(40, 40, 56))
	draw_circle(EYE_C, EYE_R, Color8(4, 4, 10))
	var aa := Astro.moon_altaz(m)
	if aa.x >= 3.0:
		_draw_moon(EYE_C, MOON_PX, m)
		draw_string(font, EYE_C + Vector2(-EYE_R + 6, -EYE_R + 16), "북 ↑  ← 동", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(font, EYE_C + Vector2(-46, EYE_R + 16), "망원경 속 달 (약 40배)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	_draw_sky_path(font, m)
	# 찍은 사진
	for i in PHOTOS_NEEDED:
		var r := Rect2(14 + i * 60, 284, 54, 66)
		draw_rect(r, Color8(16, 14, 28))
		draw_rect(r, Pal.LINE, false, 1.0)
		if i < _photos.size():
			var pm: float = _photos[i]["m"]
			_draw_moon(r.position + Vector2(27, 26), 18.0, pm)
			draw_string(font, Vector2(r.position.x + 6, r.end.y - 5), Game.clock(pm), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
		else:
			draw_string(font, Vector2(r.position.x + 22, r.position.y + 36), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(10, 15), "옥상 망원경 · 달 · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var sr := Rect2(10, 26, 620, 34)
	draw_rect(sr, Pal.PANEL)
	draw_rect(sr, Pal.LINE, false, 1.0)
	draw_multiline_string(font, sr.position + Vector2(6, 14), _status if _status_t > 0.0 else _moon_status(), HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 12, Pal.SMALL, 2, Pal.TEXT)


## 남쪽을 바라본 하늘에 달이 지나는 길과, 찍은 사진의 자리 (월식 연속 사진)
func _sky_xy(aa: Vector2) -> Vector2:
	var az := fposmod(aa.y, 360.0)
	return Vector2(SKY.position.x + (az - 90.0) / 180.0 * SKY.size.x, SKY.end.y - aa.x / 90.0 * SKY.size.y)


func _in_south(aa: Vector2) -> bool:
	var az := fposmod(aa.y, 360.0)
	return aa.x > 0.0 and az >= 90.0 and az <= 270.0


func _draw_sky_path(font: Font, m: float) -> void:
	draw_rect(SKY, Color8(14, 14, 34))
	draw_rect(SKY, Pal.LINE, false, 1.0)
	draw_string(font, SKY.position + Vector2(6, 14), "남쪽 하늘 · 달이 지나는 길", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	for d in [[90.0, "동"], [135.0, "남동"], [180.0, "남"], [225.0, "남서"], [270.0, "서"]]:
		var x := _sky_xy(Vector2(0, d[0])).x
		draw_line(Vector2(x, SKY.end.y), Vector2(x, SKY.end.y - 4), Pal.DIM, 1)
		draw_string(font, Vector2(clampf(x - 8, SKY.position.x + 2, SKY.end.x - 26), SKY.end.y + 14), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	for alt in [30.0, 60.0]:
		var y := _sky_xy(Vector2(alt, 180)).y
		Pal.dotted(self, Vector2(SKY.position.x, y), Vector2(SKY.end.x, y), Color(1, 1, 1, 0.08), 4)
		draw_string(font, Vector2(SKY.end.x - 24, y - 2), "%d°" % int(alt), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(Pal.DIM, 0.6))
	var prev := Vector2.INF
	var t := PATH_FROM - Game.START_CLOCK
	while t <= PATH_TO - Game.START_CLOCK:
		var aa := Astro.moon_altaz(t)
		var p := _sky_xy(aa)
		if _in_south(aa) and prev != Vector2.INF:
			draw_line(prev, p, Color(0.8, 0.8, 1.0, 0.25), 1)
		prev = p if _in_south(aa) else Vector2.INF
		t += 10.0
	for k in _photos.size():                           # 연속 사진처럼 달을 크게 겹쳐 그림 (시각은 위아래로 번갈아)
		var pm: float = _photos[k]["m"]
		var pp := _sky_xy(Astro.moon_altaz(pm))
		_draw_moon(pp, 9.0, pm)
		draw_string(font, pp + Vector2(-14, 22 if k % 2 == 0 else -12), Game.clock(pm), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	var aa_now := Astro.moon_altaz(m)
	if aa_now.x > 0.0:
		Pal.ring(self, _sky_xy(aa_now), 7, Pal.PINK)


## 달과 그 위에 드리운 지구 그림자를 그립니다. (북쪽이 위, 동쪽이 왼쪽)
func _draw_moon(c: Vector2, rad: float, m: float) -> void:
	var px_per_arcmin := rad / Astro.MOON_R
	var off := Astro.shadow_offset(m)
	var sc := c + Vector2(-off.x, -off.y) * px_per_arcmin
	var ur := Astro.UMBRA_R * px_per_arcmin
	var pr := Astro.PENUMBRA_R * px_per_arcmin
	var total := Astro.eclipse_phase(m) == "total"
	var step := 2.0 if rad > 30.0 else 1.0
	var y := -rad
	while y <= rad:
		var half := sqrt(maxf(rad * rad - y * y, 0.0))
		var x := -half
		while x <= half:
			var p := c + Vector2(x, y)
			var d := p.distance_to(sc)
			var col := Color8(236, 232, 214)
			if d < ur:
				var edge := clampf(d / ur, 0.0, 1.0)
				col = Color8(120, 46, 30).lerp(Color8(176, 84, 52), edge * edge) if total else Color8(60, 26, 22).lerp(Color8(96, 40, 30), edge)
			elif d < pr:
				col = col.darkened(0.35 * (1.0 - (d - ur) / (pr - ur)))
			draw_rect(Rect2(p.floor(), Vector2(step, step)), col)
			x += step
		y += step
