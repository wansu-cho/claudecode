class_name Astro
## 실제 하늘 계산입니다.
## 무대: 북위 34°, 동경 127.5°의 남해 섬.
## 날짜: 2141년 12월 13일 밤. 개기월식이 있는 보름날입니다. (게임 안에서는 "2xxx년"으로만 보여 줍니다)
##   2000~2999년 12월 중순에 우리나라에서 처음부터 끝까지 보이는 개기월식 중 하나입니다.
##   월식 시각은 지구 자전이 느려지는 정도(ΔT, 약 5분)를 넣어 계산했습니다.
## 게임 시각(분, 17:00 = 0분)을 넣으면 별의 고도와 방위를 돌려줍니다.

const LAT := 34.0
const LON := 127.5
## 2141-12-13 08:00 UT(= 17:00 KST)의 그리니치 항성시(시)
const GMST_AT_START := 13.478024704529867
const SIDEREAL_RATE := 1.00273790935      # 항성시는 태양시보다 조금 빨리 흐릅니다
## 별 목록은 2000년 기준 좌표입니다. 141.95년 동안의 세차운동(자전축이 팽이처럼 도는 것)을 보정합니다.
const PREC_T := 1.4195                     # (2141.95 − 2000) ÷ 100년

## 12월 13일 무렵 태양의 적경(시)과 적위(도), 그날의 좌표
const SUN_RA := 17.377
const SUN_DEC := -23.14

## 달: 보름달. 적경은 1시간에 약 0.046시간씩 늘어납니다. (그날의 좌표)
const MOON_RA_MID := 5.395
const MOON_RA_RATE := 0.0459
const MOON_DEC := 22.99

## 개기월식 (한국 시각)
##   반영식 시작은 생략. 부분식 시작 21:22 → 개기식 22:20 ~ 23:52 (가장 깊을 때 23:06) → 부분식 끝 00:50
## 달 중심에서 본 지구 본그림자 중심의 위치(각도 분, 동쪽 +, 북쪽 +), 23:06 기준으로 1분마다 변하는 양
const ECL_MID := "23:06"
const ECL_E0 := 0.4
const ECL_E_RATE := -0.5925
const ECL_N0 := 10.2
const ECL_N_RATE := 0.0213
const MOON_R := 16.70                     # 달의 반지름 (각도 분)
const UMBRA_R := 45.83                    # 달 거리에서 지구 본그림자의 반지름 (각도 분)
const PENUMBRA_R := 78.3                  # 반그림자의 반지름 (각도 분)

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
	# 겨울 남쪽 하늘 (돔 망원경)
	"canopus": [6.399, -52.70, -0.7],           # 노인성: 북위 34°에서 겨우 뜨고, 서울에서는 거의 안 보임
	"sirius": [6.752, -16.72, -1.5], "procyon": [7.655, 5.22, 0.4], "aldebaran": [4.599, 16.51, 0.9],
	"betelgeuse": [5.919, 7.41, 0.5], "rigel": [5.242, -8.20, 0.1], "bellatrix": [5.419, 6.35, 1.6], "saiph": [5.796, -9.67, 2.1],
	"alnitak": [5.679, -1.94, 1.7], "alnilam": [5.603, -1.20, 1.7], "mintaka": [5.533, -0.30, 2.2],
}
const BIG_DIPPER := ["dubhe", "merak", "phecda", "megrez", "alioth", "mizar", "alkaid"]
const BIG_DIPPER_LINES := [["dubhe", "merak"], ["merak", "phecda"], ["phecda", "megrez"], ["megrez", "dubhe"], ["megrez", "alioth"], ["alioth", "mizar"], ["mizar", "alkaid"]]
const CASSIOPEIA := ["caph", "schedar", "navi", "ruchbah", "segin"]
const CASSIOPEIA_LINES := [["caph", "schedar"], ["schedar", "navi"], ["navi", "ruchbah"], ["ruchbah", "segin"]]
const ORION_LINES := [["betelgeuse", "bellatrix"], ["betelgeuse", "alnitak"], ["bellatrix", "mintaka"], ["alnitak", "alnilam"], ["alnilam", "mintaka"], ["alnitak", "saiph"], ["mintaka", "rigel"]]
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
	var s: Vector2 = star_radec(id)
	return altaz(s.x, s.y, game_min)


static var _prec := {}

## 세차운동을 보정한 그날의 적경(시)·적위(도)
static func star_radec(id: String) -> Vector2:
	if not _prec.has(id):
		var s: Array = STARS[id]
		_prec[id] = precess(s[0], s[1])
	return _prec[id]


## 2000년 좌표 → 그날의 좌표 (IAU 1976 세차 공식)
static func precess(ra_h: float, dec: float) -> Vector2:
	var t := PREC_T
	var zeta := deg_to_rad((2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600.0)
	var z := deg_to_rad((2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600.0)
	var th := deg_to_rad((2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600.0)
	var a := deg_to_rad(ra_h * 15.0) + zeta
	var d := deg_to_rad(dec)
	var x := cos(th) * cos(d) * cos(a) - sin(th) * sin(d)
	var y := cos(d) * sin(a)
	var zz := sin(th) * cos(d) * cos(a) + cos(th) * sin(d)
	var ra2 := fposmod(rad_to_deg(atan2(y, x) + z) / 15.0, 24.0)
	return Vector2(ra2, rad_to_deg(asin(clampf(zz, -1.0, 1.0))))


## ---- 달과 월식 ----

static func moon_altaz(game_min: float) -> Vector2:
	var hours := (game_min - Game.at(ECL_MID)) / 60.0
	return altaz(MOON_RA_MID + MOON_RA_RATE * hours, MOON_DEC, game_min)


## 달 중심에서 본 본그림자 중심 (각도 분, x = 동쪽, y = 북쪽)
static func shadow_offset(game_min: float) -> Vector2:
	var dm := game_min - Game.at(ECL_MID)
	return Vector2(ECL_E0 + ECL_E_RATE * dm, ECL_N0 + ECL_N_RATE * dm)


## "none"(월식 아님) / "partial"(부분식: 그림자 가장자리가 달 위에 보임) / "total"(개기식)
static func eclipse_phase(game_min: float) -> String:
	var d := shadow_offset(game_min).length()
	if d >= UMBRA_R + MOON_R:
		return "none"
	if d <= UMBRA_R - MOON_R:
		return "total"
	return "partial"


## 달빛의 세기 (0 ~ 1). 달이 낮거나 그림자에 가려지면 약해집니다.
static func moonlight(game_min: float) -> float:
	var up := clampf(moon_altaz(game_min).x / 12.0, 0.0, 1.0)
	var d := shadow_offset(game_min).length()
	var covered := clampf((UMBRA_R + MOON_R - d) / (2.0 * MOON_R), 0.0, 1.0)
	return up * (1.0 - 0.97 * covered)


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
		rng.seed = 2141
		for i in 420:
			var ra := rng.randf() * 24.0
			var dec := rad_to_deg(asin(rng.randf_range(-0.35, 1.0)))
			_field.append([ra, dec, rng.randf_range(0.2, 0.75)])
	return _field


## 밤하늘이 얼마나 어두운지 (0 = 낮, 1 = 완전한 밤)
static func darkness(game_min: float) -> float:
	return clampf((-sun_alt(game_min) - 2.0) / 12.0, 0.0, 1.0)
