extends Control
## 진엔딩: 우주 속 우리의 주소 (교재 9장). 지구에서 관측 가능한 우주까지 일곱 단계로 넓어집니다.
## 누르거나 Enter로 다음 단계, 마지막 단계 뒤에 done.

signal done

const STAGES := [
	["지구", "우리가 사는 곳. 하루에 한 번 자전하고, 일 년에 한 번 태양 둘레를 공전한다."],
	["태양계", "태양과 여덟 행성의 가족. 지구는 태양에서 세 번째 행성이다."],
	["우리은하", "별이 수천억 개 모인 거대한 소용돌이. 태양은 그 가장자리 쪽의 별 하나다."],
	["국부은하군", "우리은하, 안드로메다은하 등 수십 개 은하가 모인 무리."],
	["처녀자리 초은하단", "은하군과 은하단 수백 개가 모인 더 큰 무리."],
	["라니아케아 초은하단", "하와이 말로 '헤아릴 수 없는 하늘'. 은하 약 10만 개가 한 곳으로 흘러가는 거대한 강. (2014년 발표)"],
	["관측 가능한 우주", "빛이 우리에게 닿을 수 있는 가장 먼 곳까지. 우리가 볼 수 있는 우주 전체."],
]

var stage := 0
var _t := 0.0
var _ok_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ok_at = Time.get_ticks_msec()


func next() -> void:
	if Time.get_ticks_msec() - _ok_at < 400:
		return
	_ok_at = Time.get_ticks_msec()
	stage += 1
	_t = 0.0
	if stage >= STAGES.size():
		done.emit()
		queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		get_viewport().set_input_as_handled()
		next()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Pal.SCREEN), Color8(2, 2, 8))
	var c := Vector2(320, 160)
	var zoom := 1.0 + minf(_t, 1.0) * 0.15                 # 단계가 바뀔 때 살짝 멀어지는 느낌
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + stage
	for i in 120:
		draw_rect(Rect2(rng.randf() * 640, rng.randf() * 300, 1, 1), Color(1, 1, 1, rng.randf_range(0.2, 0.7)))
	match stage:
		0:
			draw_circle(c, 70 / zoom, Color8(40, 100, 190))
			draw_circle(c + Vector2(-18, -14) / zoom, 26 / zoom, Color8(80, 160, 90))
			draw_circle(c + Vector2(22, 20) / zoom, 18 / zoom, Color8(80, 160, 90))
			var night := PackedVector2Array([c])           # 태양 반대쪽(오른쪽) 절반은 밤
			for i in 17:
				night.append(c + Vector2.from_angle(-PI / 2.0 + PI * i / 16.0) * 70 / zoom)
			draw_colored_polygon(night, Color(0, 0, 0.1, 0.55))
		1:
			draw_circle(c, 12, Color8(255, 200, 80))
			for k in 8:
				var r := (24.0 + k * 15.0) / zoom
				draw_arc(c, r, 0, TAU, 48, Color(0.6, 0.7, 1.0, 0.25), 1)
				var p := c + Vector2.from_angle(_t * (0.9 - k * 0.09) + k) * r
				draw_circle(p, 2.5 if k != 2 else 3.5, Color8(80, 140, 230) if k == 2 else Color8(200, 180, 150))
		2:
			for i in 900:
				var arm := i % 2
				var r := rng.randf_range(6, 130) / zoom
				var a := r * 0.045 + arm * PI + rng.randf_range(-0.35, 0.35) + _t * 0.05
				draw_rect(Rect2(c + Vector2(cos(a), sin(a) * 0.55) * r, Vector2.ONE), Color(0.85, 0.85, 1.0, rng.randf_range(0.2, 0.9)))
			draw_circle(c, 10, Color(1, 0.95, 0.8, 0.6))
			var sun := c + Vector2(84, 10) / zoom
			Pal.ring(self, sun, 5, Pal.GOLD)
			draw_string(font, sun + Vector2(8, -6), "태양", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
		3:
			for g in [[Vector2(-80, 10), 28.0, "우리은하"], [Vector2(90, -20), 36.0, "안드로메다은하"], [Vector2(10, 60), 14.0, ""], [Vector2(-20, -60), 10.0, ""], [Vector2(150, 50), 8.0, ""]]:
				var p: Vector2 = c + g[0] / zoom
				draw_circle(p, g[1] / zoom, Color(0.8, 0.8, 1.0, 0.25))
				draw_circle(p, g[1] / zoom * 0.35, Color(1, 0.95, 0.85, 0.7))
				if g[2] != "":
					draw_string(font, p + Vector2(-20, g[1] / zoom + 12), g[2], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
		4, 5, 6:
			var n: int = [400, 900, 1800][stage - 4]
			for i in n:
				var a := rng.randf() * TAU
				var r := pow(rng.randf(), 0.7) * 150.0 / zoom
				var p := c + Vector2.from_angle(a) * r
				if stage >= 5:                                 # 실처럼 이어진 우주 거미줄
					p += Vector2(sin(p.y * 0.05), cos(p.x * 0.05)) * 14.0
				draw_rect(Rect2(p, Vector2.ONE), Color(0.75, 0.8, 1.0, rng.randf_range(0.2, 0.8)))
			if stage == 5:
				for k in 10:
					var s := Vector2.from_angle(k * 0.63) * 140.0
					Pal.dotted(self, c + s, c + s * 0.15, Color(0.6, 0.8, 1.0, 0.3), 5)
	# 우리 주소 (지금까지)
	var addr := []
	for k in range(stage, -1, -1):
		addr.append(STAGES[k][0])
	draw_rect(Rect2(10, 270, 620, 80), Pal.PANEL)
	draw_rect(Rect2(10, 270, 620, 80), Pal.LINE, false, 1.0)
	draw_string(font, Vector2(20, 288), "우주 주소 %d / 7 · %s" % [stage + 1, STAGES[stage][0]], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	draw_multiline_string(font, Vector2(20, 306), STAGES[stage][1], HORIZONTAL_ALIGNMENT_LEFT, 600, Pal.SMALL, 2, Pal.TEXT)
	draw_string(font, Vector2(20, 342), " › ".join(PackedStringArray(addr)) + " › 별빛섬 어린이천문대", HORIZONTAL_ALIGNMENT_LEFT, 600, Pal.SMALL, Pal.DIM)
