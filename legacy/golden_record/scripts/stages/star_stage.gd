class_name StarStage
extends StageBase
## 북쪽 하늘 별자리 단계들이 함께 쓰는 부분입니다.
## 실제 별의 위치(적경·적위)를 북극 중심으로 펼쳐서 화면에 그립니다.
##
## 조작 방법
##   - 펜/터치/마우스: 별(또는 선)을 누르기
##   - 키보드: 방향키로 고르고 Enter로 누르기

## 별 목록: 이름 -> [적경(시), 적위(도), 밝기(등급, 작을수록 밝음)]
const CATALOG := {
	"polaris": [2.530, 89.26, 2.0],
	"kochab": [14.845, 74.16, 2.1],
	"pherkad": [15.345, 71.83, 3.0],
	"yildun": [17.537, 86.59, 4.4],
	"eps_umi": [16.766, 82.04, 4.2],
	"zeta_umi": [15.734, 77.79, 4.3],
	"eta_umi": [16.292, 75.76, 5.0],
	"dubhe": [11.062, 61.75, 1.8],
	"merak": [11.030, 56.38, 2.4],
	"phecda": [11.897, 53.69, 2.4],
	"megrez": [12.257, 57.03, 3.3],
	"alioth": [12.900, 55.96, 1.8],
	"mizar": [13.398, 54.93, 2.2],
	"alkaid": [13.792, 49.31, 1.9],
	"caph": [0.153, 59.15, 2.3],
	"schedar": [0.675, 56.54, 2.2],
	"navi": [0.945, 60.72, 2.2],
	"ruchbah": [1.430, 60.24, 2.7],
	"segin": [1.907, 63.67, 3.4],
}

const LITTLE_DIPPER := ["polaris", "kochab", "pherkad", "yildun", "eps_umi", "zeta_umi", "eta_umi"]
const BIG_DIPPER := ["dubhe", "merak", "phecda", "megrez", "alioth", "mizar", "alkaid"]
const BIG_DIPPER_LINES := [["dubhe", "merak"], ["merak", "phecda"], ["phecda", "megrez"], ["megrez", "dubhe"], ["megrez", "alioth"], ["alioth", "mizar"], ["mizar", "alkaid"]]
const CASSIOPEIA := ["caph", "schedar", "navi", "ruchbah", "segin"]
const CASSIOPEIA_LINES := [["caph", "schedar"], ["schedar", "navi"], ["navi", "ruchbah"], ["ruchbah", "segin"]]

const STAR_HIT := 14.0
const LINE_HIT := 8.0

var origin := Vector2(320, 180)
var scale_px := 7.0
var rotation_deg := 0.0

var pos := {}                 # 별 이름 -> 화면 위치
var hint_ids: Array = []      # 힌트로 깜빡일 대상
var busy := false             # 그림이 움직이는 동안은 입력을 받지 않습니다
var cursor_id := ""           # 키보드로 고른 대상

var _bg_stars: Array = []


func layout(new_origin: Vector2, new_scale: float, new_rotation_deg := 0.0) -> void:
	origin = new_origin
	scale_px = new_scale
	rotation_deg = new_rotation_deg
	pos.clear()
	for id in CATALOG:
		var ra: float = CATALOG[id][0]
		var dec: float = CATALOG[id][1]
		var r := 90.0 - dec
		var t := deg_to_rad(ra * 15.0)
		var v := Vector2(-r * sin(t), -r * cos(t)).rotated(deg_to_rad(rotation_deg))
		pos[id] = (origin + v * scale_px).round()
	_make_background()


func _make_background() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_bg_stars.clear()
	while _bg_stars.size() < 150:
		var p := Vector2(rng.randi_range(4, 636), rng.randi_range(28, 316))
		var near := false
		for id in pos:
			if p.distance_to(pos[id]) < 10:
				near = true
				break
		if not near:
			_bg_stars.append([p, rng.randf_range(0.25, 0.7)])


# ---- 하위 단계가 정하는 것 ----

## 지금 누를 수 있는 대상 목록. 각 항목: {"id", "pos"} (+선이면 "a", "b")
func targets() -> Array:
	return []


func _on_target(_id: String) -> void:
	pass


# ---- 입력 ----

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		cursor_id = ""
		_press_at(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var dir := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: dir = Vector2.LEFT
		KEY_RIGHT: dir = Vector2.RIGHT
		KEY_UP: dir = Vector2.UP
		KEY_DOWN: dir = Vector2.DOWN
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				get_viewport().set_input_as_handled()
				if cursor_id != "":
					_press_id(cursor_id)
			return
		_:
			return
	get_viewport().set_input_as_handled()
	_move_cursor(dir)


func _press_at(p: Vector2) -> void:
	if busy or not accept_tap():
		return
	var best := ""
	var best_d := INF
	for t in targets():
		var d: float
		if t.has("a"):
			d = p.distance_to(Geometry2D.get_closest_point_to_segment(p, t["a"], t["b"]))
			if d > LINE_HIT:
				continue
		else:
			d = p.distance_to(t["pos"])
			if d > STAR_HIT:
				continue
		if d < best_d:
			best_d = d
			best = t["id"]
	if best == "":
		say("빈 하늘이다. 정확히 눌러라.", Pal.DIM)
		return
	_on_target(best)


func _press_id(id: String) -> void:
	if busy or not accept_tap():
		return
	for t in targets():
		if t["id"] == id:
			_on_target(id)
			return


func _move_cursor(dir: Vector2) -> void:
	var list := targets()
	if list.is_empty():
		return
	var here: Vector2 = Vector2(320, 180)
	for t in list:
		if t["id"] == cursor_id:
			here = t["pos"]
	if cursor_id == "" or not list.any(func(t): return t["id"] == cursor_id):
		cursor_id = list[0]["id"]
		return
	var best := ""
	var best_score := INF
	for t in list:
		if t["id"] == cursor_id:
			continue
		var v: Vector2 = t["pos"] - here
		var dist := v.length()
		if dist < 1.0:
			continue
		var cos_a := v.normalized().dot(dir)
		if cos_a <= 0.2:
			continue
		var score := dist * (1.0 + 2.0 * (1.0 - cos_a))
		if score < best_score:
			best_score = score
			best = t["id"]
	if best != "":
		cursor_id = best


# ---- 그리기 ----

func draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.BG)
	for s in _bg_stars:
		var c := Pal.STAR
		c.a = s[1]
		draw_rect(Rect2(s[0], Vector2.ONE), c)


func draw_lines(lines: Array, color: Color) -> void:
	for l in lines:
		Pal.dotted_line(self, pos[l[0]], pos[l[1]], color, 2)


func draw_star(id: String, color := Pal.STAR) -> void:
	var p: Vector2 = pos[id]
	var mag: float = CATALOG[id][2]
	if mag < 2.5:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), color)
		draw_rect(Rect2(p + Vector2(-3, 0), Vector2(7, 1)), Color(color, 0.6))
		draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 7)), Color(color, 0.6))
	elif mag < 3.5:
		draw_rect(Rect2(p, Vector2(2, 2)), color)
	elif mag < 4.5:
		draw_rect(Rect2(p, Vector2.ONE), color)
	else:
		draw_rect(Rect2(p, Vector2.ONE), Color(color, 0.6))


func draw_stars(ids: Array) -> void:
	for id in ids:
		draw_star(id)


func draw_name(text: String, at: Vector2, color := Pal.DIM) -> void:
	draw_string(get_theme_default_font(), at.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, color)


## 힌트 대상 깜빡이기 + 키보드 선택 표시
func draw_markers() -> void:
	var blink := int(elapsed * 3.0) % 2 == 0
	if blink:
		for id in hint_ids:
			for t in targets():
				if t["id"] == id:
					Pal.ring(self, t["pos"], 7, Pal.ACCENT)
	if cursor_id != "":
		for t in targets():
			if t["id"] == cursor_id:
				Pal.ring(self, t["pos"], 9, Pal.GOLD)
				Pal.ring(self, t["pos"], 10, Pal.GOLD)


## 두 점 사이를 몇 배로 늘린 길잡이 선을 그립니다. progress(0~1)만큼만 그립니다.
## from → through 방향으로, through에서부터 두 점 사이 거리의 times배만큼 늘립니다.
func draw_guide(from: Vector2, through: Vector2, times: int, progress: float) -> void:
	draw_line(from, through, Pal.GOLD, 1.0)
	var step := through - from
	var end := through + step * times * clampf(progress, 0.0, 1.0)
	Pal.dotted_line(self, through, end, Pal.ACCENT, 3)
	var font := get_theme_default_font()
	for k in range(1, times + 1):
		if float(k) / times > progress + 0.001:
			break
		var p := through + step * k
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Pal.ACCENT)
		draw_string(font, p + Vector2(4, -3), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.ACCENT)


func _draw() -> void:
	draw_sky()
	_draw_stage()
	draw_markers()
	draw_celebration()
	draw_instruction_bar()


func _draw_stage() -> void:
	pass
