class_name Astro
## 실제 하늘 계산입니다.
## 무대: 북위 34°, 동경 127.5°의 남해 섬. 날짜: 2026년 12월 20일 밤.
## 게임 시각(분, 17:30 = 0분)을 넣으면 별의 고도와 방위를 돌려줍니다.

const LAT := 34.0
const LON := 127.5
## 2026-12-20 08:30 UT(= 17:30 KST)의 그리니치 항성시(시)
const GMST_AT_START := 14.42956240318017
const SIDEREAL_RATE := 1.00273790935      # 항성시는 태양시보다 조금 빨리 흐릅니다

## 12월 20일 무렵 태양의 적경(시)과 적위(도)
const SUN_RA := 17.95
const SUN_DEC := -23.43

## 별 목록: 이름 -> [적경(시), 적위(도), 밝기(등급)]
const STARS := {
	"polaris": [2.530, 89.26, 2.0],
	"kochab": [14.845, 74.16, 2.1], "pherkad": [15.345, 71.83, 3.0],
	"yildun": [17.537, 86.59, 4.4], "eps_umi": [16.766, 82.04, 4.2], "zeta_umi": [15.734, 77.79, 4.3], "eta_umi": [16.292, 75.76, 5.0],
	"dubhe": [11.062, 61.75, 1.8], "merak": [11.030, 56.38, 2.4], "phecda": [11.897, 53.69, 2.4], "megrez": [12.257, 57.03, 3.3],
	"alioth": [12.900, 55.96, 1.8], "mizar": [13.398, 54.93, 2.2], "alkaid": [13.792, 49.31, 1.9],
	"caph": [0.153, 59.15, 2.3], "schedar": [0.675, 56.54, 2.2], "navi": [0.945, 60.72, 2.2], "ruchbah": [1.430, 60.24, 2.7], "segin": [1.907, 63.67, 3.4],
	"capella": [5.278, 46.0, 0.1], "deneb": [20.690, 45.28, 1.3], "vega": [18.616, 38.78, 0.0], "mirfak": [3.405, 49.86, 1.8],
	"castor": [7.577, 31.89, 1.6], "pollux": [7.755, 28.03, 1.1], "algol": [3.136, 40.96, 2.1], "alderamin": [21.31, 62.59, 2.5],
	"almach": [2.065, 42.33, 2.1], "eltanin": [17.943, 51.49, 2.2], "menkalinan": [5.992, 44.95, 1.9],
}
const BIG_DIPPER := ["dubhe", "merak", "phecda", "megrez", "alioth", "mizar", "alkaid"]
const BIG_DIPPER_LINES := [["dubhe", "merak"], ["merak", "phecda"], ["phecda", "megrez"], ["megrez", "dubhe"], ["megrez", "alioth"], ["alioth", "mizar"], ["mizar", "alkaid"]]
const CASSIOPEIA := ["caph", "schedar", "navi", "ruchbah", "segin"]
const CASSIOPEIA_LINES := [["caph", "schedar"], ["schedar", "navi"], ["navi", "ruchbah"], ["ruchbah", "segin"]]
const LITTLE_DIPPER := ["polaris", "kochab", "pherkad", "yildun", "eps_umi", "zeta_umi", "eta_umi"]

static var _field: Array = []


## 게임 시각(분) -> 지방 항성시(시)
static func lst(game_min: float) -> float:
	return fposmod(GMST_AT_START + LON / 15.0 + game_min / 60.0 * SIDEREAL_RATE, 24.0)


## 적경·적위 -> Vector2(고도, 방위). 방위는 북쪽 0°, 동쪽이 +.
static func altaz(ra_h: float, dec: float, game_min: float) -> Vector2:
	var h := deg_to_rad((lst(game_min) - ra_h) * 15.0)
	var d := deg_to_rad(dec)
	var l := deg_to_rad(LAT)
	var alt := asin(sin(d) * sin(l) + cos(d) * cos(l) * cos(h))
	var az := atan2(-cos(d) * sin(h), sin(d) * cos(l) - cos(d) * sin(l) * cos(h))
	return Vector2(rad_to_deg(alt), rad_to_deg(az))


static func star_altaz(id: String, game_min: float) -> Vector2:
	var s: Array = STARS[id]
	return altaz(s[0], s[1], game_min)


static func sun_alt(game_min: float) -> float:
	return altaz(SUN_RA, SUN_DEC, game_min).x


## 북북동쪽 산 능선의 높이(도). 초저녁 북두칠성이 이 산 뒤에 숨습니다.
static func ridge_alt(az: float) -> float:
	var h := 1.0
	if az > -6.0 and az < 52.0:
		var t := (az + 6.0) / 58.0
		h += 12.0 * pow(sin(PI * t), 0.7) + 1.5 * sin(az * 0.6)
	return h


static func hidden(altaz_v: Vector2) -> bool:
	return altaz_v.x < ridge_alt(altaz_v.y)


## 어두운 배경 별 (적경, 적위, 밝기) — 매번 같은 하늘이 나오도록 고정된 씨앗을 씁니다.
static func field() -> Array:
	if _field.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026
		for i in 420:
			var ra := rng.randf() * 24.0
			var dec := rad_to_deg(asin(rng.randf_range(-0.35, 1.0)))
			_field.append([ra, dec, rng.randf_range(0.2, 0.75)])
	return _field


## 밤하늘이 얼마나 어두운지 (0 = 낮, 1 = 완전한 밤)
static func darkness(game_min: float) -> float:
	return clampf((-sun_alt(game_min) - 2.0) / 12.0, 0.0, 1.0)
