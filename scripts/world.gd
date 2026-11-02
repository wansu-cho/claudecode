extends Control
## 걸어 다니는 섬 풍경입니다. 천문대 안은 층으로, 바깥은 옆으로 이어집니다. (게임 좌표, 플레이어 키 = 40)
##
##   천문대 40 ~ 720 (가운데 큰 홀 구조)
##               왼쪽 40 ~ 300        가운데 홀 300 ~ 460              오른쪽 460 ~ 720
##     3층 옥상  서쪽 난간·망원경      나선 계단 출구, 홀 위의 돔        (빈 관측 데크)
##     2층       선생님 사무실        나선 계단, 진자 줄이 지나는 다리   강의실 (칠판, 잠든 친구들)
##     1층       창고(실습실)         나선 계단, 푸코 진자               책방 (교재, 만화책) → 오른쪽 문으로 바깥
##     지하      일곱 칸 문 너머 별지기의 방 (잠김, 창고에서 내려감)
##   바깥 (1층 높이)  720 ~ 980 천문대 마당(벤치) · 980 ~ 1320 항구(돌쇠의 배, 연락선, 쌍안경)
## 층 이동은 가운데 홀의 나선 계단에서 합니다. (main.gd에서 층을 고름)
## 손님 6명은 어린이천문대 자료에서 깨어납니다.
##   테오: 그리스로마신화 만화책(책방) · 이나: 교재 속 옛 세계 지도(책방) · 보리: 종이 앙부일구(창고)
##   케티: 판서 그림(강의실) · 돌쇠: 선생님이 찍은 바다 별 사진(사무실) · 휘: 지구본(사무실)

signal interact(id: String)
signal prologue_done

const WORLD_W := 1320.0
const FLOOR_Y := {0: 300.0, 1: 190.0, 2: 80.0}    # 층별 바닥 높이 (발 위치)
const B1_Y := 388.0               # 지하 1층 바닥 (지금은 들어갈 수 없음)
const CAM_FEET := 268.0           # 화면에서 발이 놓이는 높이 (아래로 지하가 조금 보이게)
const FLOOR_NAME := {0: "1층", 1: "2층", 2: "3층 옥상"}
const B_X0 := 40.0                # 천문대 왼쪽 벽
const B_X1 := 720.0               # 천문대 오른쪽 벽 (1층에 바깥으로 나가는 문)
const HALL_X0 := 300.0            # 가운데 홀
const HALL_X1 := 460.0
const IN_X0 := 54.0               # 안쪽에서 걸을 수 있는 범위
const IN_X1 := 706.0
const YARD_X1 := 980.0            # 이 오른쪽은 항구 (부두)
const STAIRS_X := 330.0           # 나선 계단
const PEND_X := 405.0             # 푸코 진자 (줄은 돔 꼭대기에서 1층까지)
const DOME_X := 400.0
const HOR := 262.0                # 1층 높이에서 본 수평선
const SKY_K := 3.0
const SPEED := 145.0
const JUMP_V := 235.0             # 점프 처음 속도 (픽셀/초)
const GRAVITY := 780.0
const NPC_SPEED := 55.0
const REACH := 24.0
const CHAR_H := 40.0              # 아이 캐릭터의 키 (게임 좌표). 새 그림(시트)은 이 키로 그림
const OLD_PX := 1.5               # 아직 새 그림이 없는 사람(옛 도트 그림)을 키에 맞춰 키우는 배율
## 지하 문의 별 모양 홈: (고리 반지름, 문 바닥에서 고리 가운데까지 높이) — 게임 좌표
const DOOR_RING := Vector2(6.1, 36.8)
## 그림 배경이 있는 방: 이름 -> 게임 속 자리 (그림 바닥 쪽 8칸은 바닥판 아래로 들어감)
const BACKGROUNDS := {
	"office": Rect2(40, 88, 260, 110),
	"lecture": Rect2(460, 88, 260, 110),
	"storage": Rect2(40, 198, 260, 110),
	"bookshop": Rect2(460, 198, 260, 110),
	"hall": Rect2(300, 88, 160, 220),
}
## 바깥 그림 배경: 이름 -> 게임 속 자리 (마당 흙길, 부두 마루가 1층 바닥 높이에 오게)
const OUTDOOR := {
	"yard": Rect2(720, 193, 260, 170),
	"harbor": Rect2(980, 208, 340, 170),
	"roof_dome": Rect2(312.7, -3.8, 136.4, 77.8),      # 계단 출구(가운데 330)와 돔(가운데 402)
}
const ROOF_TILE := Rect2(0, -16.4, 256, 110)            # 옥상 바닥·난간 한 조각 (x는 이어 붙이며 정함)
const SOIL := Color8(39, 16, 25)      # 마당 그림 맨 아래 흙 색 (그림 아래로 이어지는 땅)
## 가운데 홀 그림 속 2층 다리는 다른 방 바닥보다 이만큼 높습니다 (다리 위를 걸음)
const BRIDGE_UP := 19.0
const WORKBENCH_UP := 50.0          # 창고 그림 속 작업대 윗면 높이 (바닥에서)
## 벽시계: 배경 이름 -> (방 왼쪽 위에서의 위치 x, y, 반지름) — 바늘은 게임 시각에 맞춰 그림
const CLOCKS := {"office": Vector3(130.6, 23.1, 5.5), "lecture": Vector3(115.0, 31.9, 5.7)}
const HD := {"keti": "keti", "teo": "teo", "ina": "ina", "dolsoe": "dolsoe", "bori": "bori", "hwi": "hwi"}   # 새 그림이 있는 사람 -> 시트 이름

const SPOTS := [
	# 1층: 창고 · 가운데 홀 · 책방 · 바깥
	{"id": "orrery", "floor": 0, "x": 95.0, "label": "지구 공전 모형"},
	{"id": "sundial", "floor": 0, "x": 175.0, "label": "만들기 실습: 종이 앙부일구"},
	{"id": "b1door", "floor": 0, "x": 262.0, "label": "지하로 내려가는 문"},
	{"id": "stairs", "floor": 0, "x": STAIRS_X, "label": "나선 계단"},
	{"id": "pendulum", "floor": 0, "x": PEND_X, "label": "푸코 진자 살펴보기"},
	{"id": "books", "floor": 0, "x": 514.0, "label": "안락의자에 앉아 교재 읽기"},
	{"id": "mapbook", "floor": 0, "x": 580.0, "label": "교재 펼친 쪽: 옛사람들의 세계 지도"},
	{"id": "comic", "floor": 0, "x": 655.0, "label": "그리스로마신화 만화책"},
	{"id": "bench", "floor": 0, "x": 878.0, "label": "벤치에 앉아 기다리기"},
	{"id": "binoculars", "floor": 0, "x": 1296.0, "label": "부두 쌍안경으로 바다 보기"},
	# 2층: 선생님 사무실 · 가운데 홀 · 강의실
	{"id": "photo", "floor": 1, "x": 80.0, "label": "선생님이 찍은 사진: 별빛섬 바다의 북두칠성"},
	{"id": "note", "floor": 1, "x": 160.0, "label": "선생님 책상"},
	{"id": "globe", "floor": 1, "x": 245.0, "label": "지구본"},
	{"id": "stairs", "floor": 1, "x": STAIRS_X, "label": "나선 계단"},
	{"id": "blackboard", "floor": 1, "x": 490.0, "label": "칠판 보기: 오늘 밤 하늘"},
	{"id": "drawing", "floor": 1, "x": 538.0, "label": "판서 그림: 이집트 사람들의 하늘"},
	{"id": "kids", "floor": 1, "x": 632.0, "label": "잠든 친구들"},
	# 3층 옥상
	{"id": "sunset", "floor": 2, "x": 70.0, "label": "서쪽 하늘 바라보기 (해넘이)"},
	{"id": "telescope", "floor": 2, "x": 180.0, "label": "망원경으로 북쪽 하늘 보기"},
	{"id": "stairs", "floor": 2, "x": STAIRS_X, "label": "나선 계단"},
	{"id": "dome", "floor": 2, "x": DOME_X + 10.0, "label": "돔 안의 큰 망원경"},
]

## 등장인물: 깨어나는 자료, 깨어나는 시각, 시간표 [시각, (x, 층)]
const NPC_PLAN := {
	"keti": {"home": "drawing", "wake": "18:00", "plan": [["18:00", Vector2(505, 1)], ["21:00", Vector2(600, 2)]]},
	"teo": {"home": "comic", "wake": "18:00", "plan": [["18:00", Vector2(440, 0)], ["23:30", Vector2(650, 2)]]},
	"ina": {"home": "mapbook", "wake": "18:30", "plan": [["18:30", Vector2(1130, 0)]]},
	"dolsoe": {"home": "photo", "wake": "19:00", "plan": [["19:00", Vector2(110, 1)], ["20:00", Vector2(1040, 0)]]},
	"bori": {"home": "sundial", "wake": "19:00", "plan": [["19:00", Vector2(135, 0)]]},
	"hwi": {"home": "globe", "wake": "20:00", "plan": [["20:00", Vector2(530, 2)]]},
}
## 돌쇠가 배를 띄울 수 있는 마지막 시각 (물때). 북두칠성의 국자 끝 두 별은 21:55에야 산 위로 올라옵니다.
const TIDE_END := "21:30"
const BOAT_X := 1060.0             # 돌쇠의 배 (떠나면 오른쪽 바다로)
const FERRY_X := 1190.0            # 섬 연락선 (19:30 출항)
const TEACHER_X := 952.0           # 프롤로그에서 선생님이 서 있는 곳 (마당)

var player_x := 200.0
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
var npc := {}                     # 등장인물 id -> 지금 위치 (x, 층)
var boat_x := BOAT_X
var cam := Vector2.ZERO
var land_t := 9.0                 # 착지한 뒤 지난 시간 (착지 자세를 잠깐 보여 줌)
var _npc_prev := {}               # 사람마다 지난 프레임 위치 (걷는지 알아보려고)
var _npc_moving := {}
var _npc_seen := {}               # 사람이 처음 보인 뒤 지난 시간 (깨어나는 동작)
var prologue := false             # 첫 밤 전 오후: 마당의 선생님만 만날 수 있고 천문대 문은 닫혀 있음
var _t := 0.0
var _bg_tex := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR    # 새 그림(고해상도 시트)을 부드럽게 줄여 그림
	reset_night()


func reset_night() -> void:
	player_x = 200.0
	floor_i = 2
	y_off = 0.0
	vy = 0.0
	jumps = 0
	npc.clear()
	for id in NPC_PLAN:
		npc[id] = Vector2(spot_x(NPC_PLAN[id]["home"]), spot_floor(NPC_PLAN[id]["home"]))
	boat_x = BOAT_X
	facing = 1
	_snap_camera()


## 프롤로그: 항구의 연락선 옆에서 시작합니다.
func start_prologue() -> void:
	prologue = true
	floor_i = 0
	player_x = 1150.0
	facing = -1
	_snap_camera()


## 다른 층으로 옮깁니다. (나선 계단)
func go_floor(f: int) -> void:
	floor_i = f
	player_x = STAIRS_X + 16.0
	y_off = 0.0
	vy = 0.0
	jumps = 0
	_snap_camera()


func floor_y(f: int) -> float:
	return FLOOR_Y[f]


## 서 있는 높이: 2층에서 가운데 홀을 지날 때는 홀 그림 속 다리 위
func ground_y(f: int, x: float) -> float:
	if f == 1 and x > HALL_X0 + 6 and x < HALL_X1 - 6:
		return FLOOR_Y[1] - BRIDGE_UP
	return FLOOR_Y[f]


# ---- 등장인물의 시간표 ----

static func spot_x(id: String) -> float:
	for sp in SPOTS:
		if sp["id"] == id:
			return sp["x"]
	return 0.0


static func spot_floor(id: String) -> int:
	for sp in SPOTS:
		if sp["id"] == id:
			return sp["floor"]
	return 0


## "freed"(아침으로 돌아감) / "dormant"(아직 잠듦) / "awake" / 돌쇠만: "hall", "harbor", "late"
static func npc_state(id: String) -> String:
	if Game.freed.has(id):
		return "freed"
	if Game.minutes < Game.at(NPC_PLAN[id]["wake"]):
		return "dormant"
	if id == "dolsoe":
		if Game.minutes < Game.at("20:00"):
			return "hall"
		return "harbor" if Game.minutes < Game.at(TIDE_END) else "late"
	return "awake"


static func npc_target(id: String) -> Vector2:
	var target: Vector2 = NPC_PLAN[id]["plan"][0][1]
	for step in NPC_PLAN[id]["plan"]:
		if Game.minutes >= Game.at(step[0]):
			target = step[1]
	return target


func npc_visible(id: String) -> bool:
	var st := npc_state(id)
	if st == "freed" or st == "dormant":
		return false
	return not (id == "dolsoe" and Game.night.get("sailing", false))


## 사람을 목표 자리로 걷게 합니다. 층이 다르면 나선 계단에서 나타납니다.
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
			var lo := B_X1 + 14.0 if prologue else IN_X0
			var hi := WORLD_W - 12.0 if floor_i == 0 else IN_X1
			player_x = clampf(player_x + dir * SPEED * delta, lo, hi)
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
			land_t = 0.0
	land_t += delta

	for id in NPC_PLAN:
		if npc_visible(id):
			npc[id] = _walk_npc(npc[id], npc_target(id), delta)
			_npc_moving[id] = _npc_prev.get(id, npc[id]) != npc[id]
			_npc_prev[id] = npc[id]
			_npc_seen[id] = _npc_seen.get(id, 0.0) + delta
		else:
			_npc_seen.erase(id)
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
	if prologue:
		return [{"id": "teacher", "x": TEACHER_X, "label": "선생님께 인사하기", "npc": true}] if floor_i == 0 else []
	for s in SPOTS:
		if s["floor"] == floor_i:
			out.append(s)
	for id in NPC_PLAN:
		if npc_visible(id) and int(npc[id].y) == floor_i:
			out.append({"id": id, "x": npc[id].x, "label": "%s와 이야기하기" % Story.NPC[id]["name"], "npc": true})
	return out


func _find_nearest() -> String:
	var best := ""
	var best_d := REACH
	for t in targets():
		var d := absf(float(t["x"]) - player_x)
		if t.has("npc"):
			d -= 10.0                      # 사람과 물건이 겹치면 사람과 먼저 이야기합니다
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
	if floor_i == 0 and player_x > B_X1:
		return "천문대 마당" if player_x < YARD_X1 else "항구"
	if floor_i == 2:
		return FLOOR_NAME[2]
	if player_x < HALL_X0:
		return "1층 창고" if floor_i == 0 else "2층 선생님 사무실"
	if player_x < HALL_X1:
		return "%s 가운데 홀" % FLOOR_NAME[floor_i]
	return "1층 책방" if floor_i == 0 else "2층 강의실"


func _on_pier() -> bool:
	return player_x > YARD_X1


# ---- 그리기 ----

func _draw() -> void:
	var m := Game.minutes
	var hy := HOR - cam.y * 0.15             # 먼 하늘과 바다는 조금만 움직입니다
	SkyPainter.draw(self, m, Pal.SCREEN, SkyPainter.cyl(Pal.SCREEN.x / 2.0, hy, SKY_K))
	_draw_sea(m, hy)
	draw_set_transform(-cam)
	_draw_land()
	_draw_harbor()
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


## 땅 (천문대 아래부터 마당까지, 지하까지 이어지는 흙)과 마당
func _draw_land() -> void:
	var g: float = FLOOR_Y[0]
	draw_rect(Rect2(0, g, YARD_X1, 220), SOIL)
	_draw_outdoor("yard")
	_prop("bench", Vector2(878, g))


## 바깥 그림 배경 하나 그리기
func _draw_outdoor(name: String) -> void:
	if not _bg_tex.has(name):
		_bg_tex[name] = load("res://assets/backgrounds/%s.png" % name)
	draw_texture_rect(_bg_tex[name], OUTDOOR[name], false)


## 항구: 부두, 연락선, 쌍안경, 돌쇠의 배
func _draw_harbor() -> void:
	var g: float = FLOOR_Y[0]
	_draw_outdoor("harbor")
	# 섬 연락선 (19:30에 떠남)
	if Game.minutes < Game.at("19:30"):
		var fx := FERRY_X
		var fy := g + 44                                           # 물 위 (부두 앞)
		_prop2("ferry", Vector2(fx, fy), "", "boats")
		draw_string(get_theme_default_font(), Vector2(fx - 40, fy - 104), "마지막 배 19:30", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	_prop("binoculars", Vector2(1296, g))                           # 부두 쌍안경 (부두 끝)
	if not Game.freed.has("dolsoe") or Game.night.get("sailing", false):
		if boat_x < WORLD_W + 60:
			var bob := sin(_t * 1.5) * 1.5
			var bx := boat_x
			var by := g + 44 + bob
			if Game.night.get("sailing", false):                          # 북극성을 가리키며 떠남 (뱃전이 발을 가림)
				SheetSprite.named("dolsoe").draw(self, "point", 0, Vector2(bx - 30, by - 6), false, CHAR_H)
			_prop2("boat", Vector2(bx, by), "", "boats")


func _draw_building() -> void:
	var font := get_theme_default_font()
	var wall := Color8(140, 144, 182)
	var slab := Color8(196, 200, 226)
	var f0: float = FLOOR_Y[0]
	var f1: float = FLOOR_Y[1]
	var f2: float = FLOOR_Y[2]

	# 지하 1층 (잠김): 어두운 방과 둥근 문
	draw_rect(Rect2(B_X0, f0 + 10, B_X1 - B_X0, B1_Y - f0), Color8(18, 14, 26))
	draw_string(font, Vector2(B_X0 + 20, f0 + 30), "지하 1층 · 별지기의 방 (잠김)", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(Pal.DIM, 0.7))
	var vault := Vector2(380, f0 + 50)
	draw_circle(vault, 22, Color8(60, 54, 70))
	draw_arc(vault, 22, 0, TAU, 32, Color(1, 0.84, 0.4, 0.35 + 0.15 * sin(_t * 1.5)), 2.0)

	# 바깥벽 (방 안은 모두 그림 배경)
	draw_rect(Rect2(B_X0, f2, B_X1 - B_X0, f0 - f2), wall)
	_draw_backgrounds()
	# 바닥판: 2층은 양쪽 방만 (가운데 홀은 그림 속 다리)
	draw_rect(Rect2(B_X0, f1, HALL_X0 - B_X0 + 4, 10), slab)
	draw_rect(Rect2(HALL_X1 - 4, f1, B_X1 - HALL_X1 + 4, 10), slab)
	draw_rect(Rect2(B_X0, f0, B_X1 - B_X0, 10), Color8(110, 92, 110))

	_draw_storage(f0)
	_draw_hall(f0, f2)
	_draw_bookshop(font, f0)
	_draw_office(f1)
	_draw_lecture(font, f1)
	_draw_roof(font, f2)


## 그림 배경 (방 하나씩). 창문처럼 비워 둔 곳에는 지금 하늘 색이 비쳐 보입니다.
func _draw_backgrounds() -> void:
	var dark := Astro.darkness(Game.minutes)
	var sky := SkyPainter.DAY_TOP.lerp(SkyPainter.NIGHT_TOP, dark).lerp(SkyPainter.MOON_SKY, Astro.moonlight(Game.minutes) * dark * 0.3)
	for name in BACKGROUNDS:
		if not _bg_tex.has(name):
			_bg_tex[name] = load("res://assets/backgrounds/%s.png" % name)
		var r: Rect2 = BACKGROUNDS[name]
		draw_rect(r, sky)
		for i in 6:                                                    # 창밖의 별 몇 개
			draw_rect(Rect2(r.position + Vector2((i * 37) % int(r.size.x), (i * 23) % 40 + 8), Vector2.ONE), Color(1, 1, 1, 0.7 * dark))
		draw_texture_rect(_bg_tex[name], r, false)
		if CLOCKS.has(name):
			var ck: Vector3 = CLOCKS[name]
			_draw_clock(r.position + Vector2(ck.x, ck.y), ck.z)


## 진짜로 가는 벽시계: 그림 속 시계 판을 덮고 눈금과 바늘을 지금 게임 시각으로 그립니다.
## (해가 뜨며 시간이 되감길 때는 바늘도 거꾸로 돕니다)
func _draw_clock(c: Vector2, rad: float) -> void:
	var ink := Color8(48, 22, 20)
	draw_circle(c, rad - 0.4, Color8(238, 198, 154))
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0 - PI / 2.0)
		var inner := rad - (1.6 if i % 3 == 0 else 1.0)
		draw_line(c + dir * inner, c + dir * (rad - 0.5), ink, 0.5 if i % 3 else 0.7)
	var total := fposmod(Game.START_CLOCK + Game.minutes, 24.0 * 60.0)
	var minute := fmod(total, 60.0)
	var hour := fmod(total / 60.0, 12.0)
	draw_line(c, c + Vector2.from_angle(TAU * minute / 60.0 - PI / 2.0) * (rad * 0.78), ink, 0.5)
	draw_line(c, c + Vector2.from_angle(TAU * hour / 12.0 - PI / 2.0) * (rad * 0.5), ink, 0.8)
	draw_circle(c, 0.6, Color8(150, 60, 40))


## 1층 창고(실습실): 지구 공전 모형, 아이들이 만든 종이 앙부일구, 지하로 가는 문
func _draw_storage(f0: float) -> void:
	_prop("orrery", Vector2(95, f0))
	# 작업대(배경 그림) 위의 종이 앙부일구 (반구 그릇 모양)
	var top := f0 - WORKBENCH_UP
	_prop2("dial", Vector2(175, top), "bori")
	_glow_if_freed("bori", Rect2(162, top - 14, 26, 16))
	_prop("door", Vector2(262, f0))                                     # 지하로 가는 문
	for i in 7:                                                         # 문 위 별 모양 홈 7개: 모은 조각만큼 빛남
		if i < Game.pieces():
			var hole := Vector2(262, f0 - DOOR_RING.y) + Vector2.from_angle(-PI / 2.0 + TAU * i / 7.0) * DOOR_RING.x
			draw_circle(hole, 2.2, Pal.GOLD)
			draw_circle(hole, 5.0, Color(1, 0.84, 0.4, 0.25 + 0.1 * sin(_t * 2.0 + i)))


## 가운데 홀: 돔 꼭대기에서 1층까지 내려온 푸코 진자
func _draw_hall(f0: float, f2: float) -> void:
	_prop("dial", Vector2(PEND_X, f0))
	var swing := sin(_t * TAU / 4.0) * 14.0                             # 추는 긴 줄에 매달려 흔들림
	var bob := Vector2(PEND_X + swing, f0 - 10)
	draw_line(Vector2(PEND_X, f2 + 10), bob + Vector2(0, -9), Color8(200, 200, 220), 1)
	_prop("bob", bob)


## 1층 책방 (책장과 안락의자는 배경 그림): 교재 펼친 쪽(이나), 그리스로마신화 만화책(테오)
func _draw_bookshop(font: Font, f0: float) -> void:
	_prop2("mapbook", Vector2(580, f0), "ina")                            # 교재 펼친 쪽: 옛사람들의 세계 지도
	_glow_if_freed("ina", Rect2(564, f0 - 36, 32, 36))
	_prop2("comic", Vector2(655, f0), "teo")                              # 그리스로마신화 만화책 진열대
	_glow_if_freed("teo", Rect2(639, f0 - 40, 32, 40))


## 2층 선생님 사무실: 바다 별 사진(돌쇠), 책상과 쪽지, 지구본(휘)
func _draw_office(f1: float) -> void:
	_prop2("photo", Vector2(81, f1 - 48), "dolsoe")                       # 바다 별 사진 액자 (벽)
	_glow_if_freed("dolsoe", Rect2(62, f1 - 76, 38, 30))
	_prop("desk", Vector2(160, f1))
	_prop2("globe", Vector2(245, f1), "hwi")                              # 지구본
	_glow_if_freed("hwi", Rect2(231, f1 - 38, 28, 38))


## 2층 강의실: 칠판, 판서 그림(케티), 잠든 친구들
func _draw_lecture(font: Font, f1: float) -> void:
	_prop2("board", Vector2(492, f1 - 32))                                # 칠판 (벽)
	_prop2("drawing", Vector2(538, f1 - 44), "keti")                      # 판서 그림: 하늘의 여신 누트
	_glow_if_freed("keti", Rect2(518, f1 - 76, 40, 34))
	var kids := SheetSprite.named("kids")
	for k in 4:
		var dx := 580.0 + k * 35.0
		# 숨쉬기 (1.2초마다 들숨·날숨), 사람마다 9초에 한 번씩 1.5초 동안 잠꼬대
		var talk := fmod(_t + k * 2.3, 9.0) < 1.5
		var fi := 2 if talk else int(_t / 1.2 + k) % 2
		kids.draw(self, "kid%d" % (k + 1), fi, Vector2(dx, f1), false, CHAR_H)
		var zt := fmod(_t * 0.6 + k * 0.37, 1.0)
		draw_string(font, Vector2(dx + 6 + zt * 6, f1 - 36 - zt * 14), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Color(0.8, 0.85, 1.0, 1.0 - zt))


## 3층 옥상: 난간, 서쪽 표지판, 망원경, 홀 위의 돔, 계단 출구
func _draw_roof(font: Font, f2: float) -> void:
	if not _bg_tex.has("roof"):
		_bg_tex["roof"] = load("res://assets/backgrounds/roof.png")
	var tex: Texture2D = _bg_tex["roof"]
	var x := B_X0
	while x < B_X1:                                                     # 바닥·난간 조각을 옆으로 이어 붙임
		var w := minf(ROOF_TILE.size.x, B_X1 - x)
		var src := Rect2(0, 0, tex.get_width() * w / ROOF_TILE.size.x, tex.get_height())
		draw_texture_rect_region(tex, Rect2(x, ROOF_TILE.position.y, w, ROOF_TILE.size.y), src)
		x += w
	_draw_outdoor("roof_dome")
	_prop("telescope", Vector2(180, f2))                                # 북쪽 하늘 망원경


## 관측 장치·소품 그림 (props 시트). feet: 바닥 가운데
func _prop(name: String, feet: Vector2) -> void:
	SheetSprite.named("props").draw(self, name, 0, feet, false, CHAR_H)


## 소품 2차 (props2, boats 시트). guest가 있으면 손님이 깨어나 빠져나간 뒤에는 빈 모습(_e)으로
func _prop2(name: String, feet: Vector2, guest := "", sheet := "props2") -> void:
	var n := name if guest == "" or npc_state(guest) == "dormant" else name + "_e"
	SheetSprite.named(sheet).draw(self, n, 0, feet, false, CHAR_H)


## 손님의 이야기를 풀어 준 물건: 둘레에 작은 금빛 별이 번갈아 반짝입니다 (네모 테두리 대신)
func _glow_if_freed(id: String, r: Rect2) -> void:
	if not Game.freed.has(id):
		return
	for i in 4:
		var ph := fmod(_t * 0.7 + i * 0.25 + id.length() * 0.13, 1.0)   # 별마다 0→1 한 번 반짝
		var a := sin(ph * PI)
		var q := Vector2(r.position.x + r.size.x * fposmod(0.15 + i * 0.29 + id.length() * 0.07, 1.0),
				r.position.y + r.size.y * fposmod(0.2 + i * 0.37, 1.0))
		var k := 1.0 + 2.0 * a
		var c := Color(1, 0.9, 0.55, a)
		draw_line(q - Vector2(k, 0), q + Vector2(k, 0), c, 0.6)
		draw_line(q - Vector2(0, k), q + Vector2(0, k), c, 0.6)


func _draw_people() -> void:
	for id in NPC_PLAN:
		if not npc_visible(id):
			continue
		var p: Vector2 = npc[id]
		var f := int(p.y)
		var on_pier := f == 0 and p.x > YARD_X1
		var feet := Vector2(p.x, ground_y(f, p.x) - (4 if on_pier else 0))
		if id == "keti":
			feet.y += sin(_t * 2.0) - 2.0
		if HD.has(id):
			_draw_hd_npc(id, feet, player_x < p.x)
		else:
			Sprites.draw_aura(self, Sprites.rows(id), feet, Color(0.5, 0.92, 0.97, 0.8), OLD_PX)
			Sprites.draw(self, Sprites.rows(id), Sprites.pal(id), feet, player_x < p.x, 1.0, OLD_PX)
	if prologue:                                                    # 해를 등진 선생님 (얼굴이 안 보이는 실루엣)
		var tf := Vector2(TEACHER_X, floor_y(0))
		var t_sp := SheetSprite.named("teacher")
		var near := absf(player_x - TEACHER_X) < 90.0          # 가까이 오면 손을 흔듦
		t_sp.draw(self, "wave" if near else "idle", 0 if near else t_sp.frame_at("idle", _t), tf, player_x < TEACHER_X,
				CHAR_H, Color(0.16, 0.13, 0.22))                # 해를 등져 얼굴이 보이지 않는 실루엣
	var gy := ground_y(floor_i, player_x) - (4 if floor_i == 0 and _on_pier() else 0)
	if y_off < 0.0:
		var w := 16.0 * (1.0 + y_off / 80.0)
		draw_rect(Rect2(player_x - w / 2.0, gy - 1, w, 2), Color(0, 0, 0, 0.35))
	var feet := Vector2(player_x, gy + y_off)
	var hero := SheetSprite.named("hero")
	var anim := "idle"
	var fi := hero.frame_at("idle", _t)
	if y_off < 0.0:
		anim = "jump"
		fi = 1 if vy < 0.0 else 2
	elif land_t < 0.09:
		anim = "jump"
		fi = 0
	elif walk_t > 0.0:
		anim = "walk"
		fi = hero.frame_at("walk", walk_t)
	hero.draw(self, anim, fi, feet, facing < 0, CHAR_H)


## 새 그림이 있는 사람: 깨어날 때는 깨어나는 동작, 걸을 때는 걷기, 서 있으면 대기
func _draw_hd_npc(id: String, feet: Vector2, flip: bool) -> void:
	var sp := SheetSprite.named(HD[id])
	var seen: float = _npc_seen.get(id, 99.0)
	if sp.has_anim("wake") and seen < 2.4:
		sp.draw(self, "wake", int(seen / 0.6), feet, flip, CHAR_H)
	elif _npc_moving.get(id, false):
		sp.draw(self, "walk", sp.frame_at("walk", _t), feet, flip, CHAR_H)
	elif id == "hwi" and Astro.eclipse_phase(Game.minutes) != "none":
		sp.draw(self, "record", 0, feet, flip, CHAR_H)      # 월식을 죽간에 기록함
	elif id == "ina" and Game.minutes >= Game.at("19:30") and Game.minutes < Game.at("21:00"):
		sp.draw(self, "gaze", 0, feet, false, CHAR_H)       # 떠나는 연락선을 손차양하고 바라봄
	else:
		sp.draw(self, "idle", sp.frame_at("idle", _t), feet, flip, CHAR_H)


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
