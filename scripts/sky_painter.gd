class_name SkyPainter
## 실제 별 위치로 하늘을 그립니다. 바깥 풍경과 망원경 화면이 함께 씁니다.
##
## 투영(하늘의 둥근 면을 화면에 펼치는 방법) 두 가지
##   cyl: 바깥 풍경용. x = cx + (방위 − 바라보는 방위) × k, y = 지평선 y − 고도 × k
##        아주 넓게(200° 넘게) 보여 줄 수 있지만, 높은 하늘의 별자리 모양이 일그러집니다.
##   gno: 망원경용(심사 투영). 카메라로 찍은 것처럼 보입니다.
##        하늘의 큰 원(두 별을 잇는 가장 짧은 길)이 화면에서 곧은 선이 되므로,
##        '두 별을 이어 늘이기'로 북극성을 찾는 방법이 실제 하늘과 같게 됩니다.

const NIGHT_TOP := Color8(5, 6, 18)
const NIGHT_HOR := Color8(44, 28, 74)
const DAY_TOP := Color8(84, 132, 204)
const DAY_HOR := Color8(176, 204, 236)
const DUSK := Color8(236, 132, 112)
const RIDGE := Color8(14, 12, 26)
const MOON_SKY := Color8(34, 44, 86)
const OFF := Vector2(-9999, -9999)


static func cyl(cx: float, hy: float, k: float, center_az := 0.0) -> Dictionary:
	return {"type": "cyl", "cx": cx, "hy": hy, "k": k, "az": center_az}


## 바라보는 방향(방위, 고도)이 화면의 center에 오고, f = 화면 픽셀 ÷ 라디안
static func gno(center_az: float, center_alt: float, f: float, center: Vector2) -> Dictionary:
	var a := deg_to_rad(center_az)
	var h := deg_to_rad(center_alt)
	var c := Vector3(cos(h) * sin(a), cos(h) * cos(a), sin(h))     # x 동, y 북, z 위
	var right := Vector3(cos(a), -sin(a), 0.0)
	var up := right.cross(c)
	return {"type": "gno", "c": c, "right": right, "up": up, "f": f, "center": center, "az": center_az}


## 화면 1픽셀이 몇 도인지의 역수 (도 → 픽셀, 화면 가운데 기준)
static func px_per_deg(pr: Dictionary) -> float:
	return pr["k"] if pr["type"] == "cyl" else pr["f"] * PI / 180.0


## (고도, 방위) → 화면 위치. 등 뒤에 있으면 OFF
static func project(aa: Vector2, pr: Dictionary) -> Vector2:
	if pr["type"] == "cyl":
		# 사인 곡선 투영: 높이 뜰수록 방위 간격을 cos(고도)만큼 좁힘
		# (원통 투영은 천정 근처에서 방위가 크게 벌어져 별이 화면을 빠르게 가로지름)
		var x: float = wrapf(aa.y - pr["az"], -180.0, 180.0) * pr["k"] * cos(deg_to_rad(clampf(aa.x, -90.0, 90.0)))
		return Vector2(pr["cx"] + x, pr["hy"] - aa.x * pr["k"])
	var h := deg_to_rad(aa.x)
	var a := deg_to_rad(aa.y)
	var v := Vector3(cos(h) * sin(a), cos(h) * cos(a), sin(h))
	var d: float = v.dot(pr["c"])
	if d < 0.1:
		return OFF
	return pr["center"] + Vector2(v.dot(pr["right"]), -v.dot(pr["up"])) * (pr["f"] / d)


## 지평선의 화면 높이 (화면 가운데에서)
static func horizon_y(pr: Dictionary) -> float:
	if pr["type"] == "cyl":
		return pr["hy"]
	return project(Vector2(0.0, pr["az"]), pr).y


## 하늘을 그리고, 보이는 이름 있는 별의 화면 위치를 돌려줍니다.
static func draw(ci: CanvasItem, m: float, size: Vector2, pr: Dictionary) -> Dictionary:
	var hy := horizon_y(pr)
	var k := px_per_deg(pr)
	var dark := Astro.darkness(m)
	var sun := Astro.sun_alt(m)
	var dusk := clampf(1.0 - absf(sun + 5.0) / 9.0, 0.0, 1.0)
	# 보름달 빛: 하늘이 조금 밝아지고 어두운 별이 덜 보입니다. (개기식 동안에는 다시 어두워짐)
	var moon := Astro.moonlight(m) * dark

	# 하늘 그라데이션 (2픽셀 띠 + 체크무늬 디더링)
	var y := 0
	while y < int(hy) + 2:
		var t := clampf(float(y) / hy, 0.0, 1.0)
		var night := NIGHT_TOP.lerp(NIGHT_HOR, t * t)
		var day := DAY_TOP.lerp(DAY_HOR, t)
		var c := day.lerp(night, dark)
		c = c.lerp(DUSK, dusk * t * t * 0.8)
		c = c.lerp(MOON_SKY, moon * 0.35)
		ci.draw_rect(Rect2(0, y, size.x, 2), c)
		y += 2

	var out := {}
	if dark > 0.05:
		for s in Astro.field():
			var aa := Astro.altaz(s[0], s[1], m)
			if aa.x <= 0.0 or Astro.hidden(aa):
				continue
			var p := project(aa, pr)
			if p.x < 0 or p.x >= size.x or p.y < 0:
				continue
			ci.draw_rect(Rect2(p.floor(), Vector2.ONE), Color(Pal.STAR, s[2] * dark * (1.0 - 0.7 * moon) * clampf(aa.x / 6.0, 0.2, 1.0)))
		for id in Astro.STARS:
			var aa := Astro.star_altaz(id, m)
			if aa.x <= 0.0 or Astro.hidden(aa):
				continue
			var p := project(aa, pr)
			if p.x < -4 or p.x > size.x + 4 or p.y < -4:
				continue
			out[id] = p
			var mag: float = Astro.STARS[id][2]
			# 지평선 가까운 별은 공기층을 많이 지나 붉고 어둡게 보입니다.
			var low := clampf(1.0 - aa.x / 8.0, 0.0, 1.0)
			var col := Color(Pal.STAR.lerp(Color(1.0, 0.55, 0.35), low * 0.8), dark * (1.0 - low * 0.45))
			if mag < 1.0:
				Pal.sparkle(ci, p, 3, col)
			elif mag < 2.0:
				Pal.sparkle(ci, p, 1, col)
			elif mag < 3.0:
				ci.draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
			else:
				ci.draw_rect(Rect2(p.floor(), Vector2.ONE), Color(col, 0.8 * dark))

	_draw_moon(ci, m, size, pr)

	# 북북동쪽 산 능선 (바라보는 방향 앞쪽 180°만)
	var pts := PackedVector2Array()
	var span := 180.0 if pr["type"] == "cyl" else 80.0
	var az := -span
	while az <= span:
		var a2 := wrapf(az + pr["az"], -180.0, 180.0)
		var p := project(Vector2(Astro.ridge_alt(a2), a2), pr)
		if p != OFF:
			pts.append(Vector2(clampf(p.x, -40.0, size.x + 40.0), p.y))
		az += 2.0
	pts.append(Vector2(pts[pts.size() - 1].x, size.y + 2))
	pts.append(Vector2(pts[0].x, size.y + 2))
	ci.draw_colored_polygon(pts, RIDGE.lerp(Color8(70, 90, 120), 1.0 - dark))
	return out


## 보름달 (화면 안에 있을 때만). 월식 중에는 어두워지고, 개기식 동안에는 붉은 구릿빛이 됩니다.
static func _draw_moon(ci: CanvasItem, m: float, size: Vector2, pr: Dictionary) -> void:
	var aa := Astro.moon_altaz(m)
	if aa.x <= -1.0 or Astro.hidden(aa):
		return
	var p := project(aa, pr)
	var r := maxf(3.0, px_per_deg(pr) * 0.6)
	if p.x < -r or p.x > size.x + r or p.y < -r or p.y > horizon_y(pr):
		return
	var col := moon_color(m)
	ci.draw_circle(p, r * 2.4, Color(col, 0.12))
	ci.draw_circle(p, r, col)


static func moon_color(m: float) -> Color:
	var bright := Color8(244, 238, 214)
	match Astro.eclipse_phase(m):
		"total":
			return Color8(150, 62, 40)
		"partial":
			var d := Astro.shadow_offset(m).length()
			var covered := clampf((Astro.UMBRA_R + Astro.MOON_R - d) / (2.0 * Astro.MOON_R), 0.0, 1.0)
			return bright.lerp(Color8(150, 62, 40), covered * 0.8)
	return bright
