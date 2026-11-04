extends Control
## 옥상 돔 안의 큰 망원경 (Meade LX200 ACF 16인치: 구경 406mm, f/10, 초점거리 4064mm)
##   남쪽 하늘: 겨울철 남쪽 하늘(오리온자리, 시리우스)과, 수평선 바로 위의 카노푸스(노인성)
##             카노푸스는 23:38 ~ 03:16에만 수평선 위로 뜹니다. (가장 높을 때 01:27, 고도 약 3°)
##   별을 누르면 망원경을 그쪽으로 돌려 크게 봅니다. 26mm 접안렌즈: 약 156배, 실제 시야 약 0.33°
##     카노푸스, 시리우스, 베텔게우스, 리겔: 아무리 키워도 점 (별은 너무 멀어서)
##     오리온대성운(M42): 별이 태어나는 가스 구름, 가운데 트라페지움 네 별
##   관측 전에는 그리스 이름 '카노푸스'로만 부르고, 크게 본 뒤에 우리 옛 이름 '노인성'을 알게 됩니다.

signal closed

## 남쪽 하늘: 남쪽 고도 30°를 향한 심사 투영 (지평선이 화면 아래 y = 318)
var proj := SkyPainter.gno(180.0, 30.0, 274.0, Vector2(320, 160))
const STAR_HIT := 12.0
const EYE_C := Vector2(320, 196)
const EYE_R := 130.0
const NAMES := {
	"procyon": "프로키온 (작은개자리)", "aldebaran": "알데바란 (황소자리의 붉은 별)", "alnilam": "오리온자리 허리띠의 별",
	"alnitak": "오리온자리 허리띠의 별", "mintaka": "오리온자리 허리띠의 별", "bellatrix": "벨라트릭스 (오리온자리)", "saiph": "사이프 (오리온자리)",
}
## 크게 볼 수 있는 것: [이름, 별 색, 일렁임(낮게 떠서 공기 때문에 색이 바뀜), 설명]
const ZOOM := {
	"canopus": ["카노푸스", Color8(255, 236, 210), true, "약 156배로 크게 봐도 별은 작은 점이다! 너무 멀어서 아무리 키워도 점이다. 수평선에 아주 낮게 떠서 공기 때문에 무지개색으로 일렁인다."],
	"sirius": ["시리우스", Color8(220, 232, 255), true, "밤하늘에서 가장 밝은 별, 시리우스. 크게 봐도 점이다. 아직 낮게 떠서 색이 빠르게 바뀌며 반짝인다."],
	"betelgeuse": ["베텔게우스", Color8(255, 170, 110), false, "베텔게우스. 크게 봐도 점이지만 주황빛이 또렷하다. 표면 온도가 낮은 늙은 별이라 붉게 보인다."],
	"rigel": ["리겔", Color8(190, 215, 255), false, "리겔. 푸르스름한 흰빛의 점이다. 표면이 아주 뜨거운 별이라 푸르게 보인다."],
	"m42": ["오리온대성운 (M42)", Color.WHITE, false, "오리온대성운. 별이 태어나는 거대한 가스 구름이다. 가운데 사다리꼴로 모인 네 별이 트라페지움!"],
}

var mode := "south"
var zoom_id := ""
var pos := {}
var _status := ""
var _opened_at := 0
var _back_btn: Button
var _m42: Texture2D = load("res://assets/views/m42.png")
var _scope: Texture2D = load("res://assets/views/lx200.png")
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	var row := HBoxContainer.new()
	row.position = Vector2(440, 338)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_back_btn = Pal.button("남쪽 하늘로")
	_back_btn.pressed.connect(func(): _set_mode("south"))
	row.add_child(_back_btn)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_set_mode("south")


func _set_mode(m: String) -> void:
	mode = m
	_back_btn.visible = m == "zoom"
	if m == "south":
		_status = "돔이 남쪽 하늘을 향했다. 별을 누르면 큰 망원경을 그쪽으로 돌려 크게 볼 수 있다. 남쪽 수평선 근처도 잘 살펴보자."
	queue_redraw()


func close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Time.get_ticks_msec() - _opened_at > 300:
			press(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if mode == "zoom":
			_set_mode("south")
		else:
			close()


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
	if ZOOM.has(best):
		look(best)
	elif NAMES.has(best):
		_status = NAMES[best] + "."
	elif best != "":
		_status = "밝은 별이다."
	elif p.y > SkyPainter.horizon_y(proj) - 30 and absf(p.x - 320.0) < 80:
		_status = "남쪽 수평선 근처에는 아직 아무것도 보이지 않는다." if not pos.has("canopus") else "수평선 바로 위에 붉은 별이 있다. 눌러 보자!"


## 망원경을 돌려 크게 봅니다
func look(id: String) -> void:
	zoom_id = id
	_set_mode("zoom")
	_status = ZOOM[id][3]
	if id == "canopus":
		var hwi := Game.woken.has("hwi")
		var name_line := "휘: \"그건 노인성(老人星)이오! 노인성이 보이면 나라가 태평하다 하였소. 내 고향에선 귀한 별이지.\"" if hwi \
				else "책방 교재에서 읽은 이름이 떠오른다. 우리 옛사람들은 이 별을 '노인성(老人星)'이라 불렀다."
		_status += "  " + name_line
		if Game.add_fact("canopus"):
			_status += "  서울에서는 거의 볼 수 없는 별인데… 무슨 뜻일까? (나가서 생각해 보자)"


## 하위 호환 (예전 이름)
func look_canopus() -> void:
	look("canopus")


# ---- 그리기 ----

func _draw() -> void:
	var font := get_theme_default_font()
	if mode == "south":
		_draw_south(font)
	else:
		_draw_zoom(font)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 22), Color(0, 0, 0, 0.6))
	var head: String = "돔 망원경 · 남쪽 하늘" if mode == "south" else "돔 망원경 (LX200 16인치, 약 156배) · " + ZOOM[zoom_id][0]
	draw_string(font, Vector2(10, 15), "%s · %s" % [head, Game.clock()], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var r := Rect2(10, 26, 620, 48 if mode == "zoom" else 34)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	draw_multiline_string(font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)


func _draw_south(font: Font) -> void:
	pos = SkyPainter.draw(self, Game.minutes, Pal.SCREEN, proj)
	var hy := SkyPainter.horizon_y(proj)
	draw_rect(Rect2(0, hy, Pal.SCREEN.x, Pal.SCREEN.y - hy), Color8(16, 12, 30))
	var line_c := Color(0.55, 0.55, 0.85, 0.35 * Astro.darkness(Game.minutes))
	for l in Astro.ORION_LINES:
		if pos.has(l[0]) and pos.has(l[1]):
			Pal.dotted(self, pos[l[0]], pos[l[1]], line_c, 3)
	if pos.has("m42"):                                   # 오리온 칼에 붙은 뿌연 빛
		draw_circle(pos["m42"], 3.5, Color(0.7, 0.85, 0.8, 0.35))
	if pos.has("canopus") and Game.has("canopus"):
		Pal.ring(self, pos["canopus"], 7, Pal.GOLD)
		draw_string(font, pos["canopus"] + Vector2(10, -6), "노인성 (카노푸스)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	for d in [[135.0, "남동"], [180.0, "남"], [225.0, "남서"]]:
		var p := SkyPainter.project(Vector2(0.0, d[0]), proj)
		draw_string(font, Vector2(clampf(p.x - 8, 4.0, 600.0), hy + 14), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	# 앞쪽에 돔 안의 큰 망원경 (실루엣)
	var sz := Vector2(_scope.get_width(), _scope.get_height()) / (168.0 / 40.0) * 1.6
	draw_texture_rect(_scope, Rect2(Vector2(Pal.SCREEN.x - sz.x - 6, Pal.SCREEN.y - sz.y - 28), sz), false, Color(0.45, 0.45, 0.6))


func _draw_zoom(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(2, 2, 6))
	var item: Array = ZOOM[zoom_id]
	if zoom_id == "m42":
		var s := EYE_R * 2.2
		draw_texture_rect(_m42, Rect2(EYE_C - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	else:
		var col: Color = item[1]
		if item[2]:                                       # 낮은 별: 공기 때문에 색이 빠르게 바뀌며 일렁임
			col = Color.from_hsv(fmod(_t * 2.7, 1.0), 0.35, 1.0).lerp(col, 0.5)
		var jit := Vector2(sin(_t * 23.0), cos(_t * 19.0)) * (1.2 if item[2] else 0.2)
		draw_circle(EYE_C + jit, 7.0, Color(col, 0.12))
		draw_circle(EYE_C + jit, 3.5, Color(col, 0.35))
		draw_circle(EYE_C + jit, 1.6, col)
		for i in 14:                                      # 시야 속 어두운 별 몇 개
			var q := EYE_C + Vector2(fposmod(i * 61.0, 240.0) - 120.0, fposmod(i * 47.0, 220.0) - 110.0)
			if q.distance_to(EYE_C) < EYE_R - 6:
				draw_circle(q, 0.7, Color(1, 1, 1, 0.5))
	draw_arc(EYE_C, EYE_R + 120.0, 0.0, TAU, 96, Color8(2, 2, 6), 240.0)   # 둥근 시야 밖은 검게
	draw_arc(EYE_C, EYE_R, 0.0, TAU, 96, Color8(50, 50, 70), 2.0)
	draw_string(font, EYE_C + Vector2(-EYE_R, EYE_R + 14), "시야 약 0.33° (보름달 지름의 3분의 2)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
