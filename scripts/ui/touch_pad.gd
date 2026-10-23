extends Control
## 폰용 가상 키패드입니다. 화면에 버튼을 두지 않고, 손가락 위치로 조작합니다.
##   화면 왼쪽 절반: 누른 채로 좌우로 끌면 이동 (누른 자리에 패드가 나타남)
##   화면 오른쪽 절반: 탭하면 점프
##   [눌러서 ...] 말풍선: 탭하면 확인/대화
## 손가락 두 개를 동시에 쓸 수 있습니다. (왼손 이동 + 오른손 점프)

signal jump
signal interact

const DEAD := 6.0         # 이 거리보다 적게 끌면 멈춤
const FULL := 34.0        # 이만큼 끌면 최고 속도

var world: Control
var enabled := true
var _move_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _hint_t := 6.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not enabled:
		_release()
		return
	var p: Vector2 = make_input_local(event).position
	if event is InputEventScreenTouch:
		if event.pressed:
			if p.y < 40:
				return                                   # 위쪽 정보 띠 (관측 일지 버튼)
			if world.prompt_rect.has_area() and world.prompt_rect.has_point(p):
				interact.emit()
			elif p.x < size.x / 2.0:
				if _move_index == -1:
					_move_index = event.index
					_origin = p
					_knob = p
			else:
				jump.emit()
			_hint_t = 0.0
		elif event.index == _move_index:
			_release()
	elif event.index == _move_index:
		_knob = p
		var dx := p.x - _origin.x
		world.pad_dir = 0.0 if absf(dx) < DEAD else clampf(dx / FULL, -1.0, 1.0)
		if absf(dx) > FULL * 1.6:                     # 손가락이 멀리 가면 패드가 따라감
			_origin.x = p.x - signf(dx) * FULL * 1.6


func _release() -> void:
	_move_index = -1
	if world:
		world.pad_dir = 0.0


func _process(delta: float) -> void:
	_hint_t = maxf(_hint_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	if _move_index != -1:
		draw_circle(_origin, FULL, Color(1, 1, 1, 0.08))
		draw_arc(_origin, FULL, 0, TAU, 32, Color(1, 1, 1, 0.25), 1.0)
		var k := _origin + Vector2(clampf(_knob.x - _origin.x, -FULL, FULL), 0)
		draw_circle(k, 12, Color(1, 1, 1, 0.3))
	if _hint_t > 0.0 and DisplayServer.is_touchscreen_available():
		var a := minf(_hint_t, 1.0) * 0.8
		var font := get_theme_default_font()
		draw_string(font, Vector2(40, 330), "← 왼쪽: 누른 채 끌어서 이동 →", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(1, 1, 1, a))
		draw_string(font, Vector2(400, 330), "오른쪽: 탭하면 점프", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(1, 1, 1, a))
