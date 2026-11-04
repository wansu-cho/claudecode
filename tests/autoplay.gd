extends SceneTree
## 자동 점검: 시제품을 처음부터 끝까지 풀어 봅니다. (게임에는 포함되지 않습니다)
##   godot --path . --script res://tests/autoplay.gd -- [사진 저장 폴더]
## 끝까지 가면 "AUTOPLAY OK"를 출력합니다.

var shot_dir := ""
var main: Node
var game: Node
var w: Node
var shots := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot_dir = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	_run()


func _run() -> void:
	await _frames(5)
	await _shot("title")
	_key(KEY_ENTER)
	await _frames(3)
	# 프롤로그: 15:30 항구 → 마당의 선생님 → 17:00 옥상
	w = main.world
	_check(w.prologue, "프롤로그 시작")
	await _shot("prologue_card")
	_key(KEY_ENTER)
	await _frames(3)
	await _advance()
	main._on_interact("binoculars")
	await _advance()
	_check(not game.has("ship_horizon"), "프롤로그에서는 선생님만 만날 수 있음")
	w.player_x = w.TEACHER_X - 20.0
	await _frames(3)
	await _shot("prologue_teacher")
	main._on_interact("teacher")
	await _advance()
	await _wait(0.8)
	await _advance()
	_check(not w.prologue and w.floor_i == 1 and w.player_x > w.HALL_X1, "프롤로그 뒤 강의실에서 깨어남")
	_check(not game.has("note"), "쪽지는 직접 찾아야 함")
	await _shot("lecture_wake")
	main._on_interact("kids")
	await _advance()
	main._on_interact("note")                        # 2층 사무실 책상 위 쪽지
	await _advance()
	_check(game.has("note"), "쪽지 사실")
	w.go_floor(2)
	w.player_x = w.spot_x("sunset")
	await _frames(3)
	await _shot("roof_start")

	# 0) 옥상 서쪽 난간: 해넘이 (17:08부터 해가 질 때까지 지켜보기)
	game.minutes = game.at("17:08")
	await _open("sunset")
	for i in 6:
		game.minutes += 2.0
		await _frames(2)
	await _shot("sunset")
	game.minutes = game.at("17:22")
	await _frames(3)
	_check(game.has("sunset"), "서쪽으로 지는 해")
	_check(not main.fx.busy(), "관측 화면이 열려 있는 동안에는 깨달음 카드가 뜨지 않음")
	main._overlay.close()
	await _wait(1.0)
	_check(main.fx.busy(), "화면을 나오면 '무엇을 보았지?' 카드")
	await _shot("seen_card")
	main.fx.dismiss()
	await _wait(0.5)
	await _shot("insight_card")
	await _clear_fx()

	# 계단: 옥상 → 1층
	w.player_x = w.STAIRS_X
	await _frames(2)
	main._on_interact("stairs")
	await _frames(3)
	await _shot("stairs_menu")
	_key(KEY_2)
	await _wait(0.8)
	_check(w.floor_i == 0, "계단으로 1층 이동")

	# 1) 진자 첫 기록 (17:40)
	game.minutes = game.at("17:40")
	await _open("pendulum")
	main._overlay.record()
	main._overlay.close()

	# 2) 공전 모형: 12월 → 6월 → 1월 → 7월, 자전축 세우기
	await _open("orrery")
	var orr: Node = main._overlay
	orr.set_month(6)
	await _frames(2)
	await _shot("orrery_june")
	orr.set_month(1)
	orr.set_month(7)
	orr.set_tilt(0.0)
	await _frames(2)
	await _shot("orrery_flat")
	_check(game.has("tilt_seasons") and game.has("perihelion"), "공전 모형 사실 2개")
	orr.close()

	# 3) 옥상 망원경: 카시오페이아로 북극성, 사진 1 (18:45)
	game.minutes = game.at("18:45")
	w.go_floor(2)
	await _open("telescope")
	var sky: Node = main._overlay
	_check(game.has("dipper_low"), "숨은 북두칠성")
	sky.press(_mid(sky.pos["caph"], sky.pos["schedar"]))
	sky.press(_mid(sky.pos["segin"], sky.pos["ruchbah"]))
	sky.press(sky.pos["navi"])
	await _wait(2.3)
	sky.press(sky.pos["polaris"])
	_check(game.has("polaris_cas"), "카시오페이아로 북극성")
	await _shot("polaris_cas")
	await _clear_fx()
	sky.close()

	# 4) 진자 두 번째 (18:55)
	game.minutes = game.at("18:55")
	w.go_floor(0)
	await _open("pendulum")
	main._overlay.record()
	_check(game.has("pendulum"), "진자 사실")
	main._overlay.close()

	# 5) 1시간 장노출 (19:10 → 20:10)
	game.minutes = game.at("19:10")
	w.go_floor(2)
	await _open("telescope")
	main._overlay.long_exposure()
	await _wait(3.9)
	await _shot("long_exposure")
	_check(game.has("star_trail"), "도는 하늘 (장노출)")
	_check(absf(game.minutes - game.at("20:10")) < 3.0, "장노출로 1시간이 흐름 (지금 %s)" % game.clock())
	await _clear_fx()
	main._overlay.close()

	# 5-1) 책방 교재, 강의실 칠판과 잠든 친구들
	w.go_floor(0)
	w.player_x = w.spot_x("books")
	await _frames(3)
	await _open("books")
	main._overlay.open_page(6)
	await _frames(2)
	await _shot("book")
	main._overlay.close()
	w.go_floor(1)
	w.player_x = w.spot_x("blackboard")
	await _frames(3)
	await _shot("lecture_room")
	await _open("blackboard")
	await _shot("blackboard")
	main._overlay.close()
	main._on_interact("kids")
	await _advance()

	# 7) 부두 쌍안경: 연락선 (20:35)
	game.minutes = game.at("20:35")
	w.go_floor(0)
	w.player_x = w.spot_x("binoculars")
	await _frames(2)
	await _open("binoculars")
	await _wait(1.6)
	await _shot("binoculars")
	_check(game.has("ship_horizon"), "수평선 너머의 배")
	main._overlay.close()

	# 8) 돌쇠 (항구, 21:00): 처음 만나면 이야기 → 증거
	game.minutes = game.at("21:00")
	w.npc["dolsoe"] = Vector2(1040, 0)
	await _persuade("dolsoe", ["polaris_cas"], "")
	_check(not game.freed.has("dolsoe"), "돌쇠: 북극성만으로는 설득 안 됨")
	await _persuade("dolsoe", ["polaris_cas", "ship_horizon"], "")
	_check(not game.freed.has("dolsoe"), "돌쇠: 엉뚱한 증거가 섞이면 실패")
	await _persuade("dolsoe", ["polaris_cas", "star_trail"], "harbor")
	_check(game.freed.has("dolsoe"), "돌쇠 귀환")

	# 9) 이나 (항구): 틀린 증거 한 번 → 맞는 증거
	w.npc["ina"] = Vector2(1130, 0)
	await _persuade("ina", ["pendulum"], "")
	_check(not game.freed.has("ina"), "이나: 진자로는 설득 안 됨")
	await _persuade("ina", ["ship_horizon"], "ina")
	_check(game.freed.has("ina"), "이나 귀환")

	# 10) 보리 (1층 로비): 하나만 → 둘 다
	w.npc["bori"] = Vector2(135, 0)
	await _persuade("bori", ["perihelion"], "")
	_check(not game.freed.has("bori"), "보리: 하나만으로는 설득 안 됨")
	await _persuade("bori", ["perihelion", "tilt_seasons"], "bori")
	_check(game.freed.has("bori"), "보리 귀환")

	# 10-1) 옥상 망원경: 개기월식을 부분식 때 20분 넘는 간격으로 세 번 찍기
	game.minutes = game.at("21:30")
	w.go_floor(2)
	await _open("moon")
	var dome: Node = main._overlay
	_check(dome != null, "달 망원경 화면")
	dome.take_photo()
	game.minutes = game.at("21:40")
	dome.take_photo()                                # 너무 가까움: 기록 안 됨
	game.minutes = game.at("21:55")
	dome.take_photo()
	game.minutes = game.at("22:16")
	dome.take_photo()
	await _frames(3)
	await _shot("moon_partial")
	_check(game.has("eclipse_round"), "언제나 둥근 그림자")
	game.minutes = game.at("23:00")
	await _frames(3)
	await _shot("moon_total")
	dome.close()

	# 11) 케티, 휘 (옥상, 23:00)
	w.npc["keti"] = Vector2(600, 2)
	w.npc["hwi"] = Vector2(530, 2)
	await _frames(3)
	await _shot("roof_people")
	await _persuade("keti", ["pendulum", "star_trail"], "")
	_check(not game.freed.has("keti"), "케티: 해 증거 없이는 설득 안 됨")
	await _persuade("keti", ["pendulum", "sunset"], "keti")
	_check(game.freed.has("keti"), "케티 귀환")
	await _persuade("hwi", ["eclipse_round"], "hwi")
	_check(game.freed.has("hwi"), "휘 귀환")

	# 12) 테오: 힌트 듣기 → 돔에서 노인성(01:20) → 증거
	game.minutes = game.at("01:20")
	w.npc["teo"] = Vector2(650, 2)
	w.player_x = 650.0
	await _frames(2)
	main._on_interact("teo")
	await _advance()
	_key(KEY_2)                                      # 힌트를 듣는다
	await _frames(3)
	await _advance()
	await _open("dome")
	await _frames(3)
	await _shot("dome_south")
	dome = main._overlay
	_check(dome.pos.has("canopus"), "노인성이 01:20에 보임")
	dome.press(dome.pos["canopus"])
	_check(game.has("canopus"), "노인성 사실")
	await _frames(2)
	await _shot("canopus")
	dome._set_mode("south")
	dome.look("m42")
	await _frames(2)
	await _shot("m42")
	dome.close()
	await _persuade("teo", ["canopus"], "end")
	_check(game.freed.has("teo"), "테오 귀환")
	_key(KEY_1)                                      # 계속 둘러보기
	await _frames(3)

	# 13) 책방 비밀 책장: 손님 여섯 명을 다 도우면 열림
	w.go_floor(0)
	w.player_x = w.spot_x("shelf")
	await _frames(4)
	_check(game.pieces() >= 6, "책장이 열릴 조건: 손님 여섯 명")
	main._on_interact("shelf")
	await _advance()
	await _frames(3)
	await _shot("shelf_quiz")
	await _solve_quizzes()                           # 교재 179쪽 '한 장 정리'
	await _wait(0.8)
	await _advance()
	_key(KEY_2)                                      # 나중에 내려가기
	await _frames(3)
	_check(w.shelf == 2, "책장이 열림")
	await _shot("shelf")
	w.shelf = 0

	# 14) 해돋이 → 되감기 → 두 번째 밤 (주인공은 아직 모름) → 19:00에 알아챔
	game.minutes = game.NIGHT_LEN - 0.2
	await _wait(0.6)
	await _advance()
	await _wait(1.3)
	await _shot("rewind")
	await _wait(2.5)
	await _advance()
	_check(game.loop == 2 and not game.realized, "두 번째 밤 (아직 모름)")
	_check(game.shown_loop() == 1, "화면에는 여전히 1번째 밤")
	_check(w.npc_state("keti") != "dormant", "한 번 깨운 손님은 다음 밤 처음부터 깨어 있음")
	game.minutes = game.at("19:00")
	await _wait(0.8)
	await _advance()
	await _frames(3)
	await _shot("realize_quiz")
	_key(KEY_1)                                      # 틀린 답: 꿈
	await _frames(3)
	await _advance()
	_check(main.dialogue._choices.get_child_count() == 4, "틀리면 다시 고름")
	_key(KEY_2)                                      # 정답: 같은 밤이 되풀이됨
	await _frames(3)
	await _advance()
	await _shot("realize_card")
	_key(KEY_ENTER)
	await _frames(3)
	_check(game.realized, "루프를 알아챔")
	_check(game.freed.size() == 6, "여섯 명 모두 귀환 유지")
	await _shot("loop2")

	# 15) 진엔딩: 책장 → 별지기의 방 → 우주 주소 → 아침의 선생님
	w.go_floor(0)
	w.player_x = w.spot_x("shelf")
	await _frames(3)
	main._on_interact("shelf")                       # 한 장 정리는 이미 풀었으니 바로 열림
	await _wait(1.0)
	await _advance()
	_key(KEY_1)                                      # 돌계단을 내려간다
	await _wait(1.2)
	await _shot("ending_room")
	await _advance()
	await _wait(0.5)
	await _advance()
	await _wait(0.8)
	for i in 7:                                      # 우주 주소 일곱 단계
		if i == 3:
			await _shot("ending_cosmos")
		_key(KEY_ENTER)
		await _wait(0.6)
	await _wait(1.0)
	for i in 6:                                      # 아침 대사 몇 줄 넘기기 (선생님 얼굴이 보일 때까지)
		_key(KEY_ENTER)
		await _wait(0.6)
	await _shot("ending_teacher")
	await _advance()
	await _wait(0.5)
	await _advance()
	await _shot("ending_card")
	_check(w.morning, "진엔딩 아침")
	print("AUTOPLAY OK: loop=%d facts=%d freed=%s" % [game.loop, game.facts.size(), str(game.freed.keys())])
	quit(0)


## 깨달음 카드가 떠 있으면 닫습니다.
func _clear_fx() -> void:
	for i in 30:
		await _solve_quizzes()                       # "무엇을 보았지?" 다음의 설명 퀴즈
		if not main.fx.busy():
			return
		await _wait(0.4)
		main.fx.dismiss()
		await _wait(0.6)


## 말 걸기 → (처음이면 이야기) → 증거 보여 주기 → 고른 증거 제출
func _persuade(id: String, evidence: Array, shot: String) -> void:
	await _clear_fx()
	if w.npc_state(id) == "dormant":                 # 물건에 말을 걸어 깨우기
		var home: String = w.NPC_PLAN[id]["home"]
		_check(not w.npc_visible(id), id + ": 깨우기 전에는 보이지 않음")
		main._on_interact(home)
		await _advance()
		_check(w.npc_state(id) != "dormant", id + ": 물건에서 깨어남")
	w.go_floor(int(w.npc[id].y))
	w.player_x = w.npc[id].x
	await _frames(2)
	main._on_interact(id)
	await _advance()
	_key(KEY_1)                                      # 증거를 보여 준다
	await _frames(3)
	var j: Node = main._overlay
	_check(j != null and j.has_method("_confirm"), "%s: 증거 고르기 화면" % id)
	j._selected = evidence.duplicate()
	j._confirm()
	await _frames(2)
	if shot != "":
		await _frames(1)
		await _shot("talk_" + shot)
	await _advance()


func _open(spot: String) -> void:
	main._on_interact(spot)
	await _frames(3)
	await _solve_quizzes()                           # 처음 쓰는 장치면 예측 퀴즈부터
	await _frames(3)


## 떠 있는 퀴즈를 정답(예측은 첫 보기)으로 끝까지 풉니다.
func _solve_quizzes() -> void:
	for i in 40:
		var q = main.quiz
		if q == null or not is_instance_valid(q) or not q.is_inside_tree():
			return
		q.solve()
		await _wait(1.3)


func _check(ok: bool, what: String) -> void:
	if not ok:
		push_error("AUTOPLAY FAIL: " + what)
		print("AUTOPLAY FAIL: " + what)
		quit(1)


func _mid(a: Vector2, b: Vector2) -> Vector2:
	return (a + b) / 2.0


## 대사창이 닫힐 때까지 Enter를 누릅니다. (선택지가 나오면 멈춤)
func _advance() -> void:
	await _clear_fx()
	for i in 60:
		await _frames(2)
		var d: Node = main.dialogue
		if not d.visible or not d._waiting:
			return
		_key(KEY_ENTER)
	await _frames(2)


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


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
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [shot_dir, shots, name])
