extends Control
## 게임 전체의 흐름을 정하는 곳입니다.
##
## 시작 화면 → 인원 입력 → 단계 배정 발표 → 임무 브리핑
## → (단계마다) 장 소개 → 대원 교대 → 예측 → 임무 → 결과
## → 마지막 화면 → 다시 시작 화면
##
## 진행자(선생님) 전용 키
##   Space : 일시정지 / 계속
##   H     : 힌트 바로 보여 주기
##   N     : 지금 단계(화면) 건너뛰기
##   B     : 예측 보너스 (단계마다 한 번)
##   F11   : 전체 화면 켜기/끄기

const HudScript := preload("res://scripts/screens/hud.gd")
const SetupScript := preload("res://scripts/screens/setup_screen.gd")
const EndingScript := preload("res://scripts/screens/ending_screen.gd")
const STAGE_SCRIPTS := {
	"star_dipper": preload("res://scripts/stages/stage_dipper.gd"),
	"star_cassiopeia": preload("res://scripts/stages/stage_cassiopeia.gd"),
	"quiz": preload("res://scripts/stages/stage_quiz.gd"),
	"placeholder": preload("res://scripts/stages/stage_placeholder.gd"),
}
const PREDICTION_SECONDS := 10.0

var _layer: Control          # 지금 화면이 들어가는 자리
var _hud: Control
var _pause_label: Label
var _current: Control = null
var _bonus_used := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_layer)

	_hud = HudScript.new()
	_hud.visible = false
	add_child(_hud)

	_pause_label = Pal.label("일시정지  (Space를 누르면 계속)", Pal.BIG, Pal.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.custom_minimum_size = Vector2(Pal.SCREEN.x, 40)
	_pause_label.position = Vector2(0, Pal.SCREEN.y / 2 - 20)
	_pause_label.add_theme_stylebox_override("normal", Pal.box_style())
	_pause_label.visible = false
	add_child(_pause_label)

	_run()


func _run() -> void:
	while true:
		await _play_once()


func _play_once() -> void:
	_hud.visible = false
	await _card("프로젝트 골든 레코드", [
		"어린이천문대 탐사대 임무",
		"",
		"진행자 키:  Space 일시정지 · H 힌트 · N 건너뛰기 · B 예측 보너스 · F11 전체 화면",
	], "화면을 누르거나 Enter를 누르면 시작")

	var setup: Control = _show(SetupScript.new())
	var count: int = await setup.chosen
	GameState.new_game(count)

	await _card("탐사대 임무 배정", _assignment_lines())

	_hud.visible = true
	_hud.mission_text = "임무 브리핑"
	_hud.player_text = ""
	await _card("", StageData.BRIEFING)

	var last_chapter := 0
	for s in StageData.STAGES:
		var id: int = s["id"]
		var chapter: int = s["chapter"]
		var group := GameState.is_group(id)
		_bonus_used = false
		_hud.mission_text = "%s · %02d" % [StageData.CHAPTERS[chapter]["title"].replace("  ", " "), id]
		_hud.player_text = "전원 참여" if group else "대원 %d번" % GameState.assignments[id]

		if chapter != last_chapter:
			last_chapter = chapter
			await _card(StageData.CHAPTERS[chapter]["title"], [StageData.CHAPTERS[chapter]["story"]])

		await _handover(s, group)

		if s.has("prediction") and not group:
			await _prediction(s["prediction"])

		var stage: StageBase = STAGE_SCRIPTS[s["kind"]].new()
		stage.setup(s, group)
		_show(stage)
		_hud.stage = stage
		var result: String = await stage.finished
		_hud.stage = null

		await _result(s, result)

	_hud.visible = false
	var ending: Control = _show(EndingScript.new())
	await ending.done


# ---- 화면 만들기 ----

func _show(screen: Control) -> Control:
	if _current != null:
		_current.queue_free()
	_current = screen
	_layer.add_child(screen)
	return screen


func _card(title: String, lines: Array, footer := "화면을 누르거나 Enter를 누르면 계속") -> void:
	var card := CardScreen.new(title, lines, footer)
	_show(card)
	await card.advanced


func _assignment_lines() -> Array:
	var lines := []
	var ids := StageData.STAGES.map(func(s): return s["id"])
	for i in range(0, ids.size(), 2):
		var parts := []
		for id in ids.slice(i, i + 2):
			var who := "전원 참여" if GameState.is_group(id) else "대원 %d번" % GameState.assignments[id]
			parts.append("임무 %02d → %s" % [id, who])
		lines.append("      ".join(PackedStringArray(parts)))
	lines.append("")
	lines.append("%d명 참가 · 모든 대원이 한 번씩 임무를 맡는다." % GameState.player_count)
	return lines


func _handover(s: Dictionary, group: bool) -> void:
	var id: int = s["id"]
	var card: CardScreen
	if group:
		card = CardScreen.new("임무 %02d · 전원 참여" % id, [s["title"]])
		card.add_line("이번 임무는 모두 함께 푼다!", Pal.GOLD, Pal.BIG)
		card.add_line("자리에서 손가락으로 답할 준비를 하라.")
	else:
		card = CardScreen.new("임무 %02d" % id, [s["title"]])
		card.add_line("탐사대원 %d번, 앞으로!" % GameState.assignments[id], Pal.GOLD, Pal.BIG)
		var next := GameState.next_player_after(id)
		if next > 0:
			card.add_line("다음 대기(부조종사): %d번 대원은 옆에 서 주세요." % next, Pal.DIM)
	_show(card)
	await card.advanced


func _prediction(p: Dictionary) -> void:
	var lines := [p["question"], ""]
	var choices: Array = p["choices"]
	for i in choices.size():
		lines.append("%d. %s" % [i + 1, choices[i]])
	lines.append("")
	lines.append("모두 손가락으로 예측하라!")
	var card := CardScreen.new("예측 타임", lines, "Enter를 누르면 바로 임무 시작")
	card.countdown = PREDICTION_SECONDS
	card.allow_tap = false
	_show(card)
	await card.advanced


func _result(s: Dictionary, result: String) -> void:
	var titles := {
		"success": "임무 성공!",
		"assisted": "본부 지원으로 임무 완료",
		"group": "전원 임무 완료!",
		"skipped": "임무 통과",
	}
	var gains := {
		"success": GameState.GAIN_SUCCESS,
		"assisted": GameState.GAIN_ASSISTED,
		"group": GameState.GAIN_GROUP,
		"skipped": GameState.GAIN_ASSISTED,
	}
	var gain: int = gains.get(result, GameState.GAIN_ASSISTED)
	GameState.add_data(gain)

	var card := CardScreen.new(titles.get(result, "임무 완료"), ["탐사 데이터 +%d%%" % gain],
		"진행자: 예측이 맞은 대원이 많으면 B (보너스) · Enter로 계속")
	if s.has("prediction"):
		var p: Dictionary = s["prediction"]
		card.add_line("예측 정답: %d번. %s" % [p["answer"] + 1, p["choices"][p["answer"]]], Pal.ACCENT)
		card.add_line(p["explain"])
	_show(card)
	await card.advanced


# ---- 진행자 키 ----

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			get_tree().paused = not get_tree().paused
			_pause_label.visible = get_tree().paused
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_H:
			if _current is StageBase and not get_tree().paused:
				(_current as StageBase).show_hint()
		KEY_N:
			if get_tree().paused:
				return
			if _current is StageBase:
				(_current as StageBase).skip()
			elif _current is CardScreen:
				(_current as CardScreen).advance()
			else:
				return
		KEY_B:
			if not _hud.visible or _bonus_used or get_tree().paused:
				return
			_bonus_used = true
			GameState.add_data(GameState.GAIN_BONUS)
			_hud.show_toast("예측 보너스! 탐사 데이터 +%d%%" % GameState.GAIN_BONUS)
		_:
			return
	get_viewport().set_input_as_handled()
