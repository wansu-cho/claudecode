extends StarStage
## 임무 09: 북두칠성으로 북극성 찾기
## 1) 국자 끝의 두 별(메라크, 두베)을 누른다
## 2) 두 별 사이 거리의 5배로 길잡이 선이 늘어난다
## 3) 선 끝 근처의 북극성을 누른다

const GUIDE_TIME := 2.4

var step := 0
var picked: Array = []
var guide_t := -1.0


func _build() -> void:
	layout(Vector2(160, 260), 8.0, 257.1)


func get_instruction() -> String:
	match step:
		0:
			return "북두칠성 국자의 '끝' 두 별을 차례로 눌러라."
		1:
			return "길잡이 선을 그리는 중..."
		_:
			return "선이 가리키는 곳 근처에서 북극성을 찾아 눌러라."


func targets() -> Array:
	var ids: Array
	if step == 0:
		ids = BIG_DIPPER
	elif step == 2:
		ids = LITTLE_DIPPER
	else:
		return []
	var out := []
	for id in ids:
		out.append({"id": id, "pos": pos[id]})
	return out


func _on_target(id: String) -> void:
	if step == 0:
		if id in ["merak", "dubhe"]:
			if id not in picked:
				picked.append(id)
				hint_ids.erase(id)
				say("좋다. 기준 별 확보: %d / 2" % picked.size(), Pal.ACCENT)
			if picked.size() == 2:
				_start_guide()
		else:
			wrong("그 별이 아니다. 국자 '끝'의 두 별을 찾아라.")
	elif step == 2:
		if id == "polaris":
			hint_ids.clear()
			succeed(pos["polaris"])
		else:
			wrong("그 별은 북극성이 아니다. 길잡이 선을 따라가 보라.")


func _start_guide() -> void:
	step = 1
	busy = true
	cursor_id = ""
	guide_t = 0.0
	say("두 별 사이 거리를 5배로 늘린다.", Pal.ACCENT)
	await get_tree().create_timer(GUIDE_TIME, false).timeout
	busy = false
	step = 2
	if hint_shown:
		hint_ids = ["polaris"]


func _process(delta: float) -> void:
	if guide_t >= 0.0:
		guide_t += delta
	super(delta)


func _on_hint() -> void:
	if step == 0:
		hint_ids = ["merak", "dubhe"].filter(func(i): return i not in picked)
		say("힌트: 국자 입구 쪽, 손잡이 반대편 끝의 두 별이다.", Pal.ACCENT)
	else:
		hint_ids = ["polaris"]
		say("힌트: 깜빡이는 별을 확인하라.", Pal.ACCENT)


func _on_auto_solve() -> void:
	picked = ["merak", "dubhe"]
	hint_ids = ["polaris"]
	if step == 0:
		step = 1
		guide_t = 0.0
	busy = true


func _draw_stage() -> void:
	draw_lines(BIG_DIPPER_LINES, Pal.LINE)
	draw_stars(LITTLE_DIPPER)
	draw_stars(BIG_DIPPER)
	draw_name("북두칠성", pos["alkaid"] + Vector2(10, 4))

	for id in picked:
		Pal.ring(self, pos[id], 5, Pal.GOLD)
	if guide_t >= 0.0:
		draw_guide(pos["merak"], pos["dubhe"], 5, guide_t / GUIDE_TIME)
	if done:
		draw_star("polaris", Pal.GOLD)
		draw_name("북극성", pos["polaris"] + Vector2(-16, 26), Pal.GOLD)
