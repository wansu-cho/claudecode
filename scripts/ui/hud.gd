extends Control
## 화면 위쪽 정보입니다.
## 왼쪽: 몇 번째 밤, 시각, 밤 진행 막대 / 오른쪽: 관측 일지 버튼
## (이동, 점프, 확인은 가상 키패드와 키보드로 합니다)

const WorldScript := preload("res://scripts/world.gd")

signal journal_pressed

var world: Control
var _journal_btn: Button


## 관측 일지에 새 기록이 들어오면 버튼이 반짝입니다.
func flash() -> void:
	var tw := create_tween()
	_journal_btn.modulate = Color(2.0, 1.8, 0.8)
	_journal_btn.scale = Vector2(1.15, 1.15)
	tw.set_parallel()
	tw.tween_property(_journal_btn, "modulate", Color.WHITE, 0.5)
	tw.tween_property(_journal_btn, "scale", Vector2.ONE, 0.3)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_btn = Pal.button("관측 일지")
	_journal_btn.position = Vector2(524, 6)
	_journal_btn.custom_minimum_size = Vector2(110, 24)
	_journal_btn.pivot_offset = Vector2(55, 12)
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
	# 보름달 아이콘 (월식이 있는 보름날 밤)
	draw_circle(Vector2(18, 16), 5, Pal.GOLD)
	draw_string(font, Vector2(28, 20), ("%d번째 밤" % Game.loop) if Game.realized else "12월 13일", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
	draw_string(font, Vector2(150, 20), Game.clock(), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 밤 진행 막대 (17:00 → 07:30), 분홍 점: 21:30 물때 (돌쇠가 떠날 수 있는 마지막 시각)
	var bar := Rect2(12, 27, 188, 3)
	draw_rect(bar, Color(0.25, 0.22, 0.4))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(Game.minutes / Game.NIGHT_LEN, 0.0, 1.0), 3)), Pal.CYAN)
	var tide := bar.position.x + bar.size.x * Game.at(WorldScript.TIDE_END) / Game.NIGHT_LEN
	draw_rect(Rect2(tide, 25, 1, 7), Pal.PINK)
	# 지금 있는 곳
	if world:
		var place: String = world.place_name()
		var pw := font.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL).x + 16
		var pr := Rect2((Pal.SCREEN.x - pw) / 2.0, 8, pw, 18)
		draw_rect(pr, Pal.PANEL)
		draw_string(font, pr.position + Vector2(8, 13), place, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.CYAN)
	# 폰을 세로로 들고 있으면 안내
	var win := DisplayServer.window_get_size()
	if win.y > win.x:
		draw_rect(Rect2(0, 150, Pal.SCREEN.x, 60), Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 186), "폰을 가로로 돌려 주세요", HORIZONTAL_ALIGNMENT_CENTER, Pal.SCREEN.x, Pal.BIG, Pal.GOLD)
