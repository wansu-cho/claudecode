extends Control
## 걸어 다니는 섬 풍경입니다. 바깥은 옆으로, 천문대 안은 층으로 이어집니다.
##
##   바깥 (1층 높이)   0 ~ 420 항구(돌쇠의 배) · 420 ~ 900 마당(벤치)
##   천문대 900 ~ 1540
##     3층  옥상 관측 데크: 망원경, 돔
##     2층  전시실 '옛사람들의 하늘': 누트 여신 그림, 천상열차분야지도, 아직 잠든 유물들
##     1층  로비: 푸코 진자, 선생님 책상, 지하로 가는 문(잠김)
##     지하 1층  (잠김) 우주 주소 조각 7개를 모으면 열림
## 층 이동은 왼쪽 계단에서 합니다. (main.gd에서 층을 고름)

signal interact(id: String)

const WORLD_W := 1600.0
const FLOOR_Y := {0: 300.0, 1: 190.0, 2: 80.0}    # 층별 바닥 높이 (발 위치)
const B1_Y := 388.0               # 지하 1층 바닥 (지금은 들어갈 수 없음)
const CAM_FEET := 268.0           # 화면에서 발이 놓이는 높이 (아래로 지하가 조금 보이게)
const FLOOR_NAME := {0: "1층 로비", 1: "2층 전시실", 2: "3층 옥상"}
const B_X0 := 900.0               # 천문대 왼쪽 벽
const B_X1 := 1540.0              # 천문대 오른쪽 벽
const IN_X0 := 914.0              # 안쪽에서 걸을 수 있는 범위
const IN_X1 := 1526.0
const STAIRS_X := 940.0
const HOR := 262.0                # 1층 높이에서 본 수평선
const SKY_K := 3.0
const SPEED := 145.0
const JUMP_V := 235.0             # 점프 처음 속도 (픽셀/초)
const GRAVITY := 780.0
const NPC_SPEED := 55.0
const REACH := 24.0

const SPOTS := [
	{"id": "bench", "floor": 0, "x": 640.0, "label": "벤치에 앉아 기다리기"},
	{"id": "stairs", "floor": 0, "x": STAIRS_X, "label": "계단"},
	{"id": "note", "floor": 0, "x": 1090.0, "label": "선생님 책상"},
	{"id": "pendulum", "floor": 0, "x": 1290.0, "label": "푸코 진자 살펴보기"},
	{"id": "b1door", "floor": 0, "x": 1490.0, "label": "지하로 내려가는 문"},
	{"id": "stairs", "floor": 1, "x": STAIRS_X, "label": "계단"},
	{"id": "tablet", "floor": 1, "x": 1030.0, "label": "점토판 (바빌로니아 세계 지도)"},
	{"id": "bamboo", "floor": 1, "x": 1110.0, "label": "죽간 (옛 중국의 천문 기록)"},
	{"id": "nut", "floor": 1, "x": 1200.0, "label": "누트 여신 그림 (복제품)"},
	{"id": "vase", "floor": 1, "x": 1320.0, "label": "그리스 도기"},
	{"id": "starmap", "floor": 1, "x": 1450.0, "label": "천상열차분야지도 (복각본)"},
	{"id": "stairs", "floor": 2, "x": STAIRS_X, "label": "계단"},
	{"id": "telescope", "floor": 2, "x": 1130.0, "label": "망원경으로 하늘 보기"},
]
const KETI_HOME := Vector2(1200.0, 1)        # (x, 층)
const KETI_ROOF := Vector2(1250.0, 2)
const DOLSOE_HOME := Vector2(1450.0, 1)
const DOLSOE_HARBOR := Vector2(260.0, 0)
const BOAT_X := 140.0

var player_x := 1130.0
var floor_i := 2                  # 지금 있는 층 (0 = 1층/바깥, 1 = 2층, 2 = 3층 옥상)
var facing := -1
var walk_t := 0.0
var active := true
var pad_dir := 0.0                # 가상 키패드 입력 (-1 ~ 1)
var y_off := 0.0                  # 점프 높이 (위가 −)
var vy := 0.0
var jumps := 0
var prompt_rect := Rect2()        # 화면에 보이는 [확인] 말풍선 (누르면 상호작용)
var nearest := ""
var keti := KETI_HOME
var dolsoe := DOLSOE_HOME
var boat_x := BOAT_X
var cam := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset_night() -> void:
	player_x = 1130.0
	floor_i = 2
	y_off = 0.0
	vy = 0.0
	jumps = 0
	keti = KETI_HOME
	dolsoe = DOLSOE_HOME
	boat_x = BOAT_X
	facing = -1
	_snap_camera()


## 다른 층으로 옮깁니다. (계단)
func go_floor(f: int) -> void:
	floor_i = f
	player_x = STAIRS_X + 16.0
	y_off = 0.0
	vy = 0.0
	jumps = 0
	_snap_camera()


func floor_y(f: int) -> float:
	return FLOOR_Y[f]


# ---- 등장인물의 시간표 ----

static func keti_state() -> String:
	if Game.freed.has("keti"):
		return "freed"
	if Game.minutes < Game.at("18:00"):
		return "dormant"
	if Game.minutes < Game.at("21:00"):
		return "hall"
	return "yard"


static func dolsoe_state() -> String:
	if Game.freed.has("dolsoe"):
		return "freed"
	if Game.minutes < Game.at("19:00"):
		return "dormant"
	if Game.minutes < Game.at("20:00"):
		return "hall"
	if Game.minutes < Game.at("23:00"):
		return "harbor"
	return "late"


## 사람을 목표 자리로 걷게 합니다. 층이 다르면 계단에서 나타납니다.
func _walk_npc(p: Vector2, target: Vector2, delta: float) -> Vector2:
	if p.y != target.y:
		return Vector2(STAIRS_X + 10.0, target.y)
	return Vector2(move_toward(p.x, target.x, NPC_SPEED * delta), p.y)


func _process(delta: float) -> void:
	_t += delta
	if active:
		var dir := pad_dir
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
			dir = -1.0
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			dir = 1.0
		if absf(dir) > 0.05:
			facing = 1 if dir > 0 else -1
			walk_t += delta
			var lo := 12.0 if floor_i == 0 else IN_X0
			player_x = clampf(player_x + dir * SPEED * delta, lo, IN_X1)
		else:
			walk_t = 0.0
	# 점프
	if y_off < 0.0 or vy < 0.0:
		vy += GRAVITY * delta
		y_off += vy * delta
		if y_off >= 0.0:
			y_off = 0.0
			vy = 0.0
			jumps = 0

	var ks := keti_state()
	if ks == "hall" or ks == "yard":
		keti = _walk_npc(keti, KETI_HOME if ks == "hall" else KETI_ROOF, delta)
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed":
		dolsoe = _walk_npc(dolsoe, DOLSOE_HOME if ds == "hall" else DOLSOE_HARBOR, delta)
	if Game.night.get("sailing", false):
		boat_x += 28.0 * delta

	nearest = _find_nearest()
	var target := _cam_target()
	cam.x = target.x
	cam.y = lerpf(cam.y, target.y, minf(1.0, delta * 8.0))
	queue_redraw()


func _cam_target() -> Vector2:
	return Vector2(clampf(player_x - Pal.SCREEN.x / 2.0, 0.0, WORLD_W - Pal.SCREEN.x), floor_y(floor_i) - CAM_FEET)


func _snap_camera() -> void:
	cam = _cam_target()


## 점프 (두 번 점프는 Game.double_jump를 얻으면 가능)
func jump() -> void:
	if not active:
		return
	var max_jumps := 2 if Game.double_jump else 1
	if jumps < max_jumps:
		vy = -JUMP_V
		jumps += 1
		if y_off == 0.0:
			y_off = -0.01


func targets() -> Array:
	var out := []
	for s in SPOTS:
		if s["floor"] == floor_i:
			out.append(s)
	var ks := keti_state()
	if (ks == "hall" or ks == "yard") and int(keti.y) == floor_i:
		out.append({"id": "keti", "x": keti.x, "label": "케티와 이야기하기"})
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed" and not Game.night.get("sailing", false) and int(dolsoe.y) == floor_i:
		out.append({"id": "dolsoe", "x": dolsoe.x, "label": "돌쇠와 이야기하기"})
	return out


func _find_nearest() -> String:
	var best := ""
	var best_d := REACH
	for t in targets():
		var d := absf(float(t["x"]) - player_x)
		if d < best_d:
			best_d = d
			best = t["id"]
	return best


func try_interact() -> void:
	if active and nearest != "":
		interact.emit(nearest)


func label_of(id: String) -> String:
	for t in targets():
		if t["id"] == id:
			return t["label"]
	return ""


func place_name() -> String:
	if floor_i == 0 and player_x < B_X0:
		return "항구" if player_x < 420 else "천문대 마당"
	return FLOOR_NAME[floor_i]


# ---- 그리기 ----

func _draw() -> void:
	var m := Game.minutes
	var hy := HOR - cam.y * 0.15             # 먼 하늘과 바다는 조금만 움직입니다
	SkyPainter.draw(self, m, Pal.SCREEN, hy, SKY_K, Pal.SCREEN.x / 2.0)
	_draw_sea(m, hy)
	draw_set_transform(-cam)
	_draw_harbor()
	_draw_land()
	_draw_building()
	_draw_people()
	draw_set_transform(Vector2.ZERO)
	_draw_prompt()


func _draw_sea(m: float, hy: float) -> void:
	var dark := Astro.darkness(m)
	var sea := Color8(70, 110, 160).lerp(Color8(26, 18, 46), dark)
	draw_rect(Rect2(0, hy, Pal.SCREEN.x, Pal.SCREEN.y - hy + 2), sea)
	for i in 40:
		var x := fposmod(i * 97.0 - cam.x * 0.2 + sin(_t + i) * 3.0, Pal.SCREEN.x)
		var y := hy + 3 + (i * 13) % 80
		draw_rect(Rect2(x, y, 3 + i % 4, 1), Color(0.75, 0.5, 0.8, 0.35 * dark + 0.15))
	# 먼 등대 섬
	var lx := 470.0 - cam.x * 0.05
	draw_colored_polygon(PackedVector2Array([Vector2(lx - 30, hy + 1), Vector2(lx - 12, hy - 6), Vector2(lx + 14, hy - 5), Vector2(lx + 30, hy + 1)]), Color8(14, 10, 24))
	draw_rect(Rect2(lx - 1, hy - 24, 3, 18), Color8(196, 196, 214))
	draw_rect(Rect2(lx - 1, hy - 18, 3, 3), Color8(190, 60, 70))
	var beam := 0.5 + 0.5 * sin(_t * 1.6)
	draw_rect(Rect2(lx - 2, hy - 27, 5, 3), Color(1, 0.9, 0.6, 0.6 + 0.4 * beam))
	draw_circle(Vector2(lx, hy - 26), 6, Color(1, 0.85, 0.5, 0.15 * dark * beam + 0.05))


func _draw_harbor() -> void:
	var g := FLOOR_Y[0]
	draw_rect(Rect2(0, g - 4, 420, 6), Color8(92, 66, 54))
	for x in range(0, 420, 12):
		draw_rect(Rect2(x, g - 4, 1, 6), Color8(60, 42, 38))
	for x in range(10, 420, 60):
		draw_rect(Rect2(x, g + 2, 4, 40), Color8(50, 36, 34))
	if not Game.freed.has("dolsoe") or Game.night.get("sailing", false):
		if boat_x < WORLD_W:
			var bob := sin(_t * 1.5) * 1.5
			var bx := boat_x
			var by := g + 10 + bob
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 40, by - 10), Vector2(bx + 40, by - 10), Vector2(bx + 30, by), Vector2(bx - 30, by)]), Color8(110, 74, 50))
			draw_rect(Rect2(bx - 40, by - 12, 80, 2), Color8(150, 104, 70))
			draw_rect(Rect2(bx - 2, by - 62, 3, 52), Color8(80, 56, 40))
			draw_colored_polygon(PackedVector2Array([Vector2(bx + 2, by - 60), Vector2(bx + 34, by - 20), Vector2(bx + 2, by - 18)]), Color8(220, 210, 186))
			if Game.night.get("sailing", false):
				Sprites.draw(self, Sprites.DOLSOE, Sprites.DOLSOE_PAL, Vector2(bx - 16, by - 12))


func _draw_land() -> void:
	var g := FLOOR_Y[0]
	# 땅 (지하까지 이어지는 흙)
	draw_rect(Rect2(420, g, WORLD_W - 420, 200), Color8(26, 24, 44))
	draw_rect(Rect2(420, g, WORLD_W - 420, 1), Color8(96, 100, 164))
	for i in 160:
		var x := 420 + (i * 53) % int(WORLD_W - 420)
		var y := g + 3 + (i * 7) % 150
		draw_rect(Rect2(x, y, 1, 1), Color(0.6, 0.65, 0.85, 0.3))
	# 가로등
	for x in [500.0, 820.0]:
		draw_rect(Rect2(x, g - 46, 2, 46), Color8(40, 40, 60))
		draw_rect(Rect2(x - 3, g - 49, 8, 4), Color8(255, 214, 140))
		draw_circle(Vector2(x + 1, g - 46), 16, Color(1, 0.8, 0.45, 0.10))
	# 벤치
	draw_rect(Rect2(626, g - 12, 28, 3), Color8(120, 84, 60))
	draw_rect(Rect2(626, g - 20, 28, 2), Color8(120, 84, 60))
	draw_rect(Rect2(628, g - 9, 2, 9), Color8(60, 44, 40))
	draw_rect(Rect2(650, g - 9, 2, 9), Color8(60, 44, 40))


func _draw_building() -> void:
	var font := get_theme_default_font()
	var wall := Color8(140, 144, 182)
	var inside := Color8(66, 56, 84)
	var slab := Color8(196, 200, 226)
	var f0 := FLOOR_Y[0]
	var f1 := FLOOR_Y[1]
	var f2 := FLOOR_Y[2]

	# 지하 1층 (잠김): 어두운 방과 둥근 문
	draw_rect(Rect2(B_X0, f0 + 10, B_X1 - B_X0, B1_Y - f0), Color8(18, 14, 26))
	draw_string(font, Vector2(B_X0 + 70, f0 + 30), "지하 1층 (잠김)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(Pal.DIM, 0.7))
	var vault := Vector2(1300, f0 + 50)
	draw_circle(vault, 22, Color8(60, 54, 70))
	draw_arc(vault, 22, 0, TAU, 32, Color(1, 0.84, 0.4, 0.35 + 0.15 * sin(_t * 1.5)), 2.0)
	for i in 7:
		var a := TAU * i / 7.0 - PI / 2.0
		var lit := i < Game.pieces()
		draw_circle(vault + Vector2.from_angle(a) * 14.0, 2.5, Pal.GOLD if lit else Color8(30, 26, 40))

	# 바깥벽, 각 층 바닥판
	draw_rect(Rect2(B_X0, f2, B_X1 - B_X0, f0 - f2), wall)
	for f in [f0, f1]:
		draw_rect(Rect2(B_X0 + 12, f - 100, B_X1 - B_X0 - 24, 100), inside)
	draw_rect(Rect2(B_X0, f1, B_X1 - B_X0, 10), slab)               # 2층 바닥
	draw_rect(Rect2(B_X0, f2, B_X1 - B_X0, 10), slab)               # 옥상 바닥
	draw_rect(Rect2(B_X0, f0, B_X1 - B_X0, 10), Color8(110, 92, 110))
	# 입구 (1층 왼쪽 벽에 문)
	draw_rect(Rect2(B_X0, f0 - 46, 12, 46), Color8(110, 78, 60))
	draw_rect(Rect2(838, f0 - 30, 2, 30), Color8(80, 70, 90))          # 마당의 안내판
	draw_rect(Rect2(878, f0 - 30, 2, 30), Color8(80, 70, 90))
	draw_rect(Rect2(824, f0 - 46, 70, 16), Color8(34, 30, 60))
	draw_string(font, Vector2(826, f0 - 34), "어린이천문대", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 계단 (왼쪽, 모든 층)
	for f in [f0, f1]:
		for i in 8:
			draw_rect(Rect2(STAIRS_X - 18 + i * 4, f - 4 - i * 12, 10, 3), Color8(150, 140, 180))
		draw_string(font, Vector2(STAIRS_X - 18, f - 86), "계단", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	# 천장 조명
	for f in [f0, f1]:
		for lx in [1060.0, 1260.0, 1460.0]:
			draw_rect(Rect2(lx, f - 100, 6, 3), Color8(255, 220, 150))
			draw_circle(Vector2(lx + 3, f - 96), 20, Color(1, 0.85, 0.55, 0.07))

	# 1층 로비
	draw_string(font, Vector2(B_X0 + 70, f0 - 84), "1층 로비", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_rect(Rect2(1074, f0 - 22, 34, 4), Color8(120, 84, 60))      # 선생님 책상
	draw_rect(Rect2(1076, f0 - 18, 2, 18), Color8(80, 56, 44))
	draw_rect(Rect2(1104, f0 - 18, 2, 18), Color8(80, 56, 44))
	draw_rect(Rect2(1084, f0 - 25, 10, 3), Color8(244, 240, 228))
	var swing := sin(_t * TAU / 4.0) * 16.0                            # 푸코 진자
	draw_line(Vector2(1290, f0 - 100), Vector2(1290 + swing, f0 - 22), Color8(200, 200, 220), 1)
	draw_circle(Vector2(1290 + swing, f0 - 20), 5, Color8(230, 190, 90))
	draw_rect(Rect2(1250, f0 - 4, 80, 3), Color8(90, 80, 120))
	draw_rect(Rect2(1478, f0 - 40, 26, 40), Color8(54, 48, 66))      # 지하로 가는 문
	draw_rect(Rect2(1480, f0 - 38, 22, 38), Color8(40, 36, 52))
	draw_circle(Vector2(1491, f0 - 22), 3, Pal.GOLD)

	# 2층 전시실
	draw_string(font, Vector2(B_X0 + 70, f1 - 84), "2층 전시실 · 옛사람들의 하늘", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	_draw_case(1030.0, f1, Color8(170, 130, 90))                       # 점토판
	_draw_case(1110.0, f1, Color8(190, 170, 110))                      # 죽간
	_draw_case(1320.0, f1, Color8(170, 90, 60))                        # 그리스 도기
	# 누트 여신 그림
	draw_rect(Rect2(1176, f1 - 70, 48, 36), Color8(196, 160, 100))
	draw_rect(Rect2(1178, f1 - 68, 44, 32), Color8(28, 40, 96))
	draw_arc(Vector2(1200, f1 - 40), 18, PI, TAU, 16, Color8(236, 188, 76), 2)
	draw_line(Vector2(1180, f1 - 42), Vector2(1220, f1 - 42), Color8(90, 150, 80), 1)
	if keti_state() == "dormant":
		draw_rect(Rect2(1198, f1 - 56, 4, 8), Color8(244, 240, 228))
	if Game.freed.has("keti"):
		draw_rect(Rect2(1174, f1 - 72, 52, 40), Color(1, 0.84, 0.4, 0.25 + 0.1 * sin(_t * 2.0)), false, 2.0)
	# 천상열차분야지도 (돌판)
	draw_rect(Rect2(1430, f1 - 80, 40, 80), Color8(110, 108, 118))
	draw_rect(Rect2(1434, f1 - 76, 32, 32), Color8(80, 78, 90))
	draw_arc(Vector2(1450, f1 - 60), 14, 0, TAU, 20, Color8(170, 168, 180), 1)
	for i in 14:
		draw_rect(Rect2(1437 + (i * 7) % 26, f1 - 73 + (i * 11) % 26, 1, 1), Color8(230, 230, 240))
	if Game.freed.has("dolsoe"):
		draw_rect(Rect2(1428, f1 - 82, 44, 82), Color(1, 0.84, 0.4, 0.25 + 0.1 * sin(_t * 2.0)), false, 2.0)

	# 3층 옥상 관측 데크
	for x in range(int(B_X0), int(B_X1), 14):
		draw_rect(Rect2(x, f2 - 16, 2, 16), Color8(150, 154, 190))
	draw_rect(Rect2(B_X0, f2 - 18, B_X1 - B_X0, 2), Color8(170, 174, 206))
	var dome := PackedVector2Array()                                     # 돔 (반구)
	for i in 25:
		dome.append(Vector2(1440, f2) + Vector2.from_angle(PI + PI * i / 24.0) * 56.0)
	draw_colored_polygon(dome, Color8(170, 174, 206))
	draw_rect(Rect2(1384, f2, 112, 10), slab)
	draw_rect(Rect2(1432, f2 - 56, 16, 56), Color8(60, 40, 40))
	draw_rect(Rect2(1434, f2 - 52, 12, 52), Color8(255, 196, 120))
	var tx := 1130.0                                                     # 망원경
	draw_line(Vector2(tx, f2 - 26), Vector2(tx - 12, f2), Color8(60, 58, 90), 2)
	draw_line(Vector2(tx, f2 - 26), Vector2(tx + 12, f2), Color8(60, 58, 90), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 18, f2 - 22), Vector2(tx + 16, f2 - 40), Vector2(tx + 19, f2 - 35), Vector2(tx - 15, f2 - 17)]), Color8(224, 226, 240))
	draw_rect(Rect2(tx - 3, f2 - 29, 6, 4), Color8(80, 80, 120))
	# 옥상으로 올라오는 계단 입구
	draw_rect(Rect2(STAIRS_X - 14, f2 - 30, 28, 30), Color8(90, 92, 130))
	draw_rect(Rect2(STAIRS_X - 10, f2 - 26, 20, 26), Color8(40, 36, 60))


## 아직 잠들어 있는 유물이 든 유리 진열장
func _draw_case(x: float, f: float, color: Color) -> void:
	draw_rect(Rect2(x - 14, f - 18, 28, 18), Color8(90, 78, 110))
	draw_rect(Rect2(x - 12, f - 44, 24, 26), Color(0.7, 0.85, 1.0, 0.12))
	draw_rect(Rect2(x - 12, f - 44, 24, 26), Color(0.7, 0.85, 1.0, 0.35), false, 1.0)
	draw_rect(Rect2(x - 6, f - 34, 12, 14), color)


func _draw_people() -> void:
	var ks := keti_state()
	if ks == "hall" or ks == "yard":
		var feet := Vector2(keti.x, floor_y(int(keti.y)) - 2 + sin(_t * 2.0))
		draw_circle(feet + Vector2(0, -14), 20, Color(0.5, 0.9, 1.0, 0.12))
		Sprites.draw_aura(self, Sprites.KETI, feet, Color(0.5, 0.92, 0.97, 0.8))
		Sprites.draw(self, Sprites.KETI, Sprites.KETI_PAL, feet, player_x < keti.x)
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed" and not Game.night.get("sailing", false):
		var on_pier := int(dolsoe.y) == 0 and dolsoe.x < 420
		var feet := Vector2(dolsoe.x, floor_y(int(dolsoe.y)) - (4 if on_pier else 0))
		Sprites.draw_aura(self, Sprites.DOLSOE, feet, Color(0.5, 0.92, 0.97, 0.8))
		Sprites.draw(self, Sprites.DOLSOE, Sprites.DOLSOE_PAL, feet, player_x < dolsoe.x)
	var bob := 1.0 if int(walk_t * 10.0) % 2 == 1 and y_off == 0.0 else 0.0
	var on_pier := floor_i == 0 and player_x < 420
	var ground_y := floor_y(floor_i) - (4 if on_pier else 0)
	if y_off < 0.0:
		var w := 12.0 * (1.0 + y_off / 80.0)
		draw_rect(Rect2(player_x - w / 2.0, ground_y - 1, w, 2), Color(0, 0, 0, 0.35))
	var feet := Vector2(player_x, ground_y - bob + y_off)
	Sprites.draw(self, Sprites.HERO, Sprites.HERO_PAL, feet, facing > 0)
	var light := feet + Vector2(8 * (1 if facing > 0 else -1), -8)
	draw_circle(light, 8, Color(1, 0.2, 0.2, 0.18))


func _draw_prompt() -> void:
	prompt_rect = Rect2()
	if nearest == "" or not active:
		return
	var key := "눌러서" if DisplayServer.is_touchscreen_available() else "E"
	var text := "[%s] %s" % [key, label_of(nearest)]
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL).x + 12
	var x := clampf(player_x - cam.x - w / 2.0, 4, Pal.SCREEN.x - w - 4)
	var y := floor_y(floor_i) - cam.y - 70
	var r := Rect2(x, y, w, 20)
	prompt_rect = r.grow(6)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.CYAN, false, 1.0)
	draw_string(font, r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
