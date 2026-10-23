class_name Sprites
## 시제품용으로 대충 그린 캐릭터 픽셀 그림입니다. (나중에 제미나이 그림으로 바꿉니다)
## 글자 하나 = 픽셀 하나. "."은 빈칸입니다.

const HERO := [
	"......OWWO......",
	".....OWwwWO.....",
	"....OOHHHHOO....",
	"...OHHHLHHHHO...",
	"..OHHHHHHHHHHO..",
	"..OhhhhhhhhhhO..",
	"..OKKKKKKKKKKO..",
	".OKKKSSSSSKKKKO.",
	".OKSSSSSSSSSSKO.",
	".OKSSESSSSESSKO.",
	".OKSSESSSSESSKO.",
	".OKSCSSSSSSCSKO.",
	"..OSSSSSmSSSSO..",
	"...OssSSSSssO...",
	"...OFFFFFFFFO...",
	"..OJFffffffFJO..",
	".OJJJJFFJJJJLJO.",
	".OJjJJJFJJJJJjO.",
	"OSjJJJJJJJJJjSRO",
	".OjjJJJJJJJjjOO.",
	"..OjjjjjjjjjO...",
	"..OPPPPpPPPPO...",
	"..OPPPOOOPPPO...",
	"..OPPO...OPPO...",
	".OBBBO...OBBBO..",
	".OOOO.....OOOO..",
]
const HERO_PAL := {
	"O": Color8(27, 22, 48), "W": Color8(242, 238, 246), "w": Color8(190, 184, 214), "H": Color8(170, 74, 64),
	"h": Color8(120, 48, 48), "L": Color8(214, 120, 100), "K": Color8(40, 30, 40), "S": Color8(248, 208, 176),
	"s": Color8(224, 168, 138), "E": Color8(27, 22, 48), "C": Color8(240, 138, 138), "m": Color8(190, 110, 110),
	"F": Color8(214, 150, 60), "f": Color8(160, 104, 40), "J": Color8(160, 60, 56), "j": Color8(116, 40, 44),
	"P": Color8(50, 54, 90), "p": Color8(36, 38, 66), "B": Color8(92, 58, 46), "R": Color8(255, 60, 60),
}

const KETI := [
	"....OOOOOOOO....",
	"...ONNNNNNNNO...",
	"..ONNnnNNNNNNO..",
	"..ONGGGGGGGGNO..",
	".ONNNNNNNNNNNNO.",
	".ONNNNNNNNNNNNO.",
	".ONNDDDDDDDDNNO.",
	".ONNDEDDDDEDNNO.",
	".ONNDEDDDDEDNNO.",
	".ONNDDDDDDDDNNO.",
	".ONNNdDDDDdNNNO.",
	".ONNNOdDDdONNNO.",
	"..OOO.OddO.OOO..",
	"....OAGAGAGO....",
	"...OLGAGAGALO...",
	"..ODLLLLLLLLDO..",
	"..ODLLLLLLLLDO..",
	"..OdLLLLlLLLdO..",
	"...OLLLLlLLLO...",
	"...OLLLLlLLLO...",
	"...OLLLlllLLO...",
	"..OLLLLlllLLLO..",
	"..OllLLlllLLlO..",
	"...OOOOOOOOOO...",
	"....ODDO.ODDO...",
	"....OGGO.OGGO...",
]
const KETI_PAL := {
	"O": Color8(27, 22, 48), "N": Color8(24, 20, 36), "n": Color8(80, 76, 120), "G": Color8(236, 188, 76),
	"D": Color8(186, 122, 80), "d": Color8(142, 88, 58), "E": Color8(22, 18, 34), "A": Color8(58, 98, 204),
	"L": Color8(244, 240, 228), "l": Color8(196, 192, 220),
}

const DOLSOE := [
	".......OO.......",
	"......OKKO......",
	".....OKKKKO.....",
	"...OOOOOOOOOO...",
	"..OMMMMMMMMMMO..",
	"..OKKKKKKKKKKO..",
	"..OKSSSSSSSSKO..",
	"..OSSESSSSESSO..",
	"..OSSESSSSESSO..",
	"..OSCSSSSSSCSO..",
	"..OSSSSmmSSSSO..",
	"...OSSSSSSSSO...",
	"....OssssssO....",
	"...OYYYTTYYYO...",
	"..OYYYYTTYYYYO..",
	".OSYYYYTTYYYYSO.",
	".OSYyYYTTYYyYSO.",
	".OSYyYYYYYYyYSO.",
	"..OYyyyyyyyyYO..",
	"..ObbbbbbbbbbO..",
	"..OGGGGGGGGGGO..",
	"..OGGGGOOGGGGO..",
	"..OggGO..OGggO..",
	"..OwwwO..OwwwO..",
	"..OGGGO..OGGGO..",
	".OZZZZO..OZZZZO.",
	".OOOOO....OOOOO.",
]
const DOLSOE_PAL := {
	"O": Color8(27, 22, 48), "K": Color8(30, 24, 30), "M": Color8(70, 60, 60), "S": Color8(214, 160, 116),
	"s": Color8(180, 126, 90), "E": Color8(27, 22, 48), "C": Color8(220, 120, 100), "m": Color8(150, 90, 70),
	"Y": Color8(222, 214, 190), "y": Color8(176, 168, 148), "T": Color8(150, 110, 70), "b": Color8(120, 70, 50),
	"G": Color8(110, 110, 120), "g": Color8(80, 80, 90), "w": Color8(236, 232, 220), "Z": Color8(190, 160, 90),
}


## 발밑 가운데 기준으로 그립니다.
static func draw(ci: CanvasItem, rows: Array, pal: Dictionary, feet: Vector2, flip := false, alpha := 1.0) -> void:
	var h := rows.size()
	var w: int = rows[0].length()
	var origin := (feet - Vector2(w / 2.0, h)).floor()
	for j in h:
		var row: String = rows[j]
		for i in row.length():
			var ch := row[i]
			if pal.has(ch):
				var c: Color = pal[ch]
				c.a *= alpha
				var x := (w - 1 - i) if flip else i
				ci.draw_rect(Rect2(origin + Vector2(x, j), Vector2.ONE), c)


## 바깥 테두리에 빛나는 선을 그립니다 (유물에서 깨어난 손님 표시)
static func draw_aura(ci: CanvasItem, rows: Array, feet: Vector2, color: Color) -> void:
	var h := rows.size()
	var w: int = rows[0].length()
	var origin := (feet - Vector2(w / 2.0, h)).floor()
	for j in h:
		for i in w:
			if _filled(rows, i, j):
				continue
			if _filled(rows, i - 1, j) or _filled(rows, i + 1, j) or _filled(rows, i, j - 1) or _filled(rows, i, j + 1):
				ci.draw_rect(Rect2(origin + Vector2(i, j), Vector2.ONE), color)


static func _filled(rows: Array, i: int, j: int) -> bool:
	if j < 0 or j >= rows.size():
		return false
	var row: String = rows[j]
	return i >= 0 and i < row.length() and row[i] != "."
