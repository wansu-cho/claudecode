extends Control
## 망원경으로 본 북쪽 하늘입니다. (실제 별 위치, 시간이 흐르면 별이 돕니다)
##
## 할 수 있는 일
##   1) 북극성 찾기
##      - 북두칠성: 국자 끝 두 별(메라크 → 두베)을 누르면 길잡이 선이 5배로 늘어남
##      - 카시오페이아자리: W의 바깥 두 변을 누르면 만나는 점이 생기고, 가운데 별을 누르면 5배 선
##      - 길잡이 선 끝 근처의 북극성을 누르면 성공
##   2) 사진 찍기: 1시간 이상 간격으로 두 장을 찍으면 별이 도는 것을 비교할 수 있음

signal closed
signal message(text: String)

const K := 4.3
const HY := 325.0
const CX := 320.0
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
var _compare_t := -1.0
var _compare_old := {}
var _status := ""
var _status_t := 0.0
var _t := 0.0
var _opened_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	var row := HBoxContainer.new()
	row.position = Vector2(430, 330)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var photo := Pal.button("사진 찍기")
	photo.pressed.connect(take_photo)
	row.add_child(photo)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_refresh_positions()
	if Astro.hidden(Astro.star_altaz("dubhe", Game.minutes)) and Astro.star_altaz("navi", Game.minutes).x > 10.0:
		if Game.add_fact("dipper_low"):
			say("북두칠성이 북쪽 산 뒤에 숨어 있다… 대신 W자 모양 별자리가 높이 떠 있다. (관측 일지에 기록)")
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
			pos[id] = SkyPainter.to_screen(aa, CX, HY, K)


func _process(delta: float) -> void:
	_t += delta
	_status_t = maxf(_status_t - delta, 0.0)
	if guide_t >= 0.0 and guide_t < GUIDE_TIME:
		guide_t += delta
	if _compare_t >= 0.0:
		_compare_t += delta
		if _compare_t > 6.0:
			_compare_t = -1.0
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
		elif event.keycode == KEY_P:
			get_viewport().set_input_as_handled()
			take_photo()


func press(p: Vector2) -> void:
	if guide_t >= 0.0 and guide_t < GUIDE_TIME:
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
		say("찾았다! 길잡이 선이 가리키는 별, 북극성이다. 이쪽이 북쪽! (관측 일지에 기록)")
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


# ---- 사진 ----

func take_photo() -> void:
	var shot := {"m": Game.minutes, "pos": {}}
	for id in ["polaris", "kochab", "dubhe", "merak", "alkaid", "caph", "schedar", "navi", "segin", "capella", "deneb", "vega", "mirfak"]:
		var aa := Astro.star_altaz(id, Game.minutes)
		shot["pos"][id] = SkyPainter.to_screen(aa, CX, HY, K)
	var photos: Array = Game.night["photos"]
	var older := {}
	for ph in photos:
		if Game.minutes - float(ph["m"]) >= 60.0:
			older = ph
			break
	photos.append(shot)
	if older.is_empty():
		if photos.size() == 1:
			say("찰칵! %s의 북쪽 하늘을 찍었다. 시간이 지난 뒤 다시 찍어 비교해 보자." % Game.clock())
		else:
			say("찰칵! 그런데 앞 사진과 시간 차이가 너무 작다. 1시간쯤 지나서 찍어 보자.")
		return
	_compare_old = older
	_compare_t = 0.0
	var hours := (Game.minutes - float(older["m"])) / 60.0
	if Game.add_fact("star_trail"):
		say("두 사진 비교: %.1f시간 동안 별들이 북극성 근처를 중심으로 약 %d도 돌았다! (관측 일지에 기록)" % [hours, roundi(hours * 15.0)])
	else:
		say("두 사진 비교: %.1f시간 동안 약 %d도 돌았다." % [hours, roundi(hours * 15.0)])


func close() -> void:
	closed.emit()
	queue_free()


# ---- 그리기 ----

func _draw() -> void:
	SkyPainter.draw(self, Game.minutes, Pal.SCREEN, HY, K, CX)
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
	if _compare_t >= 0.0:
		_draw_compare()
	# 망원경 테두리 느낌
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	draw_string(get_theme_default_font(), Vector2(10, 15), "망원경 · 북쪽 하늘 · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	if _status_t > 0.0:
		var r := Rect2(10, 302, 410, 46)
		draw_rect(r, Pal.PANEL)
		draw_rect(r, Pal.LINE, false, 1.0)
		var lbl_font := get_theme_default_font()
		draw_multiline_string(lbl_font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)


func _draw_guide(a: Vector2, b: Vector2, progress: float) -> void:
	draw_line(a, b, Pal.GOLD, 1)
	var step := b - a
	Pal.dotted(self, b, b + step * 5.0 * progress, Pal.CYAN, 3)
	var font := get_theme_default_font()
	for k in range(1, 6):
		if float(k) / 5.0 > progress + 0.001:
			break
		var p := b + step * k
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Pal.CYAN)
		draw_string(font, p + Vector2(4, -3), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)


func _draw_compare() -> void:
	var a := clampf(_compare_t / 0.5, 0.0, 1.0) * clampf((6.0 - _compare_t) / 1.0, 0.0, 1.0)
	var old: Dictionary = _compare_old["pos"]
	for id in old:
		var p0: Vector2 = old[id]
		var p1 := SkyPainter.to_screen(Astro.star_altaz(id, Game.minutes), CX, HY, K)
		Pal.ring(self, p0, 3, Color(Pal.PINK, a))
		Pal.dotted(self, p0, p1, Color(Pal.PINK, a * 0.8), 2)
	draw_string(get_theme_default_font(), Vector2(10, 40), "분홍 = %s에 찍은 사진의 별 위치" % Game.clock(float(_compare_old["m"])), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(Pal.PINK, a))
