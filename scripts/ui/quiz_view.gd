extends Control
## 깨달음 퀴즈 화면입니다. (예측 → 관찰 → 설명 중 '예측'과 '설명')
##   spec = {"title": 제목, "steps": [단계...], "predict": true면 예측(정답 없음), "mine": 내 예측(설명 때 보여 줌)}
##   단계 = {"q": 질문, "opts": [보기...], "a": 정답 번호, "hint": 초성·힌트, "why": {틀린 보기 번호: 까닭},
##           "diagram": 그림 이름(선택), "recall": 관측 때 본 것(선택)}
## 틀리면 힌트가 한 단계씩 늘어납니다: ① 다시 떠올리기 ② 초성 힌트 ③ 보기 2개로 줄이기
## 퀴즈가 떠 있는 동안 시간은 멈춥니다. 끝나면 done을 보냅니다.

signal done(picked: String)

const BOX := Rect2(40, 26, 560, 308)
const BTN_H := 26.0
const BTN_W := 520.0                   # 보기 단추 폭 (그림 없는 문제)
const BTN_W_DIAGRAM := 250.0           # 그림 있는 문제: 오른쪽 칸 폭                    # 보기 단추 하나의 높이 (간격 포함)
const MSG_H := 44.0                    # 힌트·까닭 글 자리 (3줄)

var spec: Dictionary
var _step := 0
var _tries := 0
var _msg := ""
var _msg_col := Pal.TEXT
var _opts: Array = []                # 지금 보여 주는 보기 (원래 번호들)
var _buttons: VBoxContainer
var _t := 0.0
var _locked := false


func _init(s: Dictionary) -> void:
	spec = s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	add_child(_buttons)
	_show_step()


func _steps() -> Array:
	return spec["steps"]


func _cur() -> Dictionary:
	return _steps()[_step]


func _show_step() -> void:
	_tries = 0
	_msg = ""
	_opts = range(_cur()["opts"].size())
	_make_buttons()


func _make_buttons() -> void:
	for c in _buttons.get_children():                # 바로 빼야 함: 남아 있으면 이전 단계의 넓은 단추 폭이 그대로 남음
		_buttons.remove_child(c)
		c.queue_free()
	_buttons.size = Vector2.ZERO
	var opts: Array = _cur()["opts"]
	var wide := _cur().has("diagram")
	for k in _opts.size():
		var b := Pal.button("%d. %s" % [k + 1, opts[_opts[k]]])
		b.custom_minimum_size = Vector2(BTN_W_DIAGRAM if wide else BTN_W, 20)
		b.clip_text = true                               # 긴 보기가 상자 밖으로 넘치지 않게
		var idx: int = _opts[k]
		b.pressed.connect(func(): pick(idx))
		_buttons.add_child(b)
	# 보기는 상자 아래쪽에 붙이고, 힌트·까닭은 그 바로 위에 (서로 가리지 않게)
	_buttons.position = Vector2(BOX.position.x + (300 if wide else 20), _buttons_top())
	queue_redraw()


func _buttons_top() -> float:
	return BOX.end.y - 8.0 - BTN_H * _opts.size()


## 보기를 고릅니다 (원래 보기 번호)
func pick(i: int) -> void:
	if _locked:
		return
	var st := _cur()
	if spec.get("predict", false):
		_locked = true
		_msg = "예측을 적어 두었다: '%s'. 이제 직접 확인해 보자!" % st["opts"][i]
		_msg_col = Pal.CYAN
		queue_redraw()
		await get_tree().create_timer(1.2).timeout
		_finish(st["opts"][i])
		return
	if i == int(st["a"]):
		Sfx.play("correct", -6.0)
		_locked = true
		_msg = "맞아!  " + st.get("ok", "")
		_msg_col = Pal.GOLD
		queue_redraw()
		await get_tree().create_timer(1.0).timeout
		_locked = false
		_step += 1
		if _step >= _steps().size():
			_finish("")
		else:
			_show_step()
		return
	_tries += 1
	Sfx.play("wrong", -8.0)
	var why: Dictionary = st.get("why", {})
	var lines := []
	if why.has(i):
		lines.append(why[i])
	if _tries == 1:
		lines.append("다시 생각해 보자." + ("  관측할 때 본 것: " + st["recall"] if st.has("recall") else ""))
	elif _tries == 2:
		lines.append("힌트: " + st.get("hint", "관측 일지를 떠올려 보자."))
	else:
		lines.append("보기를 두 개로 줄였어. 하나만 골라 보자.")
		var wrong := []
		for k in st["opts"].size():
			if k != int(st["a"]):
				wrong.append(k)
		var keep: int = wrong[i % wrong.size()] if i in wrong else wrong[0]
		_opts = [int(st["a"]), keep] if (_step + _tries) % 2 == 0 else [keep, int(st["a"])]
		_make_buttons()
	_msg = "  ".join(PackedStringArray(lines))
	_msg_col = Color8(255, 170, 150)
	queue_redraw()


func _finish(picked: String) -> void:
	Game.unfreeze()
	done.emit(picked)
	queue_free()


## 시험용: 정답(예측은 첫 보기)을 차례로 고릅니다.
func solve() -> void:
	if not is_inside_tree():
		return
	pick(0 if spec.get("predict", false) else int(_cur()["a"]))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < _opts.size():
			get_viewport().set_input_as_handled()
			pick(_opts[n])


func _process(delta: float) -> void:
	_t += delta
	if _cur().get("diagram", "") != "":
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Pal.SCREEN), Color(0, 0, 0, 0.55))
	draw_rect(BOX, Color8(24, 20, 48))
	draw_rect(BOX, Pal.GOLD, false, 2.0)
	var predict: bool = spec.get("predict", false)
	var head: String = ("예측해 보자" if predict else "생각해 보자") + " · " + spec.get("title", "")
	draw_string(font, BOX.position + Vector2(14, 20), head, HORIZONTAL_ALIGNMENT_LEFT, BOX.size.x - 90, Pal.SMALL, Pal.CYAN if predict else Pal.GOLD)
	draw_line(BOX.position + Vector2(10, 28), BOX.position + Vector2(BOX.size.x - 10, 28), Color(Pal.GOLD, 0.4), 1)
	if not predict:
		draw_string(font, BOX.position + Vector2(BOX.size.x - 60, 18), "%d / %d" % [mini(_step + 1, _steps().size()), _steps().size()], HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	var y := BOX.position.y + 40
	if spec.get("mine", "") != "":
		draw_string(font, Vector2(BOX.position.x + 14, y), "보기 전 내 예측: " + spec["mine"], HORIZONTAL_ALIGNMENT_LEFT, BOX.size.x - 28, Pal.SMALL, Pal.DIM)
		y += 16
	var st := _cur()
	var qw := 240.0 if st.has("diagram") else BOX.size.x - 28
	draw_multiline_string(font, Vector2(BOX.position.x + 14 + (290 if st.has("diagram") else 0), y + 12), st["q"], HORIZONTAL_ALIGNMENT_LEFT, qw, Pal.SMALL, 5 if st.has("diagram") else 4, Pal.TEXT)
	var btop := _buttons_top()
	if st.has("diagram"):
		_diagram(st["diagram"], Rect2(BOX.position.x + 14, y, 270, minf(200.0, BOX.end.y - 10.0 - y)))
	if _msg != "":
		var mx := BOX.position.x + (300.0 if st.has("diagram") else 20.0)
		var mw := 250.0 if st.has("diagram") else BOX.size.x - 40.0
		draw_rect(Rect2(mx - 4, btop - MSG_H - 4, mw + 8, MSG_H), Color8(36, 30, 64))
		draw_multiline_string(font, Vector2(mx, btop - MSG_H + 8), _msg, HORIZONTAL_ALIGNMENT_LEFT, mw, Pal.SMALL, 3, _msg_col)


# ---- 그림 ----

func _diagram(name: String, r: Rect2) -> void:
	var c := r.position + r.size / 2.0
	var font := get_theme_default_font()
	draw_rect(r, Color8(12, 10, 28))
	match name:
		"earth_top":                                   # 북극 위에서 본 지구, 해는 왼쪽
			draw_circle(Vector2(r.position.x + 24, c.y), 16, Color8(255, 200, 90))
			draw_string(font, Vector2(r.position.x + 12, c.y + 32), "해", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
			for i in 5:
				var yy := c.y - 40 + i * 20
				draw_line(Vector2(r.position.x + 46, yy), Vector2(c.x - 50, yy), Color(1, 0.85, 0.4, 0.35), 1)
			var ec := c + Vector2(30, 0)
			draw_circle(ec, 56, Color8(40, 90, 170))
			var night := PackedVector2Array([ec])
			for i in 17:
				night.append(ec + Vector2.from_angle(-PI / 2.0 + PI * i / 16.0) * 56)
			draw_colored_polygon(night, Color(0.02, 0.02, 0.1, 0.7))
			draw_circle(ec, 4, Pal.TEXT)
			draw_string(font, ec + Vector2(-6, -8), "북극", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
			# 북극 위에서 보면 지구는 시계 반대 방향으로 돎: 아래쪽(6시)에 있는 사람이 오른쪽(밤)으로 들어감 = 해 질 녘
			var me := ec + Vector2(0, 56)
			draw_circle(me, 5, Pal.PINK)
			draw_string(font, me + Vector2(8, 12), "나 (해 질 녘)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.PINK)
			draw_string(font, Vector2(ec.x - 30, ec.y - 64), "낮 ← | → 밤", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
		"pendulum_floor":                              # 위에서 본 진자: 흔들리는 방향은 그대로, 바닥판만 돌아감
			var rot := _t * 0.6
			draw_circle(c, 80, Color8(200, 170, 140))
			draw_circle(c, 76, Color8(226, 200, 172))
			for i in 24:
				var d := Vector2.from_angle(rot + TAU * i / 24.0)
				draw_line(c + d * 64, c + d * 76, Color8(60, 40, 40), 2 if i % 6 == 0 else 1)
			draw_string(font, c + Vector2.from_angle(rot - PI / 2.0) * 58 + Vector2(-6, 4), "북", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color8(120, 40, 40))
			Pal.dotted(self, c + Vector2(-78, -30), c + Vector2(78, 30), Color(0.1, 0.1, 0.3), 3)
			var bob := c + Vector2(78, 30) * sin(_t * 2.2)
			draw_circle(bob, 7, Color8(230, 180, 70))
			draw_string(font, Vector2(r.position.x + 6, r.end.y - 8), "점선: 추가 흔들리는 방향 (그대로)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
		"earth_shapes":                                # 월식 사진과 세 가지 지구
			var mc := Vector2(c.x, r.position.y + 50)
			draw_circle(mc, 34, Color8(236, 232, 214))
			draw_circle(mc + Vector2(-44, 10), 46, Color8(70, 30, 26))
			draw_string(font, Vector2(mc.x + 40, mc.y), "월식 사진", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
			var y0 := r.position.y + 150
			var names := ["① 세모", "② 동그라미", "③ 네모"]
			for k in 3:
				var p := Vector2(r.position.x + 46 + k * 88, y0)
				match k:
					0: draw_colored_polygon(PackedVector2Array([p + Vector2(0, -24), p + Vector2(24, 18), p + Vector2(-24, 18)]), Color8(60, 120, 200))
					1: draw_circle(p, 22, Color8(60, 120, 200))
					2: draw_rect(Rect2(p - Vector2(21, 21), Vector2(42, 42)), Color8(60, 120, 200))
				draw_string(font, p + Vector2(-30, 38), names[k], HORIZONTAL_ALIGNMENT_LEFT, 70, Pal.SMALL, Pal.TEXT)
		"ship_shapes":                                 # 네모 지구와 둥근 지구 위의 배
			var y1 := r.position.y + 70
			draw_rect(Rect2(r.position.x + 20, y1, 100, 40), Color8(60, 120, 200))
			draw_string(font, Vector2(r.position.x + 30, y1 + 58), "네모(평평한) 지구", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
			draw_rect(Rect2(r.position.x + 90, y1 - 10, 18, 10), Pal.TEXT)
			draw_arc(Vector2(r.position.x + 200, y1 + 80), 70, PI * 1.15, PI * 1.85, 24, Color8(60, 120, 200), 6)
			draw_string(font, Vector2(r.position.x + 160, y1 + 58), "둥근 지구", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
			draw_rect(Rect2(r.position.x + 238, y1 + 8, 14, 9), Pal.TEXT)
			draw_circle(Vector2(r.position.x + 152, y1 + 14), 3, Pal.PINK)
			draw_string(font, Vector2(r.position.x + 132, y1 + 4), "나", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.PINK)
