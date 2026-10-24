extends Control
## 옥상 돔 안의 큰 망원경입니다.
##   남쪽 하늘: 겨울철 남쪽 하늘(오리온자리, 시리우스)과, 수평선 바로 위의 노인성(카노푸스)
##             노인성은 23:25 ~ 02:25에만 수평선 위로 뜹니다. (가장 높을 때 00:55, 고도 약 3°)
##   관측 기록 보관함: 지난 개기월식 사진 3장 (모두 보면 '언제나 둥근 그림자')

signal closed

const K := 5.0
const HY := 318.0
const CX := 320.0
const STAR_HIT := 12.0
## 실제로 우리나라에서 볼 수 있었던 개기월식 (날짜는 한국 시각)
const ECLIPSES := [
	{"date": "2018년 1월 31일 22:30", "shadow": Vector2(-0.55, -0.70)},
	{"date": "2022년 11월 8일 19:59", "shadow": Vector2(0.75, -0.45)},
	{"date": "2025년 9월 8일 03:11", "shadow": Vector2(-0.80, 0.35)},
]
const NAMES := {
	"sirius": "시리우스 (밤하늘에서 가장 밝은 별)", "betelgeuse": "베텔게우스 (오리온자리의 붉은 별)", "rigel": "리겔 (오리온자리의 푸른 별)",
	"procyon": "프로키온", "aldebaran": "알데바란 (황소자리)", "alnilam": "오리온자리 허리띠의 별",
	"alnitak": "오리온자리 허리띠의 별", "mintaka": "오리온자리 허리띠의 별",
}

var mode := "south"
var pos := {}
var _seen: Dictionary = {}
var _zoom := -1
var _status := ""
var _opened_at := 0
var _sky_btn: Button
var _arc_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	_seen = Game.night.get("eclipse_seen", {})
	Game.night["eclipse_seen"] = _seen
	var row := HBoxContainer.new()
	row.position = Vector2(300, 338)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_sky_btn = Pal.button("남쪽 하늘")
	_sky_btn.pressed.connect(func(): _set_mode("south"))
	row.add_child(_sky_btn)
	_arc_btn = Pal.button("관측 기록 보관함")
	_arc_btn.pressed.connect(func(): _set_mode("archive"))
	row.add_child(_arc_btn)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_set_mode("south")


func _set_mode(m: String) -> void:
	mode = m
	_zoom = -1
	if m == "south":
		_status = "돔 망원경이 남쪽 하늘을 향했다. 수평선 근처를 잘 살펴보자. 별을 누르면 이름을 알려 준다."
	else:
		_status = "선생님이 찍어 둔 개기월식 사진이 있다. 사진을 눌러 자세히 보자."
	queue_redraw()


func close() -> void:
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if mode == "south":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Time.get_ticks_msec() - _opened_at > 300:
			press(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func press(p: Vector2) -> void:
	if mode == "south":
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
		queue_redraw()
		return
	for i in ECLIPSES.size():
		if _card_rect(i).has_point(p):
			view_photo(i)
			return
	_zoom = -1
	queue_redraw()


func look_canopus() -> void:
	if Game.add_fact("canopus"):
		_status = "수평선 바로 위에 붉게 빛나는 별, 노인성(카노푸스)이다! 서울에서는 거의 볼 수 없는 별이다. (관측 일지에 기록)"
	else:
		_status = "노인성(카노푸스). 이 섬처럼 남쪽에서만 보이는 별이다."


func view_photo(i: int) -> void:
	_zoom = i
	_seen[i] = true
	if _seen.size() >= ECLIPSES.size():
		if Game.add_fact("eclipse_round"):
			_status = "세 번의 월식 모두, 지구 그림자의 가장자리가 둥근 곡선이다! (관측 일지에 기록)"
		else:
			_status = "세 번 모두 둥근 그림자다."
	else:
		_status = "%s 개기월식. 달에 비친 지구 그림자의 가장자리를 보자. (본 사진 %d/3)" % [ECLIPSES[i]["date"], _seen.size()]
	queue_redraw()


func _card_rect(i: int) -> Rect2:
	return Rect2(40 + i * 190, 60, 170, 190)


# ---- 그리기 ----

func _draw() -> void:
	var font := get_theme_default_font()
	if mode == "south":
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
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color8(24, 20, 36))
		for i in ECLIPSES.size():
			_draw_photo(i)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(10, 15), "돔 망원경 · %s · %s" % ["남쪽 하늘" if mode == "south" else "관측 기록 보관함", Game.clock()], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var r := Rect2(10, 262, 620, 34) if mode == "archive" else Rect2(10, 26, 620, 34)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	draw_multiline_string(font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 2, Pal.TEXT)


## 월식 사진: 달(밝은 원) 위에 지구 그림자(큰 원)가 겹친 모습
func _draw_photo(i: int) -> void:
	var r := _card_rect(i)
	var zoomed := i == _zoom
	draw_rect(r, Color8(6, 6, 12))
	draw_rect(r, Pal.GOLD if zoomed else Pal.LINE, false, 1.0)
	var c := r.get_center() + Vector2(0, -12)
	var moon_r := 54.0
	var sh: Vector2 = ECLIPSES[i]["shadow"]
	var shadow_r := moon_r * 2.6               # 지구 그림자(본그림자)는 달보다 약 2.6배 큽니다
	var shadow_c := c + sh.normalized() * (shadow_r - moon_r * 0.35)   # 그림자 가장자리가 달을 가로지르는 순간
	for y in range(int(-moon_r), int(moon_r) + 1, 2):
		var half := sqrt(maxf(moon_r * moon_r - y * y, 0.0))
		var x := -half
		while x <= half:
			var p := c + Vector2(x, y)
			var inside := p.distance_to(shadow_c) < shadow_r
			var col := Color8(120, 40, 30) if inside else Color8(236, 232, 214)
			draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
			x += 2.0
	draw_string(get_theme_default_font(), Vector2(r.position.x + 8, r.end.y - 10), ECLIPSES[i]["date"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, Pal.SMALL, Pal.GOLD if _seen.has(i) else Pal.DIM)
