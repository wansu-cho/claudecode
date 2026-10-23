extends Control
## 화면 아래 대사창입니다.
##   await say(lines)          대사 여러 줄을 차례로 보여 줌
##   await choose(["가", "나"]) 선택지를 보여 주고 고른 번호를 돌려줌

signal _next
signal _picked(index: int)

var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _waiting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Pal.box_style(Color(0.04, 0.04, 0.1, 0.94), Pal.CYAN))
	_panel.position = Vector2(16, 262)
	_panel.size = Vector2(608, 88)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_name = Pal.label("", Pal.SMALL, Pal.CYAN)
	box.add_child(_name)
	_text = Pal.label("", Pal.SMALL, Pal.TEXT)
	_text.custom_minimum_size = Vector2(590, 44)
	box.add_child(_text)
	_hint = Pal.label("▼ 누르거나 Enter", Pal.SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_hint)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	_choices.position = Vector2(360, 150)
	add_child(_choices)


func say(lines: Array) -> void:
	visible = true
	Game.freeze()
	for line in lines:
		var who: String = line[0]
		_name.text = who
		_name.visible = who != ""
		_text.text = line[1]
		_text.add_theme_color_override("font_color", Pal.TEXT if who != "" else Color("c9c4ee"))
		_hint.visible = true
		_waiting = true
		await _next
	_waiting = false
	visible = false
	Game.unfreeze()


func choose(options: Array) -> int:
	visible = true
	Game.freeze()
	_hint.visible = false
	for c in _choices.get_children():
		c.queue_free()
	for i in options.size():
		var b := Pal.button(options[i])
		b.custom_minimum_size = Vector2(260, 22)
		b.pressed.connect(func(): _picked.emit(i))
		_choices.add_child(b)
	_choices.position = Vector2(364, 256 - options.size() * 26)
	var picked: int = await _picked
	for c in _choices.get_children():
		c.queue_free()
	visible = false
	Game.unfreeze()
	return picked


func _gui_input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_next.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _waiting and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
			get_viewport().set_input_as_handled()
			_next.emit()
		elif not _waiting and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var n: int = event.keycode - KEY_1
			if n < _choices.get_child_count():
				get_viewport().set_input_as_handled()
				_picked.emit(n)
