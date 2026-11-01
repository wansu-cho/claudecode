extends Control
## 옥상 돔 안의 큰 망원경입니다.
##   남쪽 하늘: 겨울철 남쪽 하늘(오리온자리, 시리우스)과, 수평선 바로 위의 노인성(카노푸스)
##             노인성은 23:38 ~ 03:16에만 수평선 위로 뜹니다. (가장 높을 때 01:27, 고도 약 3°)
##   달: 오늘 밤의 개기월식을 크게 보고 사진을 찍습니다.
##       부분식 21:22 ~ 22:20, 개기식 22:20 ~ 23:52, 부분식 23:52 ~ 00:50
##       그림자 가장자리가 보이는 부분식 때 20분 이상 간격으로 3장을 찍으면 '언제나 둥근 그림자'

signal closed

const K := 5.0
const HY := 318.0
const CX := 320.0
const STAR_HIT := 12.0
const PHOTO_GAP := 20.0          # 사진 사이 최소 간격 (게임 분)
const PHOTOS_NEEDED := 3
const MOON_C := Vector2(320, 150)
const MOON_PX := 70.0            # 망원경 속 달의 반지름 (픽셀)
const NAMES := {
	"sirius": "시리우스 (밤하늘에서 가장 밝은 별)", "betelgeuse": "베텔게우스 (오리온자리의 붉은 별)", "rigel": "리겔 (오리온자리의 푸른 별)",
	"procyon": "프로키온", "aldebaran": "알데바란 (황소자리)", "alnilam": "오리온자리 허리띠의 별",
	"alnitak": "오리온자리 허리띠의 별", "mintaka": "오리온자리 허리띠의 별",
}

var mode := "south"
var pos := {}
var _photos: Array
var _status := ""
var _status_t := 0.0              # 달 화면: 사진 결과를 잠깐 보여 주는 시간 (초)
var _opened_at := 0
var _photo_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	_photos = Game.night.get("ecl_photos", [])
	Game.night["ecl_photos"] = _photos
	var row := HBoxContainer.new()
	row.position = Vector2(300, 338)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var sky_btn := Pal.button("남쪽 하늘")
	sky_btn.pressed.connect(func(): _set_mode("south"))
	row.add_child(sky_btn)
	var moon_btn := Pal.button("달")
	moon_btn.pressed.connect(func(): _set_mode("moon"))
	row.add_child(moon_btn)
	_photo_btn = Pal.button("사진 찍기")
	_photo_btn.pressed.connect(take_photo)
	row.add_child(_photo_btn)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_set_mode("south")


func _set_mode(m: String) -> void:
	mode = m
	_photo_btn.visible = m == "moon"
	if m == "south":
		_status = "돔 망원경이 남쪽 하늘을 향했다. 수평선 근처를 잘 살펴보자. 별을 누르면 이름을 알려 준다."
	else:
		_status_t = 0.0
	queue_redraw()


func _moon_status() -> String:
	var m := Game.minutes
	if Astro.moon_altaz(m).x < 5.0:
		return "달이 아직 낮게 떠 있어 돔 창으로 보이지 않는다."
	match Astro.eclipse_phase(m):
		"partial":
			return "달 한쪽이 지구 그림자에 먹혀 들어가 있다! 그림자의 가장자리를 사진으로 남기자."
		"total":
			return "달 전체가 지구 그림자 속에 들어가 붉은 구릿빛으로 보인다. 지금은 그림자 가장자리가 보이지 않는다."
	if m < Game.at(Astro.ECL_MID):
		return "둥글고 밝은 보름달이다. 휘의 말로는 오늘 밤 21시 20분 무렵부터 달이 먹히기 시작한다고 했다."
	return "월식이 끝나고 다시 둥근 보름달이 되었다."


func close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_status_t = maxf(_status_t - delta, 0.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Time.get_ticks_msec() - _opened_at > 300:
			press(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif event.keycode == KEY_P and mode == "moon":
			get_viewport().set_input_as_handled()
			take_photo()


func press(p: Vector2) -> void:
	if mode != "south":
		return
	var best := ""
	var best_d := STAR_HIT
	for id in pos:
		var d: float = p.distance_to(pos[id])
		if d < best_d:
			best_d = d
			best = id
	if best == "canopus":
		look_canopus()
	elif NAMES.has(best):
		_status = NAMES[best] + "."
	elif best != "":
		_status = "밝은 별이다."
	elif p.y > HY - 30 and absf(p.x - CX) < 80:
		_status = "남쪽 수평선 근처에는 아직 아무것도 보이지 않는다." if not pos.has("canopus") else "수평선 바로 위에 붉은 별이 있다. 눌러 보자!"


func look_canopus() -> void:
	if Game.add_fact("canopus"):
		_status = "수평선 바로 위에 붉게 빛나는 별, 노인성(카노푸스)이다! 아테네나 서울처럼 더 북쪽에서는 볼 수 없는 별이다. (관측 일지에 기록)"
	else:
		_status = "노인성(카노푸스). 이 섬처럼 남쪽에서만 보이는 별이다."


## 지금 달의 사진을 찍습니다. 그림자 가장자리가 보이는 부분식 때만 기록이 됩니다.
func take_photo() -> void:
	if mode != "moon":
		return
	var m := Game.minutes
	if Astro.moon_altaz(m).x < 5.0:
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
		_say("세 장 모두, 그림자가 달의 어느 부분을 지나든 가장자리가 둥근 곡선이다! (관측 일지에 기록)")
	else:
		_say("찰칵! 이번에도 둥근 그림자다.")


func _say(text: String) -> void:
	_status = text
	_status_t = 5.0


# ---- 그리기 ----

func _draw() -> void:
	var font := get_theme_default_font()
	if mode == "south":
		_draw_south(font)
	else:
		_draw_moon_view(font)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(10, 15), "돔 망원경 · %s · %s" % ["남쪽 하늘" if mode == "south" else "달", Game.clock()], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var r := Rect2(10, 26, 620, 34)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	var text := _status if mode == "south" or _status_t > 0.0 else _moon_status()
	draw_multiline_string(font, r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 2, Pal.TEXT)


func _draw_south(font: Font) -> void:
	pos = SkyPainter.draw(self, Game.minutes, Pal.SCREEN, HY, K, CX, 180.0)
	draw_rect(Rect2(0, HY, Pal.SCREEN.x, Pal.SCREEN.y - HY), Color8(16, 12, 30))
	var line_c := Color(0.55, 0.55, 0.85, 0.35 * Astro.darkness(Game.minutes))
	for l in Astro.ORION_LINES:
		if pos.has(l[0]) and pos.has(l[1]):
			Pal.dotted(self, pos[l[0]], pos[l[1]], line_c, 3)
	if Game.has("canopus") and pos.has("canopus"):
		Pal.ring(self, pos["canopus"], 7, Pal.GOLD)
		draw_string(font, pos["canopus"] + Vector2(10, -6), "노인성", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	draw_string(font, Vector2(CX - 6, HY + 13), "남", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(font, Vector2(CX - 45.0 * K - 12, HY + 14), "남동", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(font, Vector2(CX + 45.0 * K - 12, HY + 14), "남서", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)


func _draw_moon_view(font: Font) -> void:
	var m := Game.minutes
	draw_rect(Rect2(Vector2.ZERO, size), Color8(6, 6, 14))
	var aa := Astro.moon_altaz(m)
	if aa.x >= 5.0:
		_draw_moon(MOON_C, MOON_PX, m)
		draw_string(font, MOON_C + Vector2(-MOON_PX - 40, -MOON_PX + 4), "북 ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
		draw_string(font, MOON_C + Vector2(-MOON_PX - 40, -MOON_PX + 20), "← 동", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
		draw_string(font, Vector2(470, 90), "달의 높이 %d°" % roundi(aa.x), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	# 찍은 사진
	for i in PHOTOS_NEEDED:
		var r := Rect2(14 + i * 74, 250, 66, 82)
		draw_rect(r, Color8(16, 14, 28))
		draw_rect(r, Pal.LINE, false, 1.0)
		if i < _photos.size():
			var pm: float = _photos[i]["m"]
			_draw_moon(r.position + Vector2(33, 34), 22.0, pm)
			draw_string(font, Vector2(r.position.x + 12, r.end.y - 6), Game.clock(pm), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
		else:
			draw_string(font, Vector2(r.position.x + 22, r.position.y + 44), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)


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
				# 본그림자 안: 개기식이면 붉은 구릿빛, 부분식이면 어둡게 (가장자리 쪽이 조금 밝음)
				var edge := clampf(d / ur, 0.0, 1.0)
				col = Color8(120, 46, 30).lerp(Color8(176, 84, 52), edge * edge) if total else Color8(60, 26, 22).lerp(Color8(96, 40, 30), edge)
			elif d < pr:
				col = col.darkened(0.35 * (1.0 - (d - ur) / (pr - ur)))
			draw_rect(Rect2(p.floor(), Vector2(step, step)), col)
			x += step
		y += step
