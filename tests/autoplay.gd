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
	await _advance()
	w = main.world
	_check(game.has("note"), "쪽지 사실")
	await _shot("roof_start")

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
	sky.take_photo()
	sky.close()

	# 4) 진자 두 번째 (18:55)
	game.minutes = game.at("18:55")
	w.go_floor(0)
	await _open("pendulum")
	main._overlay.record()
	_check(game.has("pendulum"), "진자 사실")
	main._overlay.close()

	# 5) 사진 두 번째 (20:00)
	game.minutes = game.at("20:00")
	w.go_floor(2)
	await _open("telescope")
	main._overlay.take_photo()
	_check(game.has("star_trail"), "도는 하늘")
	main._overlay.close()

	# 6) 돔: 관측 기록 보관함 (월식 사진 3장)
	await _open("dome")
	var dome: Node = main._overlay
	dome._set_mode("archive")
	for i in 3:
		dome.view_photo(i)
	await _frames(2)
	await _shot("dome_archive")
	_check(game.has("eclipse_round"), "언제나 둥근 그림자")
	dome.close()

	# 7) 부두 쌍안경: 연락선 (20:35)
	game.minutes = game.at("20:35")
	w.go_floor(0)
	w.player_x = 40.0
	await _frames(2)
	await _open("binoculars")
	await _wait(1.6)
	await _shot("binoculars")
	_check(game.has("ship_horizon"), "수평선 너머의 배")
	main._overlay.close()

	# 8) 돌쇠 (항구, 21:00): 처음 만나면 이야기 → 증거
	game.minutes = game.at("21:00")
	w.npc["dolsoe"] = Vector2(260, 0)
	await _persuade("dolsoe", ["polaris_cas"], "harbor")
	_check(game.freed.has("dolsoe"), "돌쇠 귀환")

	# 9) 이나 (항구): 틀린 증거 한 번 → 맞는 증거
	w.npc["ina"] = Vector2(110, 0)
	await _persuade("ina", ["eclipse_round"], "")
	_check(not game.freed.has("ina"), "이나: 월식만으로는 설득 안 됨")
	await _persuade("ina", ["ship_horizon"], "ina")
	_check(game.freed.has("ina"), "이나 귀환")

	# 10) 보리 (1층 로비): 하나만 → 둘 다
	w.npc["bori"] = Vector2(1125, 0)
	await _persuade("bori", ["perihelion"], "")
	_check(not game.freed.has("bori"), "보리: 하나만으로는 설득 안 됨")
	await _persuade("bori", ["perihelion", "tilt_seasons"], "bori")
	_check(game.freed.has("bori"), "보리 귀환")

	# 11) 케티, 휘 (옥상, 21:30)
	game.minutes = game.at("21:30")
	w.go_floor(2)
	w.npc["keti"] = Vector2(1240, 2)
	w.npc["hwi"] = Vector2(1370, 2)
	await _frames(3)
	await _shot("roof_people")
	await _persuade("keti", ["pendulum", "star_trail"], "keti")
	_check(game.freed.has("keti"), "케티 귀환")
	await _persuade("hwi", ["eclipse_round"], "hwi")
	_check(game.freed.has("hwi"), "휘 귀환")

	# 12) 테오: 힌트 듣기 → 돔에서 노인성(01:00) → 증거
	game.minutes = game.at("00:50")
	w.npc["teo"] = Vector2(1300, 2)
	w.player_x = 1300.0
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
	_check(dome.pos.has("canopus"), "노인성이 00:50에 보임")
	dome.press(dome.pos["canopus"])
	_check(game.has("canopus"), "노인성 사실")
	await _frames(2)
	await _shot("canopus")
	dome.close()
	await _persuade("teo", ["canopus"], "end")
	_check(game.freed.has("teo"), "테오 귀환")
	_key(KEY_1)                                      # 계속 둘러보기
	await _frames(3)

	# 13) 지하 문: 조각 6개
	w.go_floor(0)
	w.player_x = 1490.0
	await _frames(4)
	await _shot("b1door")

	# 14) 해돋이 → 두 번째 밤
	game.minutes = game.NIGHT_LEN - 0.2
	await _wait(0.6)
	await _advance()
	_key(KEY_ENTER)
	await _frames(3)
	_check(game.loop == 2, "두 번째 밤")
	_check(game.freed.size() == 6, "여섯 명 모두 귀환 유지")
	await _shot("loop2")
	print("AUTOPLAY OK: loop=%d facts=%d freed=%s" % [game.loop, game.facts.size(), str(game.freed.keys())])
	quit(0)


## 말 걸기 → (처음이면 이야기) → 증거 보여 주기 → 고른 증거 제출
func _persuade(id: String, evidence: Array, shot: String) -> void:
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


func _check(ok: bool, what: String) -> void:
	if not ok:
		push_error("AUTOPLAY FAIL: " + what)
		print("AUTOPLAY FAIL: " + what)
		quit(1)


func _mid(a: Vector2, b: Vector2) -> Vector2:
	return (a + b) / 2.0


## 대사창이 닫힐 때까지 Enter를 누릅니다. (선택지가 나오면 멈춤)
func _advance() -> void:
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
