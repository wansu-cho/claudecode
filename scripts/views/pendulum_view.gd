extends Control
## 푸코 진자를 위에서 내려다본 모습입니다.
## 진자가 흔들리는 방향은 1시간에 약 8.4도(= 15° × sin 34°)씩 시계 방향으로 돌아갑니다.
## '기록하기'로 방향을 적어 두고, 1시간 이상 지나서 다시 기록하면 차이를 알 수 있습니다.

signal closed

const CENTER := Vector2(320, 170)
const R := 120.0
const RATE := 8.39          # 도/시간 (북위 34°)
const START_ANGLE := 24.0   # 17:30에 흔들리는 방향 (북쪽에서 시계 방향, 도)

var _status := ""
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.position = Vector2(440, 330)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var rec := Pal.button("기록하기")
	rec.pressed.connect(record)
	row.add_child(rec)
	var back := Pal.button("나가기")
	back.pressed.connect(close)
	row.add_child(back)
	_status = "줄에 매달린 무거운 추가 같은 방향으로 계속 흔들린다. 바닥 눈금으로 방향을 기록해 보자."


static func angle_at(m: float) -> float:
	return START_ANGLE + RATE * m / 60.0


func record() -> void:
	var recs: Array = Game.night["pend"]
	var now := {"m": Game.minutes, "a": angle_at(Game.minutes)}
	var older := {}
	for r in recs:
		if Game.minutes - float(r["m"]) >= 60.0:
			older = r
			break
	recs.append(now)
	if older.is_empty():
		_status = "%s 기록: 흔들리는 방향을 바닥 눈금에 표시했다. 한참 뒤에 다시 와서 비교해 보자." % Game.clock()
		if recs.size() > 1:
			_status = "%s 기록. 앞 기록과 거의 같다… 시간이 더 지나야 차이가 보일 것 같다." % Game.clock()
		return
	var diff := float(now["a"]) - float(older["a"])
	var hours := (Game.minutes - float(older["m"])) / 60.0
	if Game.add_fact("pendulum"):
		_status = "%.1f시간 동안 흔들리는 방향이 시계 방향으로 약 %d도 돌았다! 진자는 그대로인데 그 아래 땅이 돈 것이다. (관측 일지에 기록)" % [hours, roundi(diff)]
	else:
		_status = "%.1f시간 동안 약 %d도 돌았다." % [hours, roundi(diff)]


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			record()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _dir(a_deg: float) -> Vector2:
	var a := deg_to_rad(a_deg)
	return Vector2(sin(a), -cos(a))


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color8(30, 26, 44))
	draw_string(font, Vector2(10, 16), "로비 · 푸코 진자 (위에서 본 모습) · %s" % Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	draw_circle(CENTER, R + 8, Color8(56, 48, 76))
	draw_circle(CENTER, R, Color8(72, 62, 96))
	for i in 72:
		var d := _dir(i * 5.0)
		var l := 10.0 if i % 6 == 0 else 4.0
		draw_line(CENTER + d * (R - l), CENTER + d * R, Color8(170, 160, 200), 1)
	for spec in [["북", 0.0], ["동", 90.0], ["남", 180.0], ["서", 270.0]]:
		draw_string(font, CENTER + _dir(spec[1]) * (R + 18) - Vector2(6, -5), spec[0], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 기록한 방향
	for r in Game.night["pend"]:
		var d := _dir(float(r["a"]))
		draw_line(CENTER - d * R, CENTER + d * R, Color(Pal.PINK, 0.6), 1)
		draw_string(font, CENTER + d * (R + 4) + Vector2(2, 0), Game.clock(float(r["m"])), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.PINK)
	# 지금 흔들리는 추
	var d := _dir(angle_at(Game.minutes))
	Pal.dotted(self, CENTER - d * (R - 6), CENTER + d * (R - 6), Color(1, 1, 1, 0.35), 3)
	var bob := CENTER + d * (R - 14) * sin(_t * TAU / 4.0)
	draw_circle(bob, 9, Color8(230, 190, 90))
	draw_circle(bob - Vector2(2, 2), 3, Color8(255, 236, 170))
	var r := Rect2(10, 296, 420, 52)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	draw_multiline_string(font, r.position + Vector2(6, 14), _status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, Pal.SMALL, 3, Pal.TEXT)
