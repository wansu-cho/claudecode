extends Control
## 화면 전체를 덮는 안내판입니다. (제목 화면, 루프 시작, 해돋이)
## 버튼을 주면 버튼을 고를 때까지 기다리고, 없으면 누르면 넘어갑니다.

signal done(index: int)

var _lines: Array
var _buttons: Array
var _title: String
var _bg: Color


func _init(title: String, lines: Array, buttons: Array = [], bg := Color(0.01, 0.01, 0.04, 0.96)) -> void:
	_title = title
	_lines = lines
	_buttons = buttons
	_bg = bg


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = 70
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	if _title != "":
		box.add_child(Pal.label(_title, Pal.BIG, Pal.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for l in _lines:
		box.add_child(Pal.label(str(l), Pal.SMALL, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if _buttons.is_empty():
		box.add_child(Pal.label("\n누르거나 Enter", Pal.SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(Control.new())
		box.add_child(row)
		for i in _buttons.size():
			var b := Pal.button(_buttons[i], Pal.BIG)
			b.pressed.connect(func(): _finish(i))
			row.add_child(b)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg)


func _gui_input(event: InputEvent) -> void:
	if _buttons.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_finish(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_finish(0)
		elif not _buttons.is_empty() and event.keycode >= KEY_1 and event.keycode < KEY_1 + _buttons.size():
			get_viewport().set_input_as_handled()
			_finish(event.keycode - KEY_1)


func _finish(i: int) -> void:
	done.emit(i)
	queue_free()
