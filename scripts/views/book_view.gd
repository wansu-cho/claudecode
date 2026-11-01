extends Control
## 1층 책방의 어린이천문대 교재입니다. 관측으로 알아낸 것의 개념을 확인할 수 있습니다.
## 읽는 동안에는 시간이 멈춥니다.

signal closed

var _page: Label
var _title: Label
var page_i := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()
	var head := Pal.label("어린이천문대 교재 · 우리가 사는 지구와 우주", Pal.BIG, Pal.GOLD)
	head.position = Vector2(20, 10)
	head.size = Vector2(600, 24)
	add_child(head)
	var list := VBoxContainer.new()
	list.position = Vector2(16, 44)
	list.add_theme_constant_override("separation", 3)
	add_child(list)
	for i in Story.BOOK.size():
		var b := Pal.button(Story.BOOK[i]["title"])
		b.custom_minimum_size = Vector2(212, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.pressed.connect(open_page.bind(i))
		list.add_child(b)
	_title = Pal.label("", Pal.SMALL, Pal.CYAN)
	_title.position = Vector2(248, 48)
	_title.size = Vector2(376, 18)
	add_child(_title)
	_page = Pal.label("", Pal.SMALL, Color8(60, 48, 40))
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.position = Vector2(252, 74)
	_page.size = Vector2(368, 248)
	add_child(_page)
	var back := Pal.button("나가기")
	back.position = Vector2(560, 332)
	back.pressed.connect(close)
	add_child(back)
	open_page(0)


func open_page(i: int) -> void:
	page_i = i
	_title.text = Story.BOOK[i]["title"]
	_page.text = Story.BOOK[i]["text"]
	queue_redraw()


func close() -> void:
	Game.unfreeze()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				close()
			KEY_UP, KEY_W:
				get_viewport().set_input_as_handled()
				open_page(wrapi(page_i - 1, 0, Story.BOOK.size()))
			KEY_DOWN, KEY_S:
				get_viewport().set_input_as_handled()
				open_page(wrapi(page_i + 1, 0, Story.BOOK.size()))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(30, 26, 44))
	var paper := Rect2(240, 40, 388, 286)
	draw_rect(paper, Color8(244, 236, 214))
	draw_rect(Rect2(paper.position.x, paper.position.y, 6, paper.size.y), Color8(200, 150, 90))
	draw_rect(Rect2(paper.position.x + 10, paper.position.y + 26, paper.size.x - 20, 1), Color8(200, 186, 160))
	draw_rect(Rect2(paper.position.x - 4, paper.position.y + 2, 1, paper.size.y), Color8(0, 0, 0, 80))
