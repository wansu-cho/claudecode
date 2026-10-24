extends Control
## 관측 일지입니다. 루프가 돌아도 지워지지 않습니다.
## 보기 모드: 사실을 눌러 자세히 읽기
## 고르기 모드: 증거로 보여 줄 사실을 최대 2개 고르기 → picked 신호

signal picked(ids: Array)
signal closed

var pick_mode := false
var max_pick := 2
var _selected: Array = []
var _list: VBoxContainer
var _detail: Label
var _ok: Button
var _focus := ""


func _init(pick := false) -> void:
	pick_mode = pick


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.freeze()

	var title := "관측 일지" if not pick_mode else "어떤 증거를 보여 줄까? (최대 %d개)" % max_pick
	var head := Pal.label(title, Pal.BIG, Pal.GOLD)
	head.position = Vector2(24, 14)
	head.size = Vector2(592, 28)
	add_child(head)
	var address := []
	for id in Game.freed:
		address.append(Story.ADDRESS[Story.PIECE_OF[id]])
	var sub := Pal.label("알아낸 사실 %d/%d   ·   우주 주소 조각 %d/7  %s" % [Game.facts.size(), Story.FACT_ORDER.size(), Game.pieces(), ", ".join(PackedStringArray(address))], Pal.SMALL, Pal.DIM)
	sub.position = Vector2(26, 44)
	sub.size = Vector2(592, 16)
	add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 66)
	scroll.size = Vector2(256, 226)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)
	for id in Story.FACT_ORDER:
		var known := Game.has(id)
		var b := Pal.button(Story.FACTS[id]["title"] if known else "???")
		b.custom_minimum_size = Vector2(244, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not known
		b.pressed.connect(_on_fact.bind(id, b))
		_list.add_child(b)

	_detail = Pal.label("사실을 누르면 자세히 볼 수 있다.", Pal.SMALL, Pal.TEXT)
	_detail.position = Vector2(292, 70)
	_detail.size = Vector2(324, 200)
	add_child(_detail)

	var row := HBoxContainer.new()
	row.position = Vector2(292, 300)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	if pick_mode:
		_ok = Pal.button("이걸 보여 준다")
		_ok.disabled = true
		_ok.pressed.connect(_confirm)
		row.add_child(_ok)
	var close := Pal.button("닫기" if not pick_mode else "그만두기")
	close.pressed.connect(_cancel)
	row.add_child(close)


func _on_fact(id: String, b: Button) -> void:
	_detail.text = Story.FACTS[id]["text"]
	if not pick_mode:
		return
	if id in _selected:
		_selected.erase(id)
		b.add_theme_stylebox_override("normal", Pal.box_style())
	elif _selected.size() < max_pick:
		_selected.append(id)
		b.add_theme_stylebox_override("normal", Pal.box_style(Color(0.2, 0.18, 0.06, 0.95), Pal.GOLD))
	_ok.disabled = _selected.is_empty()


func _confirm() -> void:
	Game.unfreeze()
	picked.emit(_selected.duplicate())
	queue_free()


func _cancel() -> void:
	Game.unfreeze()
	if pick_mode:
		picked.emit([])
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_J]:
		get_viewport().set_input_as_handled()
		_cancel()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, 0.95))
	draw_rect(Rect2(284, 64, 336, 228), Pal.PANEL)
	draw_rect(Rect2(284, 64, 336, 228), Pal.LINE, false, 1.0)
