class_name SkyPainter
## 실제 별 위치로 북쪽 하늘을 그립니다. 바깥 풍경과 망원경 화면이 함께 씁니다.
## 화면 좌표: x = cx + (방위 − 바라보는 방위) × k, y = 지평선 y − 고도 × k
## 바라보는 방위: 0 = 북쪽 (기본), 180 = 남쪽 (돔 망원경)

const NIGHT_TOP := Color8(5, 6, 18)
const NIGHT_HOR := Color8(44, 28, 74)
const DAY_TOP := Color8(84, 132, 204)
const DAY_HOR := Color8(176, 204, 236)
const DUSK := Color8(236, 132, 112)
const RIDGE := Color8(14, 12, 26)


static func to_screen(aa: Vector2, cx: float, hy: float, k: float, center_az := 0.0) -> Vector2:
	return Vector2(cx + wrapf(aa.y - center_az, -180.0, 180.0) * k, hy - aa.x * k)


## 하늘을 그리고, 보이는 이름 있는 별의 화면 위치를 돌려줍니다.
static func draw(ci: CanvasItem, m: float, size: Vector2, hy: float, k: float, cx: float, center_az := 0.0) -> Dictionary:
	var dark := Astro.darkness(m)
	var sun := Astro.sun_alt(m)
	var dusk := clampf(1.0 - absf(sun + 5.0) / 9.0, 0.0, 1.0)

	# 하늘 그라데이션 (2픽셀 띠 + 체크무늬 디더링)
	var y := 0
	while y < int(hy) + 2:
		var t := clampf(float(y) / hy, 0.0, 1.0)
		var night := NIGHT_TOP.lerp(NIGHT_HOR, t * t)
		var day := DAY_TOP.lerp(DAY_HOR, t)
		var c := day.lerp(night, dark)
		c = c.lerp(DUSK, dusk * t * t * 0.8)
		ci.draw_rect(Rect2(0, y, size.x, 2), c)
		y += 2

	var out := {}
	if dark > 0.05:
		for s in Astro.field():
			var aa := Astro.altaz(s[0], s[1], m)
			if aa.x <= 0.0 or Astro.hidden(aa):
				continue
			var p := to_screen(aa, cx, hy, k, center_az)
			if p.x < 0 or p.x >= size.x or p.y < 0:
				continue
			ci.draw_rect(Rect2(p.floor(), Vector2.ONE), Color(Pal.STAR, s[2] * dark * clampf(aa.x / 6.0, 0.2, 1.0)))
		for id in Astro.STARS:
			var aa := Astro.star_altaz(id, m)
			if aa.x <= 0.0 or Astro.hidden(aa):
				continue
			var p := to_screen(aa, cx, hy, k, center_az)
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

	# 북북동쪽 산 능선
	var pts := PackedVector2Array()
	var az := -180.0
	while az <= 180.0:
		pts.append(Vector2(cx + az * k, hy - Astro.ridge_alt(wrapf(az + center_az, -180.0, 180.0)) * k))
		az += 2.0
	pts.append(Vector2(cx + 180.0 * k, hy + 2))
	pts.append(Vector2(cx - 180.0 * k, hy + 2))
	ci.draw_colored_polygon(pts, RIDGE.lerp(Color8(70, 90, 120), 1.0 - dark))
	return out
