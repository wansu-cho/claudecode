extends Control
## 2층 강의실의 칠판입니다. 선생님이 오늘 밤 하늘의 시간표를 적어 두었습니다.
## 보는 동안에는 시간이 멈춥니다.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()
	var back := Pal.button("나가기")
	back.position = Vector2(560, 332)
	back.pressed.connect(close)
	add_child(back)


func close() -> void:
	Game.unfreeze()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_E]:
		get_viewport().set_input_as_handled()
		close()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color8(60, 42, 30))
	var board := Rect2(24, 18, 592, 304)
	draw_rect(board, Color8(34, 70, 54))
	draw_rect(board, Color8(150, 110, 70), false, 4.0)
	var chalk := Color(0.93, 0.96, 0.92)
	draw_string(font, board.position + Vector2(20, 26), "오늘 밤 하늘  (12월 13일, 보름)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.BIG, Color8(250, 230, 140))
	var y := board.position.y + 52
	for line in Story.BLACKBOARD:
		draw_string(font, Vector2(board.position.x + 26, y), line, HORIZONTAL_ALIGNMENT_LEFT, board.size.x - 40, Pal.SMALL, chalk)
		y += 21
	draw_rect(Rect2(board.position.x + 380, board.end.y - 10, 30, 4), Color(0.95, 0.95, 0.95))   # 분필
