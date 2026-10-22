extends Control
## 화면 맨 위의 정보 띠입니다.
## 왼쪽: 지금 임무 / 가운데: 반 전체의 탐사 데이터 / 오른쪽: 남은 시간과 대원 번호

var mission_text := ""
var player_text := ""
var stage: StageBase = null     # 남은 시간을 보여 줄 단계 (없으면 표시 안 함)
var toast := ""                 # 잠깐 보여 주는 알림 (보너스 등)

var _flash := 0.0
var _toast_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.data_changed.connect(func(_v): _flash = 1.0)


func show_toast(text: String) -> void:
	toast = text
	_toast_t = 2.0


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_toast_t = maxf(_toast_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, Pal.SCREEN.x, 24), Pal.PANEL)
	draw_rect(Rect2(0, 24, Pal.SCREEN.x, 1), Pal.LINE)
	draw_string(font, Vector2(8, 17), mission_text, HORIZONTAL_ALIGNMENT_LEFT, 200, Pal.SMALL, Pal.TEXT)

	# 탐사 데이터 막대
	var bar := Rect2(300, 7, 120, 10)
	draw_string(font, Vector2(226, 17), "탐사 데이터", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_rect(bar, Pal.BG)
	var fill := bar
	fill.size.x = bar.size.x * GameState.data / 100.0
	draw_rect(fill, Pal.GOLD if _flash > 0.0 and int(_flash * 8) % 2 == 0 else Pal.ACCENT)
	draw_rect(bar, Pal.LINE, false, 1.0)
	draw_string(font, Vector2(426, 17), "%d%%" % GameState.data, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)

	var right := player_text
	if stage != null and is_instance_valid(stage) and not stage.done:
		var t := ceili(stage.time_left())
		right = "%d:%02d  %s" % [t / 60, t % 60, player_text]
	draw_string(font, Vector2(Pal.SCREEN.x - 8 - 160, 17), right, HORIZONTAL_ALIGNMENT_RIGHT, 160, Pal.SMALL, Pal.TEXT)

	if _toast_t > 0.0:
		var w := 220.0
		var r := Rect2((Pal.SCREEN.x - w) / 2.0, 32, w, 20)
		draw_rect(r, Pal.PANEL)
		draw_rect(r, Pal.GOLD, false, 1.0)
		draw_string(font, r.position + Vector2(0, 15), toast, HORIZONTAL_ALIGNMENT_CENTER, w, Pal.SMALL, Pal.GOLD)
