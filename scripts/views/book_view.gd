extends Control
## 1층 책방의 어린이천문대 교재입니다. 관측으로 알아낸 것의 개념을 확인할 수 있습니다.
## 펼친 쪽: 왼쪽에 그림(assets/views/book_N.png가 있으면), 오른쪽에 글. 아래 번호 단추로 장을 고릅니다.
## 읽는 동안에는 시간이 멈춥니다.

signal closed

const PAPER := Rect2(16, 34, 608, 290)
const PIC := Rect2(28, 64, 300, 250)          # 그림 자리 (비율을 지켜 맞춤)

var _page: Label
var _title: Label
var page_i := 0
var _pic: Texture2D = null
var _nums: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()
	var head := Pal.label("어린이천문대 교재 · 우리가 사는 지구와 우주", Pal.SMALL, Pal.GOLD)
	head.position = Vector2(20, 10)
	head.size = Vector2(600, 18)
	add_child(head)
	_title = Pal.label("", Pal.SMALL, Color8(40, 60, 130))
	_title.position = Vector2(PAPER.position.x + 14, PAPER.position.y + 8)
	_title.size = Vector2(580, 18)
	add_child(_title)
	_page = Pal.label("", Pal.SMALL, Color8(60, 48, 40))
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_page)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 332)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i in Story.BOOK.size():
		var b := Pal.button("%d" % (i + 1))
		b.custom_minimum_size = Vector2(30, 22)
		b.pressed.connect(open_page.bind(i))
		row.add_child(b)
		_nums.append(b)
	var back := Pal.button("나가기")
	back.position = Vector2(560, 332)
	back.pressed.connect(close)
	add_child(back)
	open_page(0)


func open_page(i: int) -> void:
	page_i = i
	Sfx.play("page", -8.0)
	_title.text = Story.BOOK[i]["title"]
	_page.text = Story.BOOK[i]["text"]
	var path := "res://assets/views/book_%d.png" % (i + 1)
	_pic = load(path) if ResourceLoader.exists(path) else null
	if _pic:                                      # 그림이 있으면 글은 오른쪽 절반
		_page.position = Vector2(PIC.end.x + 14, PIC.position.y)
		_page.size = Vector2(PAPER.end.x - PIC.end.x - 26, PIC.size.y)
	else:
		_page.position = Vector2(PAPER.position.x + 14, PIC.position.y)
		_page.size = Vector2(PAPER.size.x - 28, PIC.size.y)
	for k in _nums.size():
		_nums[k].modulate = Pal.GOLD if k == i else Color.WHITE
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
			KEY_LEFT, KEY_A, KEY_UP, KEY_W:
				get_viewport().set_input_as_handled()
				open_page(wrapi(page_i - 1, 0, Story.BOOK.size()))
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
				get_viewport().set_input_as_handled()
				open_page(wrapi(page_i + 1, 0, Story.BOOK.size()))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(30, 26, 44))
	draw_rect(PAPER, Color8(250, 244, 228))
	draw_rect(Rect2(PAPER.position.x, PAPER.position.y, 6, PAPER.size.y), Color8(200, 150, 90))
	draw_rect(Rect2(PAPER.position.x + 10, PAPER.position.y + 26, PAPER.size.x - 20, 1), Color8(200, 186, 160))
	if _pic:
		var k := minf(PIC.size.x / _pic.get_width(), PIC.size.y / _pic.get_height())
		var sz := Vector2(_pic.get_width(), _pic.get_height()) * k
		draw_texture_rect(_pic, Rect2(PIC.position + Vector2(0, (PIC.size.y - sz.y) / 2.0), sz), false)
		draw_line(Vector2(PIC.end.x + 6, PIC.position.y), Vector2(PIC.end.x + 6, PIC.end.y), Color8(220, 206, 180), 1)
