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


func _hint() -> String:
	for h in Story.HINTS:
		var id: String = h[0]
		if id == "polaris":
			if not Game.freed.has("dolsoe") and not (Game.has("polaris_cas") or Game.has("polaris_dip")):
				return h[1]
		elif not Game.has(id):
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
		"telescope": _open(SkyScript.new())
		"pendulum": _open(PendulumScript.new())
		"note": await _note()
		"nut": await _artifact("keti")
		"starmap": await _artifact("dolsoe")
		"keti": await _talk_keti()
		"dolsoe": await _talk_dolsoe()
	_busy = false


func _bench() -> void:
	var pick: int = await dialogue.choose(["1시간 기다리기", "30분 기다리기", "그만두기"])
	if pick == 2:
		return
	var mins := 60.0 if pick == 0 else 30.0
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.85, 0.4)
	await tw.finished
	Game.minutes = minf(Game.minutes + mins, Game.NIGHT_LEN)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.4)
	await tw2.finished
	fade.queue_free()


func _note() -> void:
	var lines := [["쪽지", Story.FACTS["note"]["text"]]]
	var hint := _hint()
	if Game.loop > 1 and hint != "":
		lines.append(["쪽지 뒷면", hint])
	await dialogue.say(lines)
	Game.add_fact("note")


func _artifact(who: String) -> void:
	var thing := "누트 여신 그림" if who == "keti" else "천상열차분야지도"
	var state: String = world.keti_state() if who == "keti" else world.dolsoe_state()
	var text := ""
	if state == "freed":
		text = "%s 속 조각 하나가 금빛으로 빛난다. 누군가 무사히 돌아간 것 같다." % thing
	elif state == "dormant":
		text = ("%s 앞에 서니, 그림 속 인물이 잠든 듯 눈을 감고 있다." % thing) if who == "keti" else ("%s의 돌판 한쪽에 작은 사람 모양이 새겨져 있다. 잠든 것 같다." % thing)
	else:
		text = "%s에서 사람 모습이 사라졌다! 어디로 간 걸까?" % thing
	await dialogue.say([["", text]])


func _talk_keti() -> void:
	if not Game.night.get("keti_met", false):
		Game.night["keti_met"] = true
		await dialogue.say(Story.KETI_WAKE)
		Game.add_fact("keti_story")
	else:
		await dialogue.say(Story.KETI_YARD if world.keti_state() == "yard" else Story.KETI_AGAIN)
	var pick: int = await dialogue.choose(["증거를 보여 준다", "그냥 둔다"])
	if pick != 0:
		return
	var ids: Array = await pick_evidence()
	if ids.is_empty():
		return
	var pend := "pendulum" in ids
	var trail := "star_trail" in ids
	if pend and trail:
		await dialogue.say(Story.KETI_WIN)
		Game.free_person("keti")
		await _check_prototype_end()
	elif trail:
		await dialogue.say(Story.KETI_ONLY_TRAIL)
	elif pend:
		await dialogue.say(Story.KETI_ONLY_PEND)
	else:
		await dialogue.say(Story.KETI_WRONG)


func _talk_dolsoe() -> void:
	var state: String = world.dolsoe_state()
	if not Game.night.get("dolsoe_met", false):
		Game.night["dolsoe_met"] = true
		await dialogue.say(Story.DOLSOE_WAKE)
		Game.add_fact("dolsoe_story")
		if state == "hall":
			return
	if state == "late":
		await dialogue.say(Story.DOLSOE_LATE)
		return
	if state == "hall":
		await dialogue.say([["돌쇠", "난 항구로 가서 배를 손보겠소. 북쪽이 어딘지 알게 되면 알려 주시오."]])
		return
	await dialogue.say(Story.DOLSOE_HARBOR)
	var pick: int = await dialogue.choose(["증거를 보여 준다", "그냥 둔다"])
	if pick != 0:
		return
	var ids: Array = await pick_evidence()
	if ids.is_empty():
		return
	if "polaris_cas" in ids or "polaris_dip" in ids:
		await dialogue.say(Story.DOLSOE_WIN if "polaris_cas" in ids else Story.DOLSOE_WIN_DIPPER)
		Game.night["sailing"] = true
		Game.free_person("dolsoe")
		await _check_prototype_end()
	else:
		await dialogue.say(Story.DOLSOE_WRONG)


func _check_prototype_end() -> void:
	if Game.freed.has("keti") and Game.freed.has("dolsoe"):
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
