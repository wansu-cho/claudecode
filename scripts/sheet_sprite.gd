class_name SheetSprite
## 제미나이로 그린 캐릭터 시트(tools/sprite_sheet.py로 정리한 것)를 그립니다.
##   var s := SheetSprite.named("hero")
##   s.draw(ci, "walk", s.frame_at("walk", t), feet, flip, 40.0)
## 원본 그림을 줄이지 않고 담아 두었다가, 화면 해상도에 맞춰 그립니다. (게임 좌표로 키 height칸)

## 대사창 얼굴 그림을 보여 줄 사람: 말하는 사람 이름 -> 시트 이름
const SPEAKERS := {"케티": "keti", "테오": "teo", "이나": "ina", "돌쇠": "dolsoe", "보리": "bori"}

static var _cache := {}

var tex: Texture2D
var meta: Dictionary


static func named(name: String) -> SheetSprite:
	if not _cache.has(name):
		var s := SheetSprite.new()
		s.tex = load("res://assets/sprites/%s.png" % name)
		s.meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % name))
		_cache[name] = s
	return _cache[name]


static func for_speaker(who: String) -> SheetSprite:
	return named(SPEAKERS[who]) if SPEAKERS.has(who) else null


func has_anim(anim: String) -> bool:
	return meta["anims"].has(anim)


func count(anim: String) -> int:
	return meta["anims"][anim]["frames"].size()


## t초 동안 반복 재생했을 때의 칸 번호
func frame_at(anim: String, t: float) -> int:
	var a: Dictionary = meta["anims"][anim]
	var n: int = a["frames"].size()
	return int(t * float(a["fps"])) % n if a["fps"] > 0 else 0


func region(anim: String, i: int) -> Rect2:
	var idx: int = meta["anims"][anim]["frames"][clampi(i, 0, count(anim) - 1)]
	var fw: float = meta["frame_w"]
	var fh: float = meta["frame_h"]
	var cols: int = meta["cols"]
	return Rect2((idx % cols) * fw, (idx / cols) * fh, fw, fh)


## feet: 발끝 가운데 (게임 좌표), height: 아이 캐릭터의 키 (게임 좌표). 키가 큰 사람은 시트의 height 배율만큼 크게
func draw(ci: CanvasItem, anim: String, i: int, feet: Vector2, flip: bool, height: float, tint := Color.WHITE) -> void:
	var k: float = height * float(meta.get("height", 1.0)) / float(meta["body_h"])
	var size := Vector2(meta["frame_w"], meta["frame_h"]) * k
	var ax: float = meta["anchor"][0] * k
	var ay: float = meta["anchor"][1] * k
	var pos := Vector2(feet.x - (size.x - ax if flip else ax), feet.y - ay)
	var rect := Rect2(pos, size)
	if flip:
		rect = Rect2(pos + Vector2(size.x, 0), Vector2(-size.x, size.y))
	ci.draw_texture_rect_region(tex, rect, region(anim, i), tint)


## 대사창용 얼굴 그림 (face 동작의 i번째 칸)
func portrait(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region("face", i)
	return at
