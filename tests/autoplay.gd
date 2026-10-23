extends SceneTree
## 자동 점검: 시제품을 처음부터 끝까지 풀어 봅니다. (게임에는 포함되지 않습니다)
##   godot --path . --script res://tests/autoplay.gd -- [사진 저장 폴더]
## 끝까지 가면 "AUTOPLAY OK"를 출력합니다.

var shot_dir := ""
var main: Node
var game: Node
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
	_key(KEY_ENTER)                                  # 시작하기
	await _frames(3)
	await _shot("intro")
	await _advance()                                 # 도입 이야기
	_check(game.has("note"), "쪽지 사실")
	await _shot("world_start")

	# 1) 진자 기록 두 번 (17:40, 18:50)
	main.world.player_x = 1880.0
	await _frames(2)
	await _shot("lobby")
	game.minutes = game.at("17:40")
	main._on_interact("pendulum")
	await _frames(2)
	main._overlay.record()
	await _shot("pendulum_1")
	main._overlay.close()
	await _frames(2)

	# 2) 망원경: 초저녁 북두칠성은 숨어 있음 → 카시오페이아로 북극성, 사진 1
	game.minutes = game.at("18:45")
	main.world.player_x = 1340.0
	main._on_interact("telescope")
	await _frames(3)
	var sky: Node = main._overlay
	_check(game.has("dipper_low"), "숨은 북두칠성 사실")
	await _shot("sky_open")
	sky.press(_mid(sky.pos["caph"], sky.pos["schedar"]))
	sky.press(_mid(sky.pos["segin"], sky.pos["ruchbah"]))
	await _frames(2)
	await _shot("sky_meet")
	sky.press(sky.pos["navi"])
	await _wait(2.3)
	await _shot("sky_guide")
	sky.press(sky.pos["polaris"])
	_check(game.has("polaris_cas"), "카시오페이아로 북극성")
	sky.take_photo()
	await _frames(3)
	await _shot("sky_polaris")
	sky.close()
	await _frames(2)

	# 3) 진자 두 번째 기록 → 사실
	game.minutes = game.at("18:55")
	main._on_interact("pendulum")
	await _frames(2)
	main._overlay.record()
	_check(game.has("pendulum"), "진자 사실")
	await _shot("pendulum_2")
	main._overlay.close()

	# 4) 케티 만나기 (전시실, 19:30)
	game.minutes = game.at("19:30")
	main.world.player_x = 2230.0
	await _frames(3)
	await _shot("keti_hall")
	main._on_interact("keti")
	await _advance()
	_key(KEY_2)                                      # 일단 그냥 둔다
	await _frames(3)
	_check(game.has("keti_story"), "케티 이야기")

	# 5) 사진 두 번째 (20:00) → 도는 하늘
	game.minutes = game.at("20:00")
	main._on_interact("telescope")
	await _frames(3)
	main._overlay.take_photo()
	await _wait(1.0)
	_check(game.has("star_trail"), "도는 하늘 사실")
	await _shot("sky_compare")
	main._overlay.close()
	await _frames(2)

	# 6) 돌쇠: 항구에서 증거 (21:00)
	game.minutes = game.at("21:00")
	main.world.dolsoe_x = 330.0
	main.world.player_x = 330.0
	await _frames(3)
	await _shot("harbor")
	main._on_interact("dolsoe")
	await _advance()
	_key(KEY_1)                                      # 증거를 보여 준다
	await _frames(3)
	await _shot("journal_pick")
	var j: Node = main._overlay
	j._selected = ["polaris_cas"]
	j._confirm()
	await _frames(2)
	await _advance()
	_check(game.freed.has("dolsoe"), "돌쇠 귀환")
	await _wait(1.5)
	await _shot("boat")

	# 7) 케티에게 증거 두 개 (21:30, 마당)
	game.minutes = game.at("21:30")
	main.world.keti_x = 1270.0
	main.world.player_x = 1270.0
	await _frames(3)
	await _shot("keti_yard")
	main._on_interact("keti")
	await _advance()
	_key(KEY_1)
	await _frames(3)
	j = main._overlay
	j._selected = ["pendulum"]
	j._confirm()
	await _frames(2)
	await _advance()                                 # 진자만으로는 반박
	_check(not game.freed.has("keti"), "진자만으로는 설득 안 됨")
	main._on_interact("keti")
	await _advance()
	_key(KEY_1)
	await _frames(3)
	j = main._overlay
	j._selected = ["pendulum", "star_trail"]
	j._confirm()
	await _frames(2)
	await _advance()                                 # 설득 → 시제품 끝 안내
	_check(game.freed.has("keti"), "케티 귀환")
	await _shot("prototype_end")
	_key(KEY_1)                                      # 계속 둘러보기
	await _frames(3)

	# 8) 해돋이 → 두 번째 밤 (일지는 남음)
	game.minutes = game.NIGHT_LEN - 0.2
	await _wait(0.6)
	await _advance()
	await _shot("loop2_card")
	_key(KEY_ENTER)
	await _frames(3)
	_check(game.loop == 2, "두 번째 밤")
	_check(game.facts.size() == 7, "일지 7개 유지 (북두칠성 방법은 안 씀)")
	await _shot("loop2_world")
	print("AUTOPLAY OK: loop=%d facts=%d freed=%s" % [game.loop, game.facts.size(), str(game.freed.keys())])
	quit(0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		push_error("AUTOPLAY FAIL: " + what)
		print("AUTOPLAY FAIL: " + what)
		quit(1)


func _mid(a: Vector2, b: Vector2) -> Vector2:
	return (a + b) / 2.0


## 대사창이 닫힐 때까지 Enter를 누릅니다. (선택지가 나오면 멈춤)
func _advance() -> void:
	for i in 40:
		await _frames(2)
		var d: Node = main.dialogue
		if not d.visible:
			return
		if not d._waiting:
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
