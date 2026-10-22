extends SceneTree
## 자동 점검용 스크립트입니다. (게임에는 포함되지 않습니다)
## 처음부터 끝까지 자동으로 한 판을 플레이하고, 중간 화면을 사진으로 저장합니다.
##
## 실행 예:
##   godot --path . --script res://tests/autoplay.gd -- 7 /저장할/폴더
##   (7 = 참가 인원, 폴더를 적지 않으면 사진은 저장하지 않습니다)

var players := 7
var shot_dir := ""
var main: Node
var shots := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		players = int(args[0])
	if args.size() > 1:
		shot_dir = args[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_play()


func _play() -> void:
	await _frames(5)
	await _shot("title")
	_key(KEY_ENTER)
	await _frames(3)
	await _shot("setup")
	_key(KEY_0 if players == 10 else KEY_0 + players)
	await _frames(3)
	await _shot("assign")
	_key(KEY_ENTER)
	await _frames(3)
	await _shot("briefing")
	_key(KEY_ENTER)

	var guard := 0
	while guard < 400:
		guard += 1
		await _frames(3)
		var cur = main._current
		if cur == null:
			continue
		var script_path: String = cur.get_script().resource_path
		if script_path.ends_with("ending_screen.gd"):
			for i in 4:
				await _shot("ending_%d" % i)
				_key(KEY_ENTER)
				await _frames(3)
			print("AUTOPLAY OK: data=%d players=%d" % [root.get_node("GameState").data, players])
			quit(0)
			return
		if cur is StageBase:
			await _play_stage(cur)
		elif cur is CardScreen:
			await _shot("card")
			_key(KEY_ENTER)
	push_error("AUTOPLAY: 끝까지 가지 못했습니다")
	quit(1)


func _play_stage(stage: StageBase) -> void:
	var kind: String = stage.stage["kind"]
	var tag := "stage%02d_%s" % [stage.stage["id"], "group" if stage.group_mode else "solo"]
	await _shot(tag + "_start")
	match kind:
		"star_dipper":
			# 틀린 별 한 번, 진짜 마우스 클릭으로 정답 두 개
			stage._press_at(stage.pos["alkaid"])
			_click(stage.pos["merak"])
			await _frames(2)
			_click(stage.pos["dubhe"])
			await _frames(2)
			await _wait(1.2)
			await _shot(tag + "_guide")
			await _wait(1.5)
			stage._press_at(stage.pos["kochab"])
			await _wait(0.4)
			stage._press_at(stage.pos["polaris"])
			await _wait(0.3)
			await _shot(tag + "_done")
		"star_cassiopeia":
			stage._press_id("side_inner_a")
			await _wait(0.4)
			stage._press_id("side_outer_a")
			await _wait(0.4)
			stage._press_id("side_outer_b")
			await _frames(2)
			await _shot(tag + "_meet")
			stage._press_id("navi")
			await _wait(2.8)
			await _shot(tag + "_guide")
			stage._press_id("polaris")
			await _wait(0.3)
			await _shot(tag + "_done")
		"quiz":
			if stage.group_mode:
				_key(KEY_ENTER)
				await _frames(3)
				await _shot(tag + "_reveal")
				_key(KEY_ENTER)
			else:
				var wrong_i: int = (stage.quiz["answer"] + 1) % 3
				_key(KEY_1 + wrong_i)
				await _wait(0.4)
				_key(KEY_1 + stage.quiz["answer"])
				await _frames(3)
				await _shot(tag + "_reveal")
				_key(KEY_ENTER)
		_:
			_key(KEY_ENTER)
	# 단계가 끝날 때까지 기다림
	var t := 0
	while is_instance_valid(stage) and stage.is_inside_tree() and main._current == stage and t < 300:
		await _frames(1)
		t += 1


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


## 게임 화면(640x360) 좌표에 마우스(펜) 클릭을 보냅니다. 실제 화면 입력과 같은 길로 들어갑니다.
func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		root.push_input(e, true)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await _frames(2)
	shots += 1
	var img := root.get_texture().get_image()
	img.save_png("%s/%03d_%s.png" % [shot_dir, shots, name])
