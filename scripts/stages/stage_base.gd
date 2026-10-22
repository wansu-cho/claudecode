class_name StageBase
extends Control
## 모든 단계(임무)가 함께 쓰는 규칙입니다.
##
## - 60초가 지나면 힌트가 자동으로 나옵니다.
## - 90초가 지나면 본부 지원으로 정답을 보여 주고 자동으로 넘어갑니다.
## - 틀리면 밋밋한 반응만 보입니다. (화려한 연출은 정답일 때만)
## - 오답이 3번 쌓이면 힌트가 나옵니다.
## - 아주 빠르게 연타하면 2초 동안 입력을 막습니다.

## result: "success"(스스로 해냄), "assisted"(본부 지원), "group"(전원 참여), "skipped"(건너뜀)
signal finished(result: String)

const HINT_TIME := 60.0
const AUTO_TIME := 90.0
const SPAM_TAPS := 4         # 1초 안에 이만큼 넘게 누르면 연타로 봅니다
const SPAM_LOCK := 2.0

var stage: Dictionary
var group_mode := false
var elapsed := 0.0
var hint_shown := false
var done := false
var wrong_count := 0
var auto_result := "assisted"   # 시간이 다 되었을 때의 결과
var auto_wait := 4.0            # 시간이 다 된 뒤 다음으로 넘어가기까지 기다리는 시간

var message := ""
var message_color := Pal.TEXT

var _finished := false
var _tap_times: Array[float] = []
var _locked_until := 0.0
var _celebrate_at := Vector2(-1, -1)
var _celebrate_t := -1.0


func setup(stage_info: Dictionary, is_group: bool) -> void:
	stage = stage_info
	group_mode = is_group


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _process(delta: float) -> void:
	elapsed += delta
	if _celebrate_t >= 0.0:
		_celebrate_t += delta
	if not done:
		if elapsed >= HINT_TIME and not hint_shown:
			show_hint()
		if elapsed >= AUTO_TIME:
			auto_solve()
	queue_redraw()


func time_left() -> float:
	return maxf(AUTO_TIME - elapsed, 0.0)


## 화면에 보이는 안내 문구 (아래쪽 띠에 표시됩니다)
func get_instruction() -> String:
	return ""


# ---- 하위 단계가 필요하면 바꿔 쓰는 함수들 ----

func _build() -> void:
	pass


func _on_hint() -> void:
	pass


func _on_auto_solve() -> void:
	pass


# ---- 공통 동작 ----

## 누를 때마다 먼저 이것을 불러 연타인지 검사합니다. false면 입력을 무시합니다.
func accept_tap() -> bool:
	if done:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < _locked_until:
		return false
	_tap_times.append(now)
	while not _tap_times.is_empty() and now - _tap_times[0] > 1.0:
		_tap_times.pop_front()
	if _tap_times.size() > SPAM_TAPS:
		_locked_until = now + SPAM_LOCK
		_tap_times.clear()
		say("입력 과부하. 잠시 대기...", Pal.DIM)
		return false
	return true


func say(text: String, color := Pal.TEXT) -> void:
	message = text
	message_color = color


func wrong(text := "다시 분석하라.") -> void:
	wrong_count += 1
	say(text, Pal.DIM)
	if wrong_count >= 3 and not hint_shown:
		show_hint()


func show_hint() -> void:
	if hint_shown or done:
		return
	hint_shown = true
	_on_hint()


func succeed(at := Vector2(-1, -1)) -> void:
	if done:
		return
	done = true
	_celebrate_at = at
	_celebrate_t = 0.0
	say("임무 성공!", Pal.GOLD)
	_finish_later("success", 1.6)


func auto_solve() -> void:
	if done:
		return
	done = true
	say("본부 지원: 정답 경로를 전송한다.", Pal.ACCENT)
	_on_auto_solve()
	_finish_later(auto_result, auto_wait)


func skip() -> void:
	done = true
	finish("skipped")


## 결과를 알리고 단계를 끝냅니다. 여러 번 불려도 한 번만 알립니다.
func finish(result: String) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(result)


func _finish_later(result: String, seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree():
		finish(result)


## 정답일 때만 나오는 반짝이는 연출입니다.
func draw_celebration() -> void:
	if _celebrate_t < 0.0 or _celebrate_at.x < 0.0:
		return
	var t := _celebrate_t
	if t > 1.6:
		return
	var r := int(4 + t * 60)
	var c := Pal.GOLD
	c.a = 1.0 - t / 1.6
	Pal.ring(self, _celebrate_at, r, c)
	Pal.ring(self, _celebrate_at, int(r * 0.6), c)
	for i in 8:
		var ang := TAU * i / 8.0 + t
		var p := _celebrate_at + Vector2.from_angle(ang) * (r * 0.8)
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), c)


## 아래쪽 안내 띠 (안내 문구 + 짧은 메시지)
func draw_instruction_bar() -> void:
	var font := get_theme_default_font()
	var y := Pal.SCREEN.y - 40
	draw_rect(Rect2(0, y, Pal.SCREEN.x, 40), Pal.PANEL)
	draw_rect(Rect2(0, y, Pal.SCREEN.x, 1), Pal.LINE)
	draw_string(font, Vector2(12, y + 16), get_instruction(), HORIZONTAL_ALIGNMENT_LEFT, Pal.SCREEN.x - 24, Pal.SMALL, Pal.TEXT)
	if message != "":
		draw_string(font, Vector2(12, y + 32), message, HORIZONTAL_ALIGNMENT_LEFT, Pal.SCREEN.x - 24, Pal.SMALL, message_color)
