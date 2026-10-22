extends StarStage
## 임무 10: 카시오페이아자리로 북극성 찾기
## 1) W자의 양쪽 바깥 두 변을 누른다 → 두 변을 늘이면 한 점에서 만난다
## 2) W의 가운데 별을 누른다 → 만난 점과 가운데 별 사이 거리의 5배로 선이 늘어난다
## 3) 선 끝 근처의 북극성을 누른다

const GUIDE_TIME := 2.4
const SIDES := {
	"side_outer_a": ["caph", "schedar"],
	"side_inner_a": ["schedar", "navi"],
	"side_inner_b": ["navi", "ruchbah"],
	"side_outer_b": ["segin", "ruchbah"],
}

var step := 0
var picked_sides: Array = []
var meet := Vector2.ZERO      # 바깥 두 변을 늘였을 때 만나는 점
var guide_t := -1.0


func _build() -> void:
	layout(Vector2(450, 190), 11.0, -76.6)
	var hit = Geometry2D.line_intersects_line(
		pos["caph"], pos["schedar"] - pos["caph"],
		pos["segin"], pos["ruchbah"] - pos["segin"])
	meet = (hit as Vector2).round()


func get_instruction() -> String:
	match step:
		0:
			return "W자의 양쪽 '바깥' 두 변을 눌러라."
		1:
			return "두 변이 만난 점이 보인다. 이제 W의 가운데 별을 눌러라."
		2:
			return "길잡이 선을 그리는 중..."
		_:
			return "선이 가리키는 곳 근처에서 북극성을 찾아 눌러라."


func targets() -> Array:
	var out := []
	match step:
		0:
			for id in SIDES:
				var a: Vector2 = pos[SIDES[id][0]]
				var b: Vector2 = pos[SIDES[id][1]]
				out.append({"id": id, "pos": ((a + b) / 2.0).round(), "a": a, "b": b})
		1:
			for id in CASSIOPEIA:
				out.append({"id": id, "pos": pos[id]})
		3:
			for id in LITTLE_DIPPER:
				out.append({"id": id, "pos": pos[id]})
	return out


func _on_target(id: String) -> void:
	match step:
		0:
			if id.begins_with("side_outer"):
				if id not in picked_sides:
					picked_sides.append(id)
					hint_ids.erase(id)
					say("변 연장 완료: %d / 2" % picked_sides.size(), Pal.ACCENT)
				if picked_sides.size() == 2:
					step = 1
					cursor_id = ""
					hint_ids.clear()
					if hint_shown:
						hint_ids = ["navi"]
			else:
				wrong("그것은 안쪽 변이다. W의 양쪽 '바깥' 변을 찾아라.")
		1:
			if id == "navi":
				hint_ids.clear()
				_start_guide()
			else:
				wrong("가운데 별이 아니다. W의 한가운데 꼭짓점을 찾아라.")
		3:
			if id == "polaris":
				hint_ids.clear()
				succeed(pos["polaris"])
			else:
				wrong("그 별은 북극성이 아니다. 길잡이 선을 따라가 보라.")


func _start_guide() -> void:
	step = 2
	busy = true
	cursor_id = ""
	guide_t = 0.0
	say("만난 점과 가운데 별 사이 거리를 5배로 늘린다.", Pal.ACCENT)
	await get_tree().create_timer(GUIDE_TIME, false).timeout
	busy = false
	step = 3
	if hint_shown:
		hint_ids = ["polaris"]


func _process(delta: float) -> void:
	if guide_t >= 0.0:
		guide_t += delta
	super(delta)


func _on_hint() -> void:
	match step:
		0:
			hint_ids = ["side_outer_a", "side_outer_b"].filter(func(i): return i not in picked_sides)
			say("힌트: W자 양 끝에 있는 두 변이다.", Pal.ACCENT)
		1:
			hint_ids = ["navi"]
			say("힌트: W의 한가운데 꼭짓점 별이다.", Pal.ACCENT)
		_:
			hint_ids = ["polaris"]
			say("힌트: 깜빡이는 별을 확인하라.", Pal.ACCENT)


func _on_auto_solve() -> void:
	picked_sides = ["side_outer_a", "side_outer_b"]
	hint_ids = ["polaris"]
	if step < 2:
		step = 2
		guide_t = 0.0
	busy = true


func _draw_stage() -> void:
	draw_lines(CASSIOPEIA_LINES, Pal.LINE)
	draw_stars(LITTLE_DIPPER)
	draw_stars(CASSIOPEIA)
	draw_name("카시오페이아자리", pos["caph"] + Vector2(12, -2))

	for side in picked_sides:
		var ends: Array = SIDES[side]
		draw_line(pos[ends[0]], pos[ends[1]], Pal.GOLD, 1.0)
		Pal.dotted_line(self, pos[ends[1]], meet, Pal.ACCENT, 2)
	if picked_sides.size() == 2:
		draw_rect(Rect2(meet - Vector2(2, 0), Vector2(5, 1)), Pal.GOLD)
		draw_rect(Rect2(meet - Vector2(0, 2), Vector2(1, 5)), Pal.GOLD)
	if guide_t >= 0.0:
		draw_guide(meet, pos["navi"], 5, guide_t / GUIDE_TIME)
	if done:
		draw_star("polaris", Pal.GOLD)
		draw_name("북극성", pos["polaris"] + Vector2(-16, 26), Pal.GOLD)
