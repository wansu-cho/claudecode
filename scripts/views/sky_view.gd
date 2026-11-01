extends Control
## 망원경으로 본 북쪽 하늘입니다. (실제 별 위치, 시간이 흐르면 별이 돕니다)
## 심사 투영으로 그려서 별자리 모양과 '두 별을 이어 늘인 선'이 실제 하늘과 같습니다.
##
## 할 수 있는 일
##   1) 북극성 찾기
##      - 북두칠성: 국자 끝 두 별(메라크 → 두베)을 누르면 길잡이 선이 5배로 늘어남
##      - 카시오페이아자리: W의 바깥 두 변을 누르면 만나는 점이 생기고, 가운데 별을 누르면 5배 선
##      - 길잡이 선 끝 근처의 북극성을 누르면 성공
##      실제 하늘에서 국자 끝 두 별 사이를 약 5.3배, W자 쪽은 약 5.0배 가면 북극성입니다. (어긋남 2° 이내)
##      게임에서는 길잡이 선이 북극성에서 끝나도록, 눈금 다섯 칸을 북극성까지 고르게 나눕니다.
##   2) 1시간 장노출: 3초 동안 1시간이 흐르며 별 궤적(일주운동)이 그려짐 → '도는 하늘'

signal closed
signal message(text: String)

const F := 200.0                 # 화면 픽셀 ÷ 라디안 (가운데에서 1°가 약 3.5픽셀)
const VIEW_ALT := 38.0           # 망원경이 북쪽 하늘 고도 38°를 향함 (북극성 34°, 카시오페이아자리는 64°까지 올라감)
const EXPOSE_MIN := 60.0
const EXPOSE_SEC := 3.5
const STAR_HIT := 12.0
const LINE_HIT := 7.0
const GUIDE_TIME := 2.0
const CAS_SIDES := {"outer_a": ["caph", "schedar"], "inner_a": ["schedar", "navi"], "inner_b": ["navi", "ruchbah"], "outer_b": ["segin", "ruchbah"]}

var pos := {}                  # 지금 보이는 별의 화면 위치
var dip_picked: Array = []
var cas_sides: Array = []
var cas_navi := false
var guide_kind := ""           # 다 그린 길잡이 선: "dip" 또는 "cas"
var guide_t := -1.0
var proj := SkyPainter.gno(0.0, VIEW_ALT, F, Vector2(320, 180))
var _exp_t := -1.0             # 장노출 진행 (초), -1이면 쉬는 중
var _exp_from := -1.0          # 장노출을 시작한 게임 시각 (궤적을 남겨 보여 줌)
var _exp_to := -1.0
var _exp_btn: Button
var _status := ""
var _status_t := 0.0
var _t := 0.0
var _opened_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	var row := HBoxContainer.new()
	row.position = Vector2(410, 330)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_exp_btn = Pal.button("1시간 장노출")
	_exp_btn.pressed.connect(long_exposure)
	row.add_child(_exp_btn)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_refresh_positions()
	if Astro.hidden(Astro.star_altaz("dubhe", Game.minutes)) and Astro.star_altaz("navi", Game.minutes).x > 10.0:
		if Game.add_fact("dipper_low"):
			say("북두칠성이 보이지 않는다. 북쪽 산 위로 W자 모양 별자리가 높이 떠 있다.")
		else:
			say("북두칠성은 아직 산 뒤에 숨어 있다. W자 별자리를 이용해 보자.")
	else:
		say("북극성을 찾아보자. 북두칠성 국자 끝 두 별, 또는 W자의 바깥 두 변을 눌러 보자.")


func say(text: String) -> void:
	_status = text
	_status_t = 6.0
	message.emit(text)


func _refresh_positions() -> void:
	pos.clear()
	for id in Astro.STARS:
		var aa := Astro.star_altaz(id, Game.minutes)
		if aa.x > 0.0 and not Astro.hidden(aa):
			var p := SkyPainter.project(aa, proj)
			if p != SkyPainter.OFF:
				pos[id] = p


func _process(delta: float) -> void:
	_t += delta
	_status_t = maxf(_status_t - delta, 0.0)
	if guide_t >= 0.0 and guide_t < GUIDE_TIME:
		guide_t += delta
	if _exp_t >= 0.0:
		_exp_t += delta
		var k := clampf(_exp_t / EXPOSE_SEC, 0.0, 1.0)
		Game.minutes = _exp_from + (_exp_to - _exp_from) * k
		if k >= 1.0:
			_exp_t = -1.0
			Game.unfreeze()
			_exp_btn.disabled = false
			if Game.add_fact("star_trail"):
				say("사진 속 별들이 모두 한 점을 가운데 두고 원을 그렸다. 가운데 별은 거의 점으로 찍혔다. 무슨 뜻일까? (나가서 생각해 보자)")
			else:
				say("별들이 북극성을 가운데 두고 둥글게 돌았다.")
	_refresh_positions()
	queue_redraw()


# ---- 누르기 ----

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
		elif event.keycode == KEY_L:
			get_viewport().set_input_as_handled()
			long_exposure()


func press(p: Vector2) -> void:
	if _exp_t >= 0.0 or (guide_t >= 0.0 and guide_t < GUIDE_TIME):
		return
	var star := _star_at(p)
	if star == "polaris":
		_try_polaris()
		return
	if star in ["merak", "dubhe"]:
		if star not in dip_picked:
			dip_picked.append(star)
		if dip_picked.size() == 2:
			_start_guide("dip")
		else:
			say("국자 끝 별 하나 확보. 나머지 하나도 눌러 보자.")
		return
	if star == "navi" and cas_sides.size() == 2:
		cas_navi = true
		_start_guide("cas")
		return
	var side := _side_at(p)
	if side != "":
		if side.begins_with("outer"):
			if side not in cas_sides:
				cas_sides.append(side)
			if cas_sides.size() == 2:
				say("두 변을 늘이니 한 점에서 만났다! 이제 W의 가운데 별을 눌러 보자.")
			else:
				say("W의 바깥 변 하나를 늘였다. 반대쪽 바깥 변도 눌러 보자.")
		else:
			say("그건 W의 안쪽 변이다. 양쪽 끝의 '바깥' 변을 찾아보자.")
		return
	if star in Astro.BIG_DIPPER:
		say("국자의 '끝'에 있는 두 별을 찾아보자. (손잡이 반대쪽)")
	elif star in Astro.CASSIOPEIA:
		say("W의 별이다. W 양쪽 끝의 바깥 변을 눌러 보자.")
	elif star != "":
		say("밝은 별이지만, 북극성을 찾는 데 쓰는 별은 아니다.")


func _try_polaris() -> void:
	if guide_kind == "":
		say("저 별이 북극성일까? 길잡이 선을 먼저 그려서 확인해 보자.")
		return
	var fact := "polaris_dip" if guide_kind == "dip" else "polaris_cas"
	if Game.add_fact(fact):
		say("찾았다! 길잡이 선이 가리키는 별, 북극성이다. 이쪽이 북쪽!")
	else:
		say("북극성이다. 이 방법은 이미 일지에 적어 두었다.")
	Game.night["polaris_seen"] = true


func _start_guide(kind: String) -> void:
	guide_kind = kind
	guide_t = 0.0
	say("두 점 사이 거리를 5배로 늘여 보자…")


func _star_at(p: Vector2) -> String:
	var best := ""
	var best_d := STAR_HIT
	for id in pos:
		var d: float = p.distance_to(pos[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func _side_at(p: Vector2) -> String:
	for id in CAS_SIDES:
		var ab: Array = CAS_SIDES[id]
		if not (pos.has(ab[0]) and pos.has(ab[1])):
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, pos[ab[0]], pos[ab[1]])
		if p.distance_to(q) < LINE_HIT:
			return id
	return ""


func _meet() -> Vector2:
	var a: Vector2 = pos.get("caph", Vector2.ZERO)
	var b: Vector2 = pos.get("schedar", Vector2.ZERO)
	var c: Vector2 = pos.get("segin", Vector2.ZERO)
	var d: Vector2 = pos.get("ruchbah", Vector2.ZERO)
	var hit = Geometry2D.line_intersects_line(a, b - a, c, d - c)
	return hit if hit != null else b


# ---- 장노출 ----

## 카메라 셔터를 1시간 열어 둡니다. 3.5초 동안 시간이 1시간 흐르며 별 궤적이 그려집니다.
func long_exposure() -> void:
	if _exp_t >= 0.0:
		return
	if Astro.darkness(Game.minutes) < 0.6:
		say("하늘이 아직 밝아서 별이 잘 찍히지 않는다. 더 어두워지면 해 보자.")
		return
	if Game.minutes > Game.NIGHT_LEN - EXPOSE_MIN - 1.0:
		say("해가 뜨기 전에 1시간을 찍을 시간이 없다.")
		return
	_exp_from = Game.minutes
	_exp_to = Game.minutes + EXPOSE_MIN
	_exp_t = 0.0
	_exp_btn.disabled = true
	Game.freeze()                 # 장노출 동안은 이 화면이 시간을 직접 흐르게 합니다
	say("셔터를 열었다. 1시간 동안 하늘을 찍는다…")


func close() -> void:
	if _exp_t >= 0.0:
		Game.minutes = _exp_to
		Game.unfreeze()
	closed.emit()
	queue_free()


# ---- 그리기 ----

func _draw() -> void:
	SkyPainter.draw(self, Game.minutes, Pal.SCREEN, proj)
	if _exp_from >= 0.0:
		_draw_trails()
	var dark := Astro.darkness(Game.minutes)
	var line_c := Color(0.55, 0.55, 0.85, 0.35 * dark)
	for l in Astro.BIG_DIPPER_LINES + Astro.CASSIOPEIA_LINES:
		if pos.has(l[0]) and pos.has(l[1]):
			Pal.dotted(self, pos[l[0]], pos[l[1]], line_c, 3)
	for id in dip_picked:
		if pos.has(id):
			Pal.ring(self, pos[id], 5, Pal.GOLD)
	for side in cas_sides:
		var ab: Array = CAS_SIDES[side]
		if pos.has(ab[0]) and pos.has(ab[1]):
			draw_line(pos[ab[0]], pos[ab[1]], Pal.GOLD, 1)
			Pal.dotted(self, pos[ab[1]], _meet(), Pal.CYAN, 2)
	if cas_sides.size() == 2:
		var mp := _meet()
		draw_rect(Rect2(mp - Vector2(2, 0), Vector2(5, 1)), Pal.GOLD)
		draw_rect(Rect2(mp - Vector2(0, 2), Vector2(1, 5)), Pal.GOLD)
	if guide_t >= 0.0:
		var a: Vector2
		var b: Vector2
		if guide_kind == "dip":
			a = pos.get("merak", Vector2.ZERO)
			b = pos.get("dubhe", Vector2.ZERO)
		else:
			a = _meet()
			b = pos.get("navi", Vector2.ZERO)
		_draw_guide(a, b, clampf(guide_t / GUIDE_TIME, 0.0, 1.0))
	if Game.night.get("polaris_seen", false) and pos.has("polaris"):
		Pal.ring(self, pos["polaris"], 7, Pal.GOLD)
		draw_string(get_theme_default_font(), pos["polaris"] + Vector2(10, -6), "북극성", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 망원경 테두리 느낌
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(get_theme_default_font(), Vector2(10, 15), "망원경 · 북쪽 하늘 · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	if _status_t > 0.0:
		var r := Rect2(10, 302, 392, 46)
		draw_rect(r, Pal.PANEL)
		draw_rect(r, Pal.LINE, false, 1.0)
		var lbl_font := get_theme_default_font()
		draw_multiline_string(lbl_font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)


## 길잡이 선: 두 점(a → b)을 이은 선을 b에서 북극성까지 늘이고, 다섯 칸으로 나눕니다.
func _draw_guide(a: Vector2, b: Vector2, progress: float) -> void:
	draw_line(a, b, Pal.GOLD, 1)
	var target: Vector2 = pos.get("polaris", b + (b - a) * 5.0)
	var step := (target - b) / 5.0
	Pal.dotted(self, b, b + step * 5.0 * progress, Pal.CYAN, 3)
	var font := get_theme_default_font()
	for k in range(1, 6):
		if float(k) / 5.0 > progress + 0.001:
			break
		var p := b + step * k
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Pal.CYAN)
		draw_string(font, p + Vector2(4, -3), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)


## 장노출 궤적: 장노출을 시작한 때부터 지금(또는 끝난 때)까지 별이 지나간 길
func _draw_trails() -> void:
	var to := minf(Game.minutes, _exp_to)
	var steps := 24
	var dark := Astro.darkness(Game.minutes)
	var stars := []
	for id in Astro.STARS:
		var rd: Vector2 = Astro.star_radec(id)
		stars.append([rd.x, rd.y, 0.9])
	for f in Astro.field():
		if f[2] > 0.45:
			stars.append(f)
	for st in stars:
		var pts := PackedVector2Array()
		for i in steps + 1:
			var t: float = _exp_from + (to - _exp_from) * i / steps
			var aa := Astro.altaz(st[0], st[1], t)
			if aa.x <= 0.0 or Astro.hidden(aa):
				break
			var p := SkyPainter.project(aa, proj)
			if p == SkyPainter.OFF:
				break
			pts.append(p)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.55 * st[2] * dark), 1.0)
