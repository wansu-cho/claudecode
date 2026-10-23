extends StageBase
## 고르기 문제 단계입니다.
##
## 개인 플레이: 대원이 답을 펜으로 누르거나 숫자키(1~3)로 고릅니다.
##             틀린 답은 흐려지고, 맞히면 설명이 나옵니다.
## 전원 참여  : 모두 손가락으로 답하고, 진행자가 Enter로 정답을 공개합니다.

var quiz: Dictionary
var revealed := false
var solved_by_player := false
var _buttons: Array[Button] = []
var _explain: Label


func _build() -> void:
	quiz = stage["quiz"]
	auto_wait = 12.0
	if group_mode:
		auto_result = "group"

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	box.add_child(Pal.label(quiz["question"], Pal.SMALL, Pal.TEXT))
	var choices: Array = quiz["choices"]
	for i in choices.size():
		var b := Pal.button("%d. %s" % [i + 1, choices[i]], Pal.SMALL)
		b.custom_minimum_size = Vector2(0, 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if group_mode:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			b.pressed.connect(_choose.bind(i))
		box.add_child(b)
		_buttons.append(b)

	_explain = Pal.label("", Pal.SMALL, Pal.GOLD)
	box.add_child(_explain)


func get_instruction() -> String:
	if revealed:
		return "화면을 누르거나 Enter를 누르면 다음 임무로."
	if group_mode:
		return "전원 참여! 모두 손가락으로 답하라. (진행자: Enter로 정답 공개)"
	return "정답을 골라 눌러라. (키보드: 숫자키 1~%d)" % _buttons.size()


func _choose(i: int) -> void:
	if done or not accept_tap():
		return
	if i == quiz["answer"]:
		_reveal()
		succeed_quiz()
	else:
		_dim(i)
		wrong("오답이다. 다시 분석하라.")


func succeed_quiz() -> void:
	done = true
	solved_by_player = true
	say("분석 성공!", Pal.GOLD)


func _dim(i: int) -> void:
	var b := _buttons[i]
	b.disabled = true
	b.add_theme_color_override("font_disabled_color", Pal.DIM)
	b.add_theme_stylebox_override("disabled", Pal.box_style(Pal.BG, Pal.PANEL))


func _reveal() -> void:
	revealed = true
	for i in _buttons.size():
		if i == quiz["answer"]:
			_buttons[i].add_theme_stylebox_override("normal", Pal.box_style(Pal.PANEL, Pal.GOLD))
			_buttons[i].add_theme_stylebox_override("disabled", Pal.box_style(Pal.PANEL, Pal.GOLD))
			_buttons[i].add_theme_color_override("font_color", Pal.GOLD)
			_buttons[i].add_theme_color_override("font_disabled_color", Pal.GOLD)
			_buttons[i].disabled = true
		else:
			_dim(i)
	_explain.text = quiz["explain"]


func _on_hint() -> void:
	if group_mode:
		_reveal()
		done = true
		return
	# 틀린 보기 하나를 지워 줍니다.
	for i in _buttons.size():
		if i != quiz["answer"] and not _buttons[i].disabled:
			_dim(i)
			say("힌트: 틀린 보기 하나를 지웠다.", Pal.ACCENT)
			return


func _on_auto_solve() -> void:
	_reveal()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if revealed:
			accept_event()
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		if revealed:
			_next()
		elif group_mode:
			_reveal()
			done = true
		return
	if not group_mode and not revealed:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < _buttons.size():
			get_viewport().set_input_as_handled()
			if not _buttons[n].disabled:
				_choose(n)


func _next() -> void:
	if group_mode:
		finish("group")
	elif solved_by_player:
		finish("success")
	else:
		finish("assisted")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.BG)
	draw_instruction_bar()
