extends Control
## 관측 일지에 새 사실이 적힐 때의 효과입니다.
##   관측으로 알아낸 사실(aha가 있는 것): 관측 화면을 나온 뒤에 카드가 뜹니다. (해석할 시간을 주려고)
##     1단계 "무엇을 보았나": 본 것만 떠올림 → 눌러서 생각해 보기
##     2단계 "깨달음!": 깨달음 한 줄 → 누르면 카드가 관측 일지 버튼으로 날아갑니다.
##   이야기 기록(인물의 이야기, 쪽지): 작은 카드가 바로 관측 일지 버튼으로 날아갑니다.
## 깨달음 카드가 떠 있는 동안에는 시간이 멈춥니다.

signal landed

const CARD := Vector2(380, 150)
const JOURNAL_AT := Vector2(579, 18)          # 관측 일지 버튼 가운데

var _queue: Array = []
var _card: Control = null
var _waiting := false
var _shown_at := 0
var _stage := 0
var _fact := ""
var quiz_runner: Callable              # main이 넣어 줌: 사실 id를 받아 설명 퀴즈를 풀 때까지 기다림


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.fact_added.connect(_on_fact)


func busy() -> bool:
	return _card != null


## 아직 보여 주지 않은 깨달음이 있는지 (main이 관측 화면이 닫힌 뒤에 show_next를 부름)
func has_pending() -> bool:
	return not _queue.is_empty()


func _on_fact(id: String) -> void:
	var f: Dictionary = Story.FACTS[id]
	if f.has("aha"):
		_queue.append(id)
	else:
		_fly_small(f["title"])


func show_next() -> void:
	if _queue.is_empty() or _card != null:
		return
	_fact = _queue.pop_front()
	var f: Dictionary = Story.FACTS[_fact]
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()
	_stage = 1
	_card = _make_card("무엇을 보았지?", "", f["seen"], "눌러서 생각해 보기", Pal.CYAN)
	_pop_in()


func _pop_in() -> void:
	add_child(_card)
	_card.pivot_offset = CARD / 2.0
	_card.position = (Pal.SCREEN - CARD) / 2.0
	_card.scale = Vector2(0.4, 0.4)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	_waiting = true
	_shown_at = Time.get_ticks_msec()
	queue_redraw()


func _make_card(head_text: String, title: String, body: String, foot: String, head_col: Color) -> Control:
	var c := Control.new()
	c.size = CARD
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color8(24, 20, 48)
	bg.size = CARD
	c.add_child(bg)
	var frame := ReferenceRect.new()
	frame.border_color = Pal.GOLD
	frame.border_width = 2.0
	frame.editor_only = false
	frame.size = CARD
	c.add_child(frame)
	var head := Pal.label(head_text, Pal.BIG, head_col)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 10)
	head.size = Vector2(CARD.x, 22)
	c.add_child(head)
	var t := Pal.label(title, Pal.SMALL, Pal.CYAN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 44)
	t.size = Vector2(CARD.x, 16)
	c.add_child(t)
	var a := Pal.label(body, Pal.SMALL, Pal.TEXT)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.position = Vector2(20, 70)
	a.size = Vector2(CARD.x - 40, 46)
	c.add_child(a)
	var hint := Pal.label(foot, Pal.SMALL, Pal.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, CARD.y - 22)
	hint.size = Vector2(CARD.x, 16)
	c.add_child(hint)
	return c


## 카드를 넘깁니다: 1단계 → 깨달음, 깨달음 → 관측 일지로 날아감
func dismiss() -> void:
	if not _waiting or _card == null:
		return
	if _stage == 1:
		_stage = 2
		_waiting = false
		var f: Dictionary = Story.FACTS[_fact]
		if quiz_runner.is_valid() and Story.QUIZ.has(_fact):   # "무엇을 보았지?" 다음에 설명 퀴즈
			_card.visible = false
			await quiz_runner.call(_fact)
		_card.queue_free()
		var st: int = int(Game.stars.get(_fact, 0))
		var title: String = f["title"] + ("  ·  " + Story.STAR_NAME[st] if st > 0 else "")
		_card = _make_card("★  깨달음!  ★", title, f["aha"], "관측 일지에 기록 · 눌러서 계속", Pal.GOLD)
		Sfx.play("aha", -4.0)
		_pop_in()
		return
	_waiting = false
	var card := _card
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2(0.08, 0.08), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "position", JOURNAL_AT - CARD / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		card.queue_free()
		landed.emit()
		Game.unfreeze()
		_card = null
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw())


## 작은 기록 카드: 화면 가운데 아래에서 관측 일지 버튼으로 날아갑니다.
func _fly_small(title: String) -> void:
	var l := Pal.label("관측 일지 + " + title, Pal.SMALL, Pal.GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bg := ColorRect.new()
	bg.color = Color8(24, 20, 48, 230)
	var w := get_theme_default_font().get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL).x + 16
	bg.size = Vector2(w, 20)
	l.position = Vector2(8, 2)
	l.size = Vector2(w - 16, 16)
	bg.add_child(l)
	bg.position = Vector2((Pal.SCREEN.x - w) / 2.0, 250)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(bg, "position", JOURNAL_AT - Vector2(w / 2.0, 10), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bg, "modulate:a", 0.2, 0.5)
	tw.tween_callback(func():
		bg.queue_free()
		landed.emit())


func _input(event: InputEvent) -> void:
	if not _waiting or Time.get_ticks_msec() - _shown_at < 350:
		if _waiting:
			get_viewport().set_input_as_handled()
		return
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		go = true
	if go or event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if go:
		dismiss()


func _draw() -> void:
	if _card != null:
		draw_rect(Rect2(Vector2.ZERO, Pal.SCREEN), Color(0, 0, 0, 0.45))


func _process(_delta: float) -> void:
	if _card != null:
		queue_redraw()
