extends Control
## 걸어 다니는 섬 풍경입니다. (옆으로 이어진 한 줄짜리 지도)
##
##   0 ~ 520     항구 (돌쇠의 배)
##   520 ~ 1500  언덕길, 벤치, 천문대 마당과 망원경
##   1560 ~ 2560 천문대 (로비의 푸코 진자, 선생님 책상, 전시실의 유물)

signal interact(id: String)

const WORLD_W := 2560.0
const GROUND := 300.0
const HOR := 262.0
const SKY_K := 3.0
const SPEED := 145.0
const JUMP_V := 235.0       # 점프 처음 속도 (픽셀/초)
const GRAVITY := 780.0
const NPC_SPEED := 55.0
const REACH := 26.0

const SPOTS := [
	{"id": "bench", "x": 820.0, "label": "벤치에 앉아 기다리기"},
	{"id": "telescope", "x": 1340.0, "label": "망원경으로 하늘 보기"},
	{"id": "pendulum", "x": 1880.0, "label": "푸코 진자 살펴보기"},
	{"id": "note", "x": 2010.0, "label": "선생님 책상"},
	{"id": "nut", "x": 2230.0, "label": "누트 여신 그림 (복제품)"},
	{"id": "starmap", "x": 2460.0, "label": "천상열차분야지도 (복각본)"},
]
const KETI_HOME := 2230.0
const KETI_YARD := 1270.0
const DOLSOE_HOME := 2460.0
const DOLSOE_HARBOR := 330.0
const BOAT_X := 200.0

var player_x := 1400.0
var facing := -1
var walk_t := 0.0
var active := true
var pad_dir := 0.0           # 가상 키패드 입력 (-1 ~ 1)
var y_off := 0.0             # 점프 높이 (위가 −)
var vy := 0.0
var jumps := 0
var prompt_rect := Rect2()   # 화면에 보이는 [확인] 말풍선 (누르면 상호작용)
var nearest := ""
var keti_x := KETI_HOME
var dolsoe_x := DOLSOE_HOME
var boat_x := BOAT_X
var cam := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset_night() -> void:
	player_x = 1400.0
	y_off = 0.0
	vy = 0.0
	jumps = 0
	keti_x = KETI_HOME
	dolsoe_x = DOLSOE_HOME
	boat_x = BOAT_X
	facing = -1


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
			player_x = clampf(player_x + dir * SPEED * delta, 12.0, WORLD_W - 12.0)
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
		keti_x = move_toward(keti_x, KETI_HOME if ks == "hall" else KETI_YARD, NPC_SPEED * delta)
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed":
		dolsoe_x = move_toward(dolsoe_x, DOLSOE_HOME if ds == "hall" else DOLSOE_HARBOR, NPC_SPEED * delta)
	if Game.night.get("sailing", false):
		boat_x += 28.0 * delta

	nearest = _find_nearest()
	cam = clampf(player_x - Pal.SCREEN.x / 2.0, 0.0, WORLD_W - Pal.SCREEN.x)
	queue_redraw()


func targets() -> Array:
	var out := SPOTS.duplicate()
	var ks := keti_state()
	if ks == "hall" or ks == "yard":
		out.append({"id": "keti", "x": keti_x, "label": "케티와 이야기하기"})
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed" and not Game.night.get("sailing", false):
		out.append({"id": "dolsoe", "x": dolsoe_x, "label": "돌쇠와 이야기하기"})
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


func try_interact() -> void:
	if active and nearest != "":
		interact.emit(nearest)


func label_of(id: String) -> String:
	for t in targets():
		if t["id"] == id:
			return t["label"]
	return ""


# ---- 그리기 ----

func _draw() -> void:
	var m := Game.minutes
	SkyPainter.draw(self, m, Pal.SCREEN, HOR, SKY_K, Pal.SCREEN.x / 2.0)
	_draw_sea(m)
	draw_set_transform(Vector2(-cam, 0))
	_draw_harbor()
	_draw_land()
	_draw_building()
	_draw_people()
	draw_set_transform(Vector2.ZERO)
	_draw_prompt()


func _draw_sea(m: float) -> void:
	var dark := Astro.darkness(m)
	var sea := Color8(70, 110, 160).lerp(Color8(26, 18, 46), dark)
	draw_rect(Rect2(0, HOR, Pal.SCREEN.x, GROUND - HOR + 60), sea)
	for i in 40:
		var x := fposmod(i * 97.0 - cam * 0.2 + sin(_t + i) * 3.0, Pal.SCREEN.x)
		var y := HOR + 3 + (i * 13) % int(GROUND - HOR - 4)
		draw_rect(Rect2(x, y, 3 + i % 4, 1), Color(0.75, 0.5, 0.8, 0.35 * dark + 0.15))
	# 먼 등대 섬
	var lx := 470.0 - cam * 0.05
	draw_colored_polygon(PackedVector2Array([Vector2(lx - 30, HOR + 1), Vector2(lx - 12, HOR - 6), Vector2(lx + 14, HOR - 5), Vector2(lx + 30, HOR + 1)]), Color8(14, 10, 24))
	draw_rect(Rect2(lx - 1, HOR - 24, 3, 18), Color8(196, 196, 214))
	draw_rect(Rect2(lx - 1, HOR - 18, 3, 3), Color8(190, 60, 70))
	var beam := 0.5 + 0.5 * sin(_t * 1.6)
	draw_rect(Rect2(lx - 2, HOR - 27, 5, 3), Color(1, 0.9, 0.6, 0.6 + 0.4 * beam))
	draw_circle(Vector2(lx, HOR - 26), 6, Color(1, 0.85, 0.5, 0.15 * dark * beam + 0.05))


func _draw_harbor() -> void:
	# 부두 (나무 판자)
	draw_rect(Rect2(0, GROUND - 4, 520, 6), Color8(92, 66, 54))
	for x in range(0, 520, 12):
		draw_rect(Rect2(x, GROUND - 4, 1, 6), Color8(60, 42, 38))
	for x in range(10, 520, 60):
		draw_rect(Rect2(x, GROUND + 2, 4, 30), Color8(50, 36, 34))
	# 돌쇠의 배
	if not Game.freed.has("dolsoe") or Game.night.get("sailing", false):
		if boat_x < WORLD_W:
			var bob := sin(_t * 1.5) * 1.5
			var bx := boat_x
			var by := GROUND + 10 + bob
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 40, by - 10), Vector2(bx + 40, by - 10), Vector2(bx + 30, by), Vector2(bx - 30, by)]), Color8(110, 74, 50))
			draw_rect(Rect2(bx - 40, by - 12, 80, 2), Color8(150, 104, 70))
			draw_rect(Rect2(bx - 2, by - 62, 3, 52), Color8(80, 56, 40))
			draw_colored_polygon(PackedVector2Array([Vector2(bx + 2, by - 60), Vector2(bx + 34, by - 20), Vector2(bx + 2, by - 18)]), Color8(220, 210, 186))
			if Game.night.get("sailing", false):
				Sprites.draw(self, Sprites.DOLSOE, Sprites.DOLSOE_PAL, Vector2(bx - 16, by - 12))


func _draw_land() -> void:
	draw_rect(Rect2(520, GROUND, WORLD_W - 520, 80), Color8(26, 24, 44))
	draw_rect(Rect2(520, GROUND, WORLD_W - 520, 1), Color8(96, 100, 164))
	for i in 220:
		var x := 520 + (i * 53) % int(WORLD_W - 520)
		var y := GROUND + 3 + (i * 7) % 55
		draw_rect(Rect2(x, y, 1, 1), Color(0.6, 0.65, 0.85, 0.35))
	# 가로등
	for x in [640.0, 1060.0]:
		draw_rect(Rect2(x, GROUND - 46, 2, 46), Color8(40, 40, 60))
		draw_rect(Rect2(x - 3, GROUND - 49, 8, 4), Color8(255, 214, 140))
		draw_circle(Vector2(x + 1, GROUND - 46), 16, Color(1, 0.8, 0.45, 0.10))
	# 벤치
	draw_rect(Rect2(806, GROUND - 12, 28, 3), Color8(120, 84, 60))
	draw_rect(Rect2(806, GROUND - 20, 28, 2), Color8(120, 84, 60))
	draw_rect(Rect2(808, GROUND - 9, 2, 9), Color8(60, 44, 40))
	draw_rect(Rect2(830, GROUND - 9, 2, 9), Color8(60, 44, 40))
	# 망원경
	var tx := 1340.0
	draw_line(Vector2(tx, GROUND - 26), Vector2(tx - 12, GROUND), Color8(60, 58, 90), 2)
	draw_line(Vector2(tx, GROUND - 26), Vector2(tx + 12, GROUND), Color8(60, 58, 90), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 18, GROUND - 22), Vector2(tx + 16, GROUND - 40), Vector2(tx + 19, GROUND - 35), Vector2(tx - 15, GROUND - 17)]), Color8(224, 226, 240))
	draw_rect(Rect2(tx - 3, GROUND - 29, 6, 4), Color8(80, 80, 120))


func _draw_building() -> void:
	var x0 := 1560.0
	var x1 := WORLD_W
	var roof := 150.0
	# 돔
	draw_circle(Vector2(1780, roof), 56, Color8(170, 174, 206))
	draw_rect(Rect2(1772, roof - 56, 16, 56), Color8(60, 40, 40))
	draw_rect(Rect2(1774, roof - 52, 12, 52), Color8(255, 196, 120))
	# 바깥벽과 지붕
	draw_rect(Rect2(x0, roof, x1 - x0, GROUND - roof), Color8(140, 144, 182))
	draw_rect(Rect2(x0, roof - 4, x1 - x0, 6), Color8(196, 200, 226))
	# 정면 (문, 간판)
	draw_rect(Rect2(1620, GROUND - 46, 26, 46), Color8(110, 78, 60))
	draw_rect(Rect2(1642, GROUND - 24, 2, 2), Color8(255, 220, 140))
	draw_rect(Rect2(1580, roof + 14, 100, 14), Color8(34, 30, 60))
	draw_string(get_theme_default_font(), Vector2(1586, roof + 26), "어린이천문대", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.GOLD)
	# 안쪽 (벽을 잘라 낸 단면)
	draw_rect(Rect2(1700, roof + 8, x1 - 1700 - 8, GROUND - roof - 8), Color8(66, 56, 84))
	draw_rect(Rect2(1700, GROUND - 2, x1 - 1700 - 8, 2), Color8(110, 92, 110))
	for lx in [1800.0, 2000.0, 2200.0, 2400.0]:
		draw_rect(Rect2(lx, roof + 8, 6, 3), Color8(255, 220, 150))
		draw_circle(Vector2(lx + 3, roof + 12), 22, Color(1, 0.85, 0.55, 0.07))
	draw_string(get_theme_default_font(), Vector2(1740, roof + 26), "로비", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	draw_string(get_theme_default_font(), Vector2(2140, roof + 26), "전시실: 옛사람들의 하늘", HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.DIM)
	# 푸코 진자 (옆에서 본 모습)
	var px := 1880.0
	var swing := sin(_t * TAU / 4.0) * 18.0
	draw_line(Vector2(px, roof + 10), Vector2(px + swing, GROUND - 26), Color8(200, 200, 220), 1)
	draw_circle(Vector2(px + swing, GROUND - 24), 5, Color8(230, 190, 90))
	draw_rect(Rect2(px - 40, GROUND - 6, 80, 3), Color8(90, 80, 120))
	# 선생님 책상
	draw_rect(Rect2(1994, GROUND - 22, 34, 4), Color8(120, 84, 60))
	draw_rect(Rect2(1996, GROUND - 18, 2, 18), Color8(80, 56, 44))
	draw_rect(Rect2(2024, GROUND - 18, 2, 18), Color8(80, 56, 44))
	draw_rect(Rect2(2004, GROUND - 25, 10, 3), Color8(244, 240, 228))
	# 누트 여신 그림
	var glow_k := 1.0 if Game.freed.has("keti") else 0.0
	draw_rect(Rect2(2206, 190, 48, 36), Color8(196, 160, 100))
	draw_rect(Rect2(2208, 192, 44, 32), Color8(28, 40, 96))
	draw_arc(Vector2(2230, 222), 18, PI, TAU, 16, Color8(236, 188, 76), 2)
	draw_line(Vector2(2210, 220), Vector2(2250, 220), Color8(90, 150, 80), 1)
	if keti_state() == "dormant":
		draw_rect(Rect2(2228, 206, 4, 8), Color8(244, 240, 228))
	if glow_k > 0.0:
		draw_rect(Rect2(2204, 188, 52, 40), Color(1, 0.84, 0.4, 0.25 + 0.1 * sin(_t * 2.0)), false, 2.0)
	# 천상열차분야지도 (돌판)
	draw_rect(Rect2(2440, 178, 42, GROUND - 178), Color8(110, 108, 118))
	draw_rect(Rect2(2444, 182, 34, 34), Color8(80, 78, 90))
	draw_arc(Vector2(2461, 199), 15, 0, TAU, 20, Color8(170, 168, 180), 1)
	for i in 14:
		draw_rect(Rect2(2448 + (i * 7) % 26, 186 + (i * 11) % 26, 1, 1), Color8(230, 230, 240))
	if Game.freed.has("dolsoe"):
		draw_rect(Rect2(2438, 176, 46, GROUND - 176), Color(1, 0.84, 0.4, 0.25 + 0.1 * sin(_t * 2.0)), false, 2.0)


func _draw_people() -> void:
	var ks := keti_state()
	if ks == "hall" or ks == "yard":
		var feet := Vector2(keti_x, GROUND - 2 + sin(_t * 2.0) * 1.0)
		draw_circle(feet + Vector2(0, -14), 20, Color(0.5, 0.9, 1.0, 0.12))
		Sprites.draw_aura(self, Sprites.KETI, feet, Color(0.5, 0.92, 0.97, 0.8))
		Sprites.draw(self, Sprites.KETI, Sprites.KETI_PAL, feet, player_x < keti_x)
	var ds := dolsoe_state()
	if ds != "dormant" and ds != "freed" and not Game.night.get("sailing", false):
		var feet := Vector2(dolsoe_x, GROUND - (4 if dolsoe_x < 520 else 0))
		Sprites.draw_aura(self, Sprites.DOLSOE, feet, Color(0.5, 0.92, 0.97, 0.8))
		Sprites.draw(self, Sprites.DOLSOE, Sprites.DOLSOE_PAL, feet, player_x < dolsoe_x)
	var bob := 1.0 if int(walk_t * 10.0) % 2 == 1 and y_off == 0.0 else 0.0
	var on_pier := player_x < 520
	var ground_y := GROUND - (4 if on_pier else 0)
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
	var x := clampf(player_x - cam - w / 2.0, 4, Pal.SCREEN.x - w - 4)
	var r := Rect2(x, GROUND - 70, w, 20)
	prompt_rect = r.grow(6)
	draw_rect(r, Pal.PANEL)
	draw_rect(r, Pal.CYAN, false, 1.0)
	draw_string(font, r.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.SMALL, Pal.TEXT)
