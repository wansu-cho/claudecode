extends Control
## 화면 위아래의 정보와 터치 버튼입니다.
## 위: 몇 번째 밤, 시각, 밤 진행 막대 / 관측 일지 버튼
## 아래: ◀ ▶ (누르고 있는 동안 이동), 확인 버튼

signal journal_pressed
signal action_pressed

var world: Control
var _journal_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_journal_btn = Pal.button("관측 일지")
	_journal_btn.position = Vector2(530, 6)
	_journal_btn.custom_minimum_size = Vector2(104, 20)
	_journal_btn.pressed.connect(func(): journal_pressed.emit())
	add_child(_journal_btn)

	for spec in [["◀", Vector2(10, 318), -1], ["▶", Vector2(54, 318), 1]]:
		var b := Pal.button(spec[0], Pal.BIG)
		b.position = spec[1]
		b.custom_minimum_size = Vector2(38, 34)
		var dir: int = spec[2]
		b.button_down.connect(func(): _hold(dir, true))
		b.button_up.connect(func(): _hold(dir, false))
		add_child(b)
	var ok := Pal.button("확인", Pal.BIG)
	ok.position = Vector2(560, 318)
	ok.custom_minimum_size = Vector2(70, 34)
	ok.pressed.connect(func(): action_pressed.emit())
	add_child(ok)


func _hold(dir: int, on: bool) -> void:
	if world == null:
		return
	if dir < 0:
		world.hold_left = on
	else:
		world.hold_right = on


func _process(_delta: float) -> void:
	_journal_btn.text = "관측 일지 %d/%d" % [Game.facts.size(), Story.FACT_ORDER.size()]
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(6, 6, 200, 30)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.LINE, false, 1.0)
	# 초승달 아이콘
	draw_circle(Vector2(18, 16), 5, Pal.GOLD)
	draw_circle(Vector2(20, 14), 5, Pal.PANEL)
	draw_string(font, Vector2(28, 20), "%d번째 밤" % Game.loop, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
	draw_string(font, Vector2(150, 20), Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 밤 진행 막대 (17:30 → 07:30), 빨간 점: 23시 물때
	var bar := Rect2(12, 27, 188, 3)
	draw_rect(bar, Color(0.25, 0.22, 0.4))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * Game.minutes / Game.NIGHT_LEN, 3)), Pal.CYAN)
	var tide := bar.position.x + bar.size.x * Game.at("23:00") / Game.NIGHT_LEN
	draw_rect(Rect2(tide, 25, 1, 7), Pal.PINK)
