class_name CardScreen
extends Control
## 글만 보여 주는 화면(안내판)입니다.
## 임무 브리핑, 대원 교대, 예측 질문, 결과 화면이 모두 이것을 씁니다.
## 화면을 누르거나 Enter를 누르면 다음으로 넘어갑니다.

signal advanced

var countdown := 0.0      # 0보다 크면 시간이 다 되었을 때 자동으로 넘어갑니다
var allow_tap := true     # false면 화면을 눌러도 넘어가지 않습니다 (예측 화면에서 실수로 넘기지 않게)
var _countdown_label: Label
var _box: VBoxContainer
var _done := false


func _init(title: String, lines: Array, footer := "화면을 누르거나 Enter를 누르면 계속") -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_box)

	if title != "":
		_box.add_child(Pal.label(title, Pal.BIG, Pal.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line in lines:
		add_line(str(line))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(spacer)

	_countdown_label = Pal.label("", Pal.BIG, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(_countdown_label)
	_box.add_child(Pal.label(footer, Pal.SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func add_line(text: String, color := Pal.TEXT, size := Pal.SMALL) -> void:
	var l := Pal.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	# 아래쪽 안내 문구(여백, 카운트다운, 안내)보다 위에 오도록 순서를 맞춥니다.
	if _countdown_label != null:
		_box.move_child(l, _box.get_child_count() - 4)


func _process(delta: float) -> void:
	if countdown <= 0.0 or _done:
		return
	countdown -= delta
	_countdown_label.text = str(ceili(maxf(countdown, 0.0)))
	if countdown <= 0.0:
		advance()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if allow_tap:
			advance()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			advance()


func advance() -> void:
	if _done:
		return
	_done = true
	advanced.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.BG)
