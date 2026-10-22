extends Control
## 참가 인원 입력 화면입니다. (5~10명)
## 펜으로 숫자를 누르거나, 키보드 숫자키(5~9, 10명은 0)를 누릅니다.

signal chosen(count: int)

var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 70
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	box.add_child(Pal.label("오늘의 탐사대원은 몇 명인가?", Pal.BIG, Pal.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for n in range(GameState.MIN_PLAYERS, GameState.MAX_PLAYERS + 1):
		var b := Pal.button(str(n))
		b.custom_minimum_size = Vector2(64, 64)
		b.pressed.connect(_choose.bind(n))
		row.add_child(b)

	box.add_child(Pal.label("숫자를 누르세요. (키보드: 5~9, 10명은 0)", Pal.SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n := -1
		if event.keycode >= KEY_5 and event.keycode <= KEY_9:
			n = event.keycode - KEY_0
		elif event.keycode == KEY_0:
			n = 10
		if n > 0:
			get_viewport().set_input_as_handled()
			_choose(n)


func _choose(n: int) -> void:
	if _done:
		return
	_done = true
	chosen.emit(n)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.BG)
