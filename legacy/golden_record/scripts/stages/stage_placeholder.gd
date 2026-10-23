extends StageBase
## 아직 만들지 않은 단계 자리입니다.
## 어떤 내용이 들어갈지 보여 주고, 누르면 통과합니다.


func _build() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 80
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(Pal.label(stage["title"], Pal.BIG, Pal.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Pal.label("[제작 중인 임무]", Pal.SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Pal.label(stage["summary"], Pal.SMALL, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER))


func get_instruction() -> String:
	return "이 임무는 아직 만드는 중이다. 화면을 누르거나 Enter를 누르면 통과."


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_pass()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_pass()


func _pass() -> void:
	done = true
	finish("group" if group_mode else "success")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.BG)
	draw_instruction_bar()
