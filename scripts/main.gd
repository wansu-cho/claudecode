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
const SunsetScript := preload("res://scripts/views/sunset_view.gd")
const FactFxScript := preload("res://scripts/ui/fact_fx.gd")
const BookScript := preload("res://scripts/views/book_view.gd")
const BoardScript := preload("res://scripts/views/blackboard_view.gd")
## 손님 표정 칸 순서 (시트의 face 줄): 기본, 걱정(테오는 생각), 고집(테오는 아쉬움), 놀람, 깨달음
const FACE_WORRY := 1
const FACE_STUBBORN := 2
const FACE_SURPRISED := 3
const FACE_WIN := 4
const TRUST_MAX := 3          # 사람마다 하룻밤에 틀려도 되는 횟수 (믿음 하트)

var world: Control
var hud: Control
var pad: Control
var dialogue: Control
var fx: Control
var overlay_layer: Control
var _overlay: Control = null
var _busy := false          # 대화나 이벤트가 진행 중
var _ending := false
var _free_t := 0.0          # 아무 화면도 열려 있지 않은 채로 지난 시간 (초)


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
	fx = FactFxScript.new()
	add_child(fx)
	fx.landed.connect(func(): hud.flash())
	_title()


func _title() -> void:
	Game.running = false
	var has_save := Game.load_save()
	var buttons := ["이어 하기", "처음부터"] if has_save else ["시작하기"]
	var card := CardScript.new(Story.TITLE, ["어린이천문대 겨울 캠프, 끝나지 않는 밤", "", "시제품 (그림은 임시)"], buttons)
	add_child(card)
	var pick: int = await card.done
	if not has_save or pick == 1:
		Game.new_game()
	await _begin_night(true)


func _begin_night(first_of_session: bool) -> void:
	var first := Game.loop == 1 and Game.facts.is_empty()
	if first:
		await _prologue()
	Game.start_night()
	world.reset_night()
	if first:
		Game.freeze()
		await dialogue.say(Story.INTRO)
		Game.add_fact("note")
		Game.unfreeze()
	elif not Game.realized:
		# 두 번째 밤: 첫 밤과 똑같이 시작합니다. 주인공은 아직 모릅니다.
		Game.freeze()
		await dialogue.say(Story.INTRO + Story.DEJA_NIGHT2)
		Game.unfreeze()
	else:
		var lines := ["12월 13일 17:00. 다시, 해 질 녘이다.", "관측 일지는 그대로 남아 있다."]
		var hint := _hint()
		if hint != "":
			lines.append("")
			lines.append("쪽지 뒷면에 글씨가 생겼다: \"" + hint + "\"")
		var card := CardScript.new("%d번째 밤" % Game.shown_loop(), lines)
		add_child(card)
		Game.freeze()
		await card.done
		Game.unfreeze()
	_ending = false


## 프롤로그: 15:30 항구에서 시작해 마당의 선생님을 만나면 17:00 옥상으로 넘어갑니다. (시간은 멈춰 있음)
func _prologue() -> void:
	Game.start_night()
	Game.minutes = Story.PROLOGUE_TIME
	Game.freeze()
	world.reset_night()
	world.start_prologue()
	var card := CardScript.new("프롤로그", Story.PROLOGUE_CARD)
	add_child(card)
	await card.done
	await dialogue.say(Story.PROLOGUE_START)
	await world.prologue_done
	await _fade(func():
		world.prologue = false
		Game.start_night()
		world.reset_night())


## 아직 풀지 못한 것 중 첫 번째 힌트
func _hint() -> String:
	for h in Story.HINTS:
		if Game.freed.has(h[1]):
			continue
		for id in h[0]:
			if not Game.has(id):
				return h[2]
	return ""


func _process(delta: float) -> void:
	var can_move: bool = _overlay == null and not dialogue.visible and not _busy and not fx.busy()
	# 관측 화면을 나온 뒤(대화도 없을 때)에야 깨달음 카드를 띄웁니다.
	_free_t = _free_t + delta if can_move else 0.0
	if can_move and Game.running and not Game.realized and Game.loop >= 2:
		if Game.night.get("realize_now", false) or Game.minutes >= Game.at("19:00"):
			_realize()
	if _free_t > 0.6 and fx.has_pending() and Game.running:
		fx.show_next()
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
		var j := _open(JournalScript.new(false))
		if not Game.realized:
			j.tree_exited.connect(func(): Game.night["realize_now"] = true)


func pick_evidence() -> Array:
	var j: Control = _open(JournalScript.new(true))
	var ids: Array = await j.picked
	return ids


# ---- 상호작용 ----

func _on_interact(id: String) -> void:
	if _busy:
		return
	_busy = true
	if world.prologue:
		if id == "teacher":
			# 손전등을 건네는 줄부터 플레이어 손에 손전등이 보입니다
			var give := Story.PROLOGUE_TEACHER.find(Story.PROLOGUE_GIVE)
			await dialogue.say(Story.PROLOGUE_TEACHER.slice(0, give))
			world.has_lantern = true
			await dialogue.say(Story.PROLOGUE_TEACHER.slice(give))
			world.prologue_done.emit()
		else:
			await dialogue.say(Story.PROLOGUE_BLOCK)
		_busy = false
		return
	match id:
		"bench": await _bench()
		"stairs": await _stairs()
		"b1door": await _b1door()
		"comic", "mapbook", "sundial", "drawing", "photo", "globe": await _artifact(id)
		"telescope": _open(SkyScript.new())
		"sunset": _open(SunsetScript.new())
		"books": _open(BookScript.new())
		"blackboard": _open(BoardScript.new())
		"kids": await _kids()
		"dome": _open(DomeScript.new())
		"binoculars": _open(ShipScript.new())
		"orrery": _open(OrreryScript.new())
		"pendulum": _open(PendulumScript.new())
		"note": await _note()
		_:
			if Story.NPC.has(id):
				Game.freeze()                    # 사람과 이야기하는 동안에는 시간이 멈춤
				await _talk(id)
				Game.unfreeze()
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


## 강의실에서 잠든 친구들 (말 걸 때마다 다른 모습)
func _kids() -> void:
	var i: int = Game.night.get("kids_i", 0)
	Game.night["kids_i"] = i + 1
	await dialogue.say([["", Story.KIDS[i % Story.KIDS.size()]]])


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


## 손님이 깨어나는 자료를 조사했을 때: 잠들어 있음 / 사람이 빠져나감 / 아침으로 돌아감
func _artifact(spot: String) -> void:
	var who := ""
	for id in world.NPC_PLAN:
		if world.NPC_PLAN[id]["home"] == spot:
			who = id
	var state: String = world.npc_state(who) if who != "" else "dormant"
	var text: String = Story.SLEEPING[spot]
	if state == "freed":
		text = "자료 속 조각 하나가 금빛으로 빛난다. %s는 무사히 아침으로 돌아간 것 같다." % Story.NPC[who]["name"]
	elif state != "dormant":
		text = "자료 속 사람 모습이 사라졌다! 어디로 간 걸까?"
	await dialogue.say([["", text]])


## 등장인물과 이야기하고, 증거를 보여 줍니다. (대사와 필요한 증거는 story.gd의 NPC 표)
func _talk(id: String) -> void:
	var info: Dictionary = Story.NPC[id]
	var state: String = world.npc_state(id)
	var met_key := id + "_met"
	if not Game.night.get(met_key, false):
		Game.night[met_key] = true
		await dialogue.say(info["wake"])
		if Game.met.has(id):
			dialogue.face = FACE_SURPRISED
			await dialogue.say(info["deja"])
			Game.night["realize_now"] = true
		Game.met[id] = true
		Game.add_fact(info["story"])
	elif state == "late":
		await dialogue.say(info["late"])
		return
	elif state == "hall":
		await dialogue.say(info["hall"])
	else:
		await dialogue.say(info["again"])
	if state == "late":
		await dialogue.say(info["late"])
		return
	var trust := _trust(id)
	if trust <= 0:
		await dialogue.say(info["tired"])
		return
	var options := ["증거를 보여 준다  %s" % _hearts(trust), "그냥 둔다"]
	if info.get("hints", false):
		options.insert(1, "힌트를 듣는다")
	var pick: int = await dialogue.choose(options)
	if options[pick] == "힌트를 듣는다":
		var hint := _hint()
		dialogue.face = FACE_WORRY                   # 테오: 턱을 괴고 생각하는 얼굴
		await dialogue.say([[info["name"], hint if hint != "" else "이제 내가 알려 줄 건 없어. 정말 대단해!"]])
		return
	if pick != 0:
		return
	var ids: Array = await pick_evidence()
	if ids.is_empty():
		return
	# 필요한 증거를 정확히 보여 줘야 합니다. 엉뚱한 증거가 섞이면 헷갈려서 실패합니다.
	var need: Array = info["need"]
	var extra := ids.filter(func(f): return f not in need)
	var missing := need.filter(func(f): return f not in ids)
	if extra.is_empty() and missing.is_empty():
		dialogue.face = FACE_WIN
		await dialogue.say(info["win"])
		if id == "dolsoe":
			Game.night["sailing"] = true
		Game.free_person(id)
		await _check_prototype_end()
		return
	if not extra.is_empty():
		var react: Dictionary = info.get("react", {})
		dialogue.face = FACE_STUBBORN
		if react.has(extra[0]):
			await dialogue.say(react[extra[0]])
		elif extra.size() < ids.size():
			await dialogue.say(info["mixed"])
		else:
			await dialogue.say(info["wrong"])
	else:
		dialogue.face = FACE_WORRY
		await dialogue.say(info["partial"][ids[0]])
	# 틀리면 믿음 하트가 하나 줄어듭니다. 다 잃으면 그날 밤에는 더 듣지 않습니다.
	trust -= 1
	Game.night["trust_" + id] = trust
	if trust > 0:
		await dialogue.say([["", "%s의 믿음 %s" % [info["name"], _hearts(trust)]]])
	else:
		await dialogue.say(info["tired"])
		await dialogue.say([["", "%s의 믿음을 모두 잃었다. 오늘 밤에는 더 이상 증거를 들어 주지 않는다." % info["name"]]])


func _trust(id: String) -> int:
	return int(Game.night.get("trust_" + id, TRUST_MAX))


func _hearts(n: int) -> String:
	return "♥".repeat(n) + "♡".repeat(TRUST_MAX - n)


## 해돋이 → 17:00: 하늘과 시계가 거꾸로 빠르게 감깁니다.
func _rewind() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.85, 0.9, 1.0, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var mark := Pal.label("◀◀", Pal.BIG, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	mark.position = Vector2(0, 150)
	mark.size = Vector2(Pal.SCREEN.x, 30)
	add_child(mark)
	var tw := create_tween()
	tw.tween_method(func(v: float): Game.minutes = v, Game.NIGHT_LEN, 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(veil, "color:a", 0.25, 2.2)
	tw.tween_property(veil, "color:a", 1.0, 0.25)
	await tw.finished
	mark.queue_free()
	var tw2 := create_tween()
	tw2.tween_property(veil, "color:a", 0.0, 0.6)
	tw2.tween_callback(veil.queue_free)


func _check_prototype_end() -> void:
	if Game.freed.size() >= Story.NPC.size():
		await dialogue.say(Story.PROTOTYPE_END)
		var pick: int = await dialogue.choose(["계속 둘러보기", "처음부터 다시"])
		if pick == 1:
			Game.new_game()
			_close_overlay()
			await _begin_night(false)


## 두 번째 밤에 주인공이 루프를 알아챕니다.
func _realize() -> void:
	_busy = true
	Game.realized = true
	Game.save()
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.8, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	await tw.finished
	flash.queue_free()
	await dialogue.say(Story.REALIZE)
	var lines: Array = Story.REALIZE_CARD.duplicate()
	var hint := _hint()
	if hint != "":
		lines.append("")
		lines.append("쪽지 뒷면에 글씨가 생겼다: \"" + hint + "\"")
	var card := CardScript.new("%d번째 밤" % Game.loop, lines)
	add_child(card)
	Game.freeze()
	await card.done
	Game.unfreeze()
	_busy = false


func _end_night() -> void:
	_busy = true
	_close_overlay()
	Game.running = false
	await dialogue.say(Story.SUNRISE if Game.realized else Story.SUNRISE_FIRST)
	await _rewind()
	Game.next_loop()
	_busy = false
	await _begin_night(false)
