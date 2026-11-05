extends SceneTree
## 전체 점검: 저장 → 다시 켜서 '이어 하기' → 세 번째 밤 → 모든 자리를 한 번씩 살펴보기
##   godot --path . --script res://tests/audit.gd     끝에 "AUDIT OK" 또는 "AUDIT FAIL"
var main: Node
var game: Node
var w: Node
var fails := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	game = root.get_node("Game")
	# 1) 세 번째 밤까지 진행한 저장 파일을 만듦 (사실 몇 개, 깨운 손님, 도운 손님 하나)
	game.new_game()
	game.loop = 3
	game.realized = true
	for f in ["note", "sunset", "pendulum", "keti_story"]:
		game.facts[f] = true
	game.woken["keti"] = true
	game.met["keti"] = true
	game.freed["dolsoe"] = true
	game.save()
	# 2) 게임을 켜고 '이어 하기'
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	_key(KEY_ENTER)                                  # 첫 단추 = 이어 하기
	await _frames(6)
	w = main.world
	_check(not w.prologue, "이어 하기: 프롤로그 없이 시작")
	_check(game.loop == 3 and game.realized, "이어 하기: 세 번째 밤, 루프를 아는 상태")
	await _close_all()
	_check(w.npc_state("keti") != "dormant", "깨운 적 있는 케티는 처음부터 깨어 있음")
	_check(w.npc_state("hwi") == "dormant", "깨운 적 없는 휘는 물건 속에서 잠듦")
	_check(w.npc_state("dolsoe") == "freed", "도운 돌쇠는 물건으로 돌아가 있음")
	# 3) 22:00에 모든 자리를 한 번씩 살펴보고 닫기 (오류 없이)
	game.minutes = game.at("22:00")
	var seen := {}
	for s in w.SPOTS:
		var key: String = s["id"] + str(s["floor"])
		if seen.has(key):
			continue
		seen[key] = true
		w.go_floor(int(s["floor"]))
		w.player_x = float(s["x"])
		await _frames(2)
		main._on_interact(s["id"])
		await _frames(4)
		await _close_all()
		_check(not main._busy, "%s: 살펴본 뒤 다시 움직일 수 있음" % s["id"])
	# 4) 해가 뜨면 네 번째 밤
	game.minutes = game.NIGHT_LEN - 0.2
	await _wait(0.5)
	await _close_all()
	await _wait(5.0)
	await _close_all()
	_check(game.loop == 4, "해가 뜬 뒤 네 번째 밤")
	print("AUDIT OK" if fails == 0 else "AUDIT FAIL: %d" % fails)
	quit()


## 떠 있는 대사, 선택지, 퀴즈, 관측 화면, 카드를 모두 닫음
func _close_all() -> void:
	for i in 80:
		await _frames(2)
		var busy := false
		if main.quiz != null and is_instance_valid(main.quiz) and main.quiz.is_inside_tree():
			main.quiz.solve()
			await _wait(1.3)
			busy = true
		var d: Node = main.dialogue
		if d.visible:
			busy = true
			if d._waiting:
				_key(KEY_ENTER)
			else:
				_key(KEY_1 + d._choices.get_child_count() - 1)   # 선택지: 마지막(그만두기 등)
		if main._overlay != null and is_instance_valid(main._overlay):
			busy = true
			if main._overlay.has_method("close"):
				main._overlay.close()
			else:
				main._overlay.queue_free()
		if main.fx.busy():
			busy = true
			main.fx.dismiss()
			await _wait(0.6)
		for c in main.get_children():
			if c.has_signal("done") and c.get_script() and str(c.get_script().resource_path).ends_with("card.gd"):
				busy = true
				_key(KEY_ENTER)
		if not busy:
			return


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("AUDIT FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
