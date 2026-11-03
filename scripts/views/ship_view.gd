extends Control
## 부두 쌍안경으로 본 바다입니다.
## 섬 연락선이 19:30에 떠나 북쪽으로 멀어집니다. (시속 약 15 km)
## 지구가 둥글기 때문에, 배가 수평선(약 6 km) 너머로 가면 아래부터 가려집니다.
##   가려지는 높이 ≈ (거리 − 6.2 km)² ÷ (2 × 지구 반지름)
## 선체가 가려지고 돛대 불빛만 보이는 모습을 1초 이상 지켜보면 '수평선 너머의 배'를 알게 됩니다.

signal closed

const HY := 200.0                 # 화면 속 수평선
const DEPART := "19:30"
const SPEED_KM_MIN := 0.25        # 분당 0.25 km = 시속 15 km
const EYE_HORIZON_KM := 6.18      # 눈높이 3 m에서 수평선까지 거리
const EARTH_R_KM := 6371.0
const SHIP_LEN_M := 50.0          # 연락선 길이 (그림 비율로 높이가 정해짐)
const MAST_AT := 0.32             # 돛대가 배 가운데에서 오른쪽으로 떨어진 비율 (배 길이 기준)
const MAST_M := 14.7              # 돛대 꼭대기 불빛 높이 (그림: 길이 1559 : 높이 460)
const CABIN_M := 7.0
const HULL_M := 4.0

var _status := ""
var _ferry: Texture2D = load("res://assets/backgrounds/ferry.png")
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := Pal.button("나가기")
	back.position = Vector2(560, 332)
	back.pressed.connect(close)
	add_child(back)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


static func distance_km(m: float) -> float:
	return 0.5 + maxf(m - Game.at(DEPART), 0.0) * SPEED_KM_MIN


## 수평선에 가려지는 높이 (m)
static func hidden_m(d_km: float) -> float:
	var beyond := maxf(d_km - EYE_HORIZON_KM, 0.0)
	return beyond * beyond / (2.0 * EARTH_R_KM) * 1000.0


func _process(delta: float) -> void:
	_t += delta
	var m := Game.minutes
	var d := distance_km(m)
	var h := hidden_m(d)
	if m < Game.at(DEPART):
		_status = "부두에 섬 연락선이 서 있다. 안내판: '마지막 배 19:30 출항'."
	elif h >= MAST_M:
		_status = "배는 이미 수평선 너머로 사라졌다. 이제 아무 불빛도 보이지 않는다."
	elif h < 0.5:
		_status = "연락선이 떠났다. 배까지 약 %.0f km. 불빛이 모두 보인다." % d
	elif h < HULL_M:
		_status = "배까지 약 %.0f km. 어? 선체 아래쪽이 수평선에 조금씩 가려지기 시작한다." % d
	else:
		_status = "배까지 약 %.0f km. 선체 불빛은 사라졌는데, 위쪽 불빛은 아직 보인다! 쌍안경으로 크게 봐도 아랫부분은 다시 보이지 않는다." % d
		if h > 2.0:
			Game.night["ship_watch"] = Game.night.get("ship_watch", 0.0) + delta
			if Game.night["ship_watch"] >= 1.0 and Game.add_fact("ship_horizon"):
				_status = "아래쪽 불빛은 사라지고 돛대 꼭대기 불빛만 남았다. 쌍안경으로 크게 봐도 아래는 보이지 않는다. 무슨 뜻일까? (나가서 생각해 보자)"
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var dark := Astro.darkness(Game.minutes)
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, HY), Color8(10, 12, 30).lerp(Color8(90, 120, 170), 1.0 - dark))
	draw_rect(Rect2(0, HY, Pal.SCREEN.x, Pal.SCREEN.y - HY), Color8(16, 22, 44).lerp(Color8(50, 80, 130), 1.0 - dark))
	for i in 60:
		draw_rect(Rect2((i * 71) % 640, (i * 37) % int(HY - 10), 1, 1), Color(1, 1, 1, 0.5 * dark))
	for i in 30:
		var y := HY + 4 + (i * 11) % 150
		draw_rect(Rect2(fposmod(i * 83.0 + sin(_t + i) * 6.0, 640), y, 6, 1), Color(0.6, 0.7, 1.0, 0.25))
	_draw_ship()
	# 쌍안경 테두리 (두 원 바깥을 검게)
	var c1 := Vector2(250, 180)
	var c2 := Vector2(390, 180)
	var rr := 150.0
	var black := Color(0, 0, 0, 0.94)
	for y in range(0, 360, 2):
		var dy := float(y) - c1.y
		if absf(dy) >= rr:
			draw_rect(Rect2(0, y, 640, 2), black)
			continue
		var half := sqrt(rr * rr - dy * dy)            # 두 원이 이 줄에서 차지하는 구간
		var x0 := c1.x - half
		var x2 := c2.x + half
		draw_rect(Rect2(0, y, x0, 2), black)
		if c1.x + half < c2.x - half:
			draw_rect(Rect2(c1.x + half, y, (c2.x - half) - (c1.x + half), 2), black)
		draw_rect(Rect2(x2, y, 640 - x2, 2), black)
	draw_string(font, Vector2(10, 16), "부두 쌍안경 · 북쪽 바다 · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	var r := Rect2(10, 296, 540, 52)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	draw_multiline_string(font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)


## 거리에 따라 작아지고, 가려진 높이만큼 수평선 아래로 잘려 보입니다. (연락선 그림, 길이 SHIP_LEN_M)
func _draw_ship() -> void:
	var m := Game.minutes
	var d := distance_km(m)
	var hid := hidden_m(d)
	if hid >= MAST_M:
		return
	var tex: Texture2D = _ferry
	var px_per_m := clampf(110.0 / d, 0.6, 10.0)      # 쌍안경으로 크게 본 크기
	var water := HY + hid * px_per_m                   # 배가 떠 있는 물 높이 (수평선보다 아래)
	var size := Vector2(SHIP_LEN_M, MAST_M) * px_per_m
	var top := water - size.y
	var cx := 320.0 - size.x * MAST_AT                 # 돛대가 시야 가운데에 오게
	if top < HY:
		var show := minf(1.0, (HY - top) / size.y)      # 수평선 위로 보이는 비율 (위에서부터)
		var dark := Astro.darkness(Game.minutes)
		var tint := Color.WHITE.lerp(Color(0.55, 0.52, 0.7), dark)
		draw_texture_rect_region(tex, Rect2(cx - size.x / 2.0, top, size.x, size.y * show),
				Rect2(0, 0, tex.get_width(), tex.get_height() * show), tint)
		var lamp := Vector2(cx + size.x * MAST_AT, top + size.y * 0.03)   # 돛대 꼭대기 등
		draw_circle(lamp, maxf(2.0, px_per_m * 1.2), Color(1, 0.85, 0.5, 0.25 * dark + 0.1))
	draw_line(Vector2(0, HY), Vector2(640, HY), Color(0.7, 0.75, 1.0, 0.35), 1)
