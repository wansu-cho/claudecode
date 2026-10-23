extends Control
## 화면 위쪽 정보입니다.
## 왼쪽: 몇 번째 밤, 시각, 밤 진행 막대 / 오른쪽: 관측 일지 버튼
## (이동, 점프, 확인은 가상 키패드와 키보드로 합니다)

signal journal_pressed

var _journal_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_btn = Pal.button("관측 일지")
	_journal_btn.position = Vector2(524, 6)
	_journal_btn.custom_minimum_size = Vector2(110, 24)
	_journal_btn.pressed.connect(func(): journal_pressed.emit())
	add_child(_journal_btn)


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
	# 밤 진행 막대 (17:30 → 07:30), 분홍 점: 23시 물때
	var bar := Rect2(12, 27, 188, 3)
	draw_rect(bar, Color(0.25, 0.22, 0.4))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * Game.minutes / Game.NIGHT_LEN, 3)), Pal.CYAN)
	var tide := bar.position.x + bar.size.x * Game.at("23:00") / Game.NIGHT_LEN
	draw_rect(Rect2(tide, 25, 1, 7), Pal.PINK)
	# 폰을 세로로 들고 있으면 안내
	var win := DisplayServer.window_get_size()
	if win.y > win.x:
		draw_rect(Rect2(0, 150, Pal.SCREEN.x, 60), Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 186), "폰을 가로로 돌려 주세요", HORIZONTAL_ALIGNMENT_CENTER, Pal.SCREEN.x, Pal.BIG, Pal.GOLD)
