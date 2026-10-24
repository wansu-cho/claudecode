extends Control
## 게임 전체 흐름입니다.
##   제목 → (첫 밤이면) 도입 이야기 → 섬 탐험 → 07:30 해돋이 → 다음 밤 (관측 일지는 남음)
##
## 조작
##   이동: ← → 또는 A D (터치: 화면 왼쪽을 누른 채 끌기)
##   점프: Space, W, ↑ (터치: 화면 오른쪽 탭)
##   확인/대화: E, Enter (터치: [눌러서 …] 말풍선 탭)
##   관측 일지: J (터치: 위쪽 버튼)

const WorldScript := preload("res://scripts/world.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PadScript := preload("res://scripts/ui/touch_pad.gd")
const DialogueScript := preload("res://scripts/ui/dialogue_box.gd")
const CardScript := preload("res://scripts/ui/card.gd")
const JournalScript := preload("res://scripts/ui/journal_view.gd")
const SkyScript := preload("res://scripts/views/sky_view.gd")
const PendulumScript := preload("res://scripts/views/pendulum_view.gd")
const DomeScript := preload("res://scripts/views/dome_view.gd")
const ShipScript := preload("res://scripts/views/ship_view.gd")
const OrreryScript := preload("res://scripts/views/orrery_view.gd")

var world: Control
var hud: Control
var pad: Control
var dialogue: Control
var overlay_layer: Control
var _overlay: Control = null
var _busy := false          # 대화나 이벤트가 진행 중
var _ending := false


func _ready() -> void:
	world = WorldScript.new()
	add_child(world)
	world.interact.connect(_on_interact)
	pad = PadScript.new()
	pad.world = world
	add_child(pad)
	pad.jump.connect(func(): world.jump())
	pad.interact.connect(func(): world.try_interact())
	hud = HudScript.new()
	hud.world = world
	add_child(hud)
	hud.journal_pressed.connect(open_journal)
	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	dialogue = DialogueScript.new()
	add_child(dialogue)
	_title()


func _title() -> void:
	Game.running = false
	var has_save := Game.load_save()
	var buttons := ["이어 하기", "처음부터"] if has_save else ["시작하기"]
	var card := CardScript.new(Story.TITLE, ["어린이천문대 겨울 별 캠프, 끝나지 않는 밤", "", "시제품 (그림은 임시)"], buttons)
	add_child(card)
	var pick: int = await card.done
	if not has_save or pick == 1:
		Game.new_game()
	await _begin_night(true)


func _begin_night(first_of_session: bool) -> void:
	Game.start_night()
	world.reset_night()
	if Game.loop == 1 and Game.facts.is_empty():
		Game.freeze()
		await dialogue.say(Story.INTRO)
		Game.add_fact("note")
		Game.unfreeze()
	else:
		var lines := ["12월 20일 17:30. 다시, 해 질 녘이다.", "관측 일지는 그대로 남아 있다."]
		var hint := _hint()
		if hint != "":
			lines.append("")
			lines.append("쪽지 뒷면에 글씨가 생겼다: \"" + hint + "\"")
		var card := CardScript.new("%d번째 밤" % Game.loop, lines)
		add_child(card)
		Game.freeze()
		await card.done
		Game.unfreeze()
	_ending = false


## 아직 풀지 못한 것 중 첫 번째 힌트
func _hint() -> String:
	for h in Story.HINTS:
		var id: String = h[0]
		var todo := false
		match id:
			"polaris": todo = not Game.freed.has("dolsoe") and not (Game.has("polaris_cas") or Game.has("polaris_dip"))
			"orrery": todo = not Game.freed.has("bori") and not (Game.has("perihelion") and Game.has("tilt_seasons"))
			"ship_horizon": todo = not Game.freed.has("ina") and not Game.has(id)
			"eclipse_round": todo = not Game.freed.has("hwi") and not Game.has(id)
			"canopus": todo = not Game.freed.has("teo") and not Game.has(id)
			_: todo = not Game.has(id)
		if todo:
			return h[1]
	return ""


func _process(_delta: float) -> void:
	var can_move := _overlay == null and not dialogue.visible and not _busy
	world.active = can_move and Game.running
	pad.enabled = world.active
	hud.visible = _overlay == null
	if Game.running and Game.minutes >= Game.NIGHT_LEN and not _ending and not _busy:
		_ending = true
		_end_night()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _overlay != null or dialogue.visible or _busy:
		return
	if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		world.try_interact()
	elif event.keycode in [KEY_SPACE, KEY_W, KEY_UP]:
		get_viewport().set_input_as_handled()
		world.jump()
	elif event.keycode == KEY_J:
		get_viewport().set_input_as_handled()
		open_journal()
	elif event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---- 화면 덮개 ----

func _open(view: Control) -> Control:
	_close_overlay()
	_overlay = view
	overlay_layer.add_child(view)
	view.tree_exited.connect(func(): if _overlay == view: _overlay = null)
	return view


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func open_journal() -> void:
	if _overlay == null and not dialogue.visible:
		_open(JournalScript.new(false))


func pick_evidence() -> Array:
	var j: Control = _open(JournalScript.new(true))
	var ids: Array = await j.picked
	return ids


# ---- 상호작용 ----

func _on_interact(id: String) -> void:
	if _busy:
		return
	_busy = true
	match id:
		"bench": await _bench()
		"stairs": await _stairs()
		"b1door": await _b1door()
		"tablet", "bamboo", "vase", "calendar", "nut", "starmap": await _artifact(id)
		"telescope": _open(SkyScript.new())
		"dome": _open(DomeScript.new())
		"binoculars": _open(ShipScript.new())
		"orrery": _open(OrreryScript.new())
		"pendulum": _open(PendulumScript.new())
		"note": await _note()
		_:
			if Story.NPC.has(id):
				await _talk(id)
	_busy = false


func _bench() -> void:
	var pick: int = await dialogue.choose(["1시간 기다리기", "30분 기다리기", "그만두기"])
	if pick == 2:
		return
	var mins := 60.0 if pick == 0 else 30.0
	await _fade(func(): Game.minutes = minf(Game.minutes + mins, Game.NIGHT_LEN))


func _stairs() -> void:
	var floors := []
	var names := []
	for f in [2, 1, 0]:
		if f != world.floor_i:
			floors.append(f)
			names.append(world.FLOOR_NAME[f])
	names.append("그만두기")
	var pick: int = await dialogue.choose(names)
	if pick >= floors.size():
		return
	await _fade(func(): world.go_floor(floors[pick]))


func _b1door() -> void:
	await dialogue.say([
		["", "지하로 내려가는 무거운 문이다. 손잡이 위에 별 모양 홈 일곱 개가 둥글게 파여 있다."],
		["", "홈 %d개가 금빛으로 빛나고 있다. 문은 아직 꿈쩍도 하지 않는다." % Game.pieces()],
	])


## 화면을 잠깐 어둡게 했다가 밝히며, 그 사이에 할 일을 합니다.
func _fade(between: Callable) -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.9, 0.2)
	await tw.finished
	between.call()
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.2)
	await tw2.finished
	fade.queue_free()


func _note() -> void:
	var lines := [["쪽지", Story.FACTS["note"]["text"]]]
	var hint := _hint()
	if Game.loop > 1 and hint != "":
		lines.append(["쪽지 뒷면", hint])
	await dialogue.say(lines)
	Game.add_fact("note")


## 유물을 조사했을 때: 잠들어 있음 / 사람이 빠져나감 / 아침으로 돌아감
func _artifact(spot: String) -> void:
	var who := ""
	for id in world.NPC_PLAN:
		if world.NPC_PLAN[id]["home"] == spot:
			who = id
	var state: String = world.npc_state(who) if who != "" else "dormant"
	var text: String = Story.SLEEPING[spot]
	if state == "freed":
		text = "유물 속 조각 하나가 금빛으로 빛난다. %s는 무사히 아침으로 돌아간 것 같다." % Story.NPC[who]["name"]
	elif state != "dormant":
		text = "유물 속 사람 모습이 사라졌다! 어디로 간 걸까?"
	await dialogue.say([["", text]])


## 등장인물과 이야기하고, 증거를 보여 줍니다. (대사와 필요한 증거는 story.gd의 NPC 표)
func _talk(id: String) -> void:
	var info: Dictionary = Story.NPC[id]
	var state: String = world.npc_state(id)
	var met_key := id + "_met"
	if not Game.night.get(met_key, false):
		Game.night[met_key] = true
		await dialogue.say(info["wake"])
		Game.add_fact(info["story"])
		if state == "hall":
			return
	elif state == "late":
		await dialogue.say(info["late"])
		return
	elif state == "hall":
		await dialogue.say(info["hall"])
		return
	else:
		await dialogue.say(info["again"])
	if state == "late":
		await dialogue.say(info["late"])
		return
	var options := ["증거를 보여 준다", "그냥 둔다"]
	if info.get("hints", false):
		options.insert(1, "힌트를 듣는다")
	var pick: int = await dialogue.choose(options)
	if options[pick] == "힌트를 듣는다":
		var hint := _hint()
		await dialogue.say([[info["name"], hint if hint != "" else "이제 내가 알려 줄 건 없어. 정말 대단해!"]])
		return
	if options[pick] != "증거를 보여 준다":
		return
	var ids: Array = await pick_evidence()
	if ids.is_empty():
		return
	var ok := false
	if info.has("need_any"):
		for f in info["need_any"]:
			if f in ids:
				ok = true
	else:
		ok = true
		for f in info["need"]:
			if f not in ids:
				ok = false
	if ok:
		await dialogue.say(info["win"])
		if id == "dolsoe":
			Game.night["sailing"] = true
		Game.free_person(id)
		await _check_prototype_end()
		return
	var partial: Dictionary = info.get("partial", {})
	for f in ids:
		if partial.has(f):
			await dialogue.say(partial[f])
			return
	await dialogue.say(info["wrong"])


func _check_prototype_end() -> void:
	if Game.freed.size() >= Story.NPC.size():
		await dialogue.say(Story.PROTOTYPE_END)
		var pick: int = await dialogue.choose(["계속 둘러보기", "처음부터 다시"])
		if pick == 1:
			Game.new_game()
			_close_overlay()
			await _begin_night(false)


func _end_night() -> void:
	_busy = true
	_close_overlay()
	Game.running = false
	await dialogue.say(Story.SUNRISE)
	Game.next_loop()
	_busy = false
	await _begin_night(false)
