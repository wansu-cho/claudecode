extends Control
## 마지막 화면: 「창백한 푸른 점」
## 1990년 보이저 1호가 찍은 사진을 픽셀로 다시 그리고, 이야기를 한 줄씩 보여 줍니다.
## (실제 NASA 사진을 쓰고 싶으면 assets/images/pale_blue_dot.png 파일을 넣으면 그 사진을 씁니다)

signal done

const PHOTO_PATH := "res://assets/images/pale_blue_dot.png"
const DOT := Vector2(452, 150)   # 지구 점의 위치

var page := 0
var _t := 0.0
var _photo: Texture2D = null
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(PHOTO_PATH):
		_photo = load(PHOTO_PATH)

	_label = Pal.label("", Pal.SMALL, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_left = 24
	_label.offset_right = -24
	_label.offset_top = -110
	_label.offset_bottom = -8
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_show_page()


func _pages() -> Array:
	var grade := "보고서 완성"
	if GameState.data >= 90:
		grade = "완벽한 보고서"
	elif GameState.data >= 60:
		grade = "훌륭한 보고서"
	return [
		"[최종 보고]\n1990년 2월 14일, 보이저 1호가 약 60억 km 밖에서 뒤돌아 찍은 사진이다.",
		"빛줄기 속 아주 작은 점 하나.\n이것이 우리가 조사한 행성, 지구다.",
		"그리고 사실...\n지금 여러분이 서 있는 곳이다.",
		"탐사 데이터 %d%% 수집 · %s\n\n지구의 우주 주소\n%s\n\n모두 함께 소리 내어 읽어 보자!" % [GameState.data, grade, StageData.COSMIC_ADDRESS],
	]


func _show_page() -> void:
	_label.text = _pages()[page]
	# 마지막 장은 사진 없이 글만 크게 보여 줍니다.
	_label.offset_top = -330 if page >= 3 else -110
	_t = 0.0


func _next() -> void:
	if page < _pages().size() - 1:
		page += 1
		_show_page()
	else:
		done.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_next()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if page >= 3:
		return
	var photo_rect := Rect2(80, 30, 480, 210)
	if _photo != null:
		draw_texture_rect(_photo, photo_rect, false)
	else:
		_draw_pixel_photo(photo_rect)
	if page >= 1 and int(_t * 2.0) % 2 == 0:
		Pal.ring(self, DOT, 6, Pal.ACCENT)


## 원본 사진처럼, 흩어진 햇빛 줄기 속에 아주 작은 푸른 점을 그립니다.
func _draw_pixel_photo(r: Rect2) -> void:
	draw_rect(r, Color("050505"))
	var bands := [
		[200.0, 26.0, Color(0.55, 0.42, 0.30, 0.20)],
		[290.0, 36.0, Color(0.70, 0.55, 0.40, 0.22)],
		[452.0, 30.0, Color(0.75, 0.55, 0.38, 0.28)],
		[520.0, 18.0, Color(0.50, 0.45, 0.55, 0.16)],
	]
	for b in bands:
		var cx: float = b[0]
		var w: float = b[1]
		for y in range(int(r.position.y), int(r.end.y)):
			# 사진의 빛줄기는 살짝 기울어져 있습니다.
			var x := cx + (y - r.position.y) * 0.08 - w / 2.0
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + w, r.end.x)
			if x1 > x0:
				draw_rect(Rect2(x0, y, x1 - x0, 1), b[2])
	draw_rect(Rect2(DOT, Vector2.ONE), Color("a8c8ff"))
