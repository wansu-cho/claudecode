extends Node
## 게임 상태입니다. (어디서든 Game으로 부를 수 있습니다)
##
## - 지금 시각(밤이 시작된 뒤 몇 분)과 몇 번째 밤인지
## - 루프가 돌아도 남는 것: 관측 일지, 아침으로 돌아간 사람들
## - 루프마다 지워지는 것: 이번 밤의 기록(night)

signal fact_added(id: String)

const NIGHT_LEN := 840.0          # 17:30 ~ 07:30, 14시간
const START_CLOCK := 17 * 60 + 30
const SEC_PER_MIN := 1.0 / 3.0    # 실제 1/3초 = 게임 1분 (한 밤 = 약 4분 40초)
const SAVE_PATH := "user://save.json"

var minutes := 0.0
var loop := 1
var running := false
var facts := {}                   # 알아낸 사실 id -> true
var freed := {}                   # 아침으로 돌아간 사람 id -> true
var night := {}                   # 이번 밤에만 쓰는 기록
var double_jump := false          # 나중에 퀘스트로 얻는 두 번 점프
var _freeze := 0


func _process(delta: float) -> void:
	if running and _freeze == 0:
		minutes = minf(minutes + delta / SEC_PER_MIN, NIGHT_LEN)


## 대화, 일지를 보는 동안에는 시간이 멈춥니다.
func freeze() -> void:
	_freeze += 1


func unfreeze() -> void:
	_freeze = maxi(_freeze - 1, 0)


func clock(m := -1.0) -> String:
	var total := int(START_CLOCK + (minutes if m < 0.0 else m)) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


## "HH:MM"을 게임 분으로 (17:30 = 0)
static func at(hhmm: String) -> float:
	var p := hhmm.split(":")
	var t := int(p[0]) * 60 + int(p[1]) - START_CLOCK
	if t < 0:
		t += 24 * 60
	return float(t)


func has(id: String) -> bool:
	return facts.has(id)


func add_fact(id: String) -> bool:
	if facts.has(id):
		return false
	facts[id] = true
	save()
	fact_added.emit(id)
	return true


func free_person(id: String) -> void:
	freed[id] = true
	save()


func pieces() -> int:
	return freed.size()


func start_night() -> void:
	minutes = 0.0
	night = {"pend": [], "photos": []}
	_freeze = 0
	running = true


func next_loop() -> void:
	loop += 1
	save()
	start_night()


func new_game() -> void:
	loop = 1
	facts = {}
	freed = {}
	double_jump = false
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"loop": loop, "facts": facts.keys(), "freed": freed.keys(), "double_jump": double_jump}))


func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	loop = int(data.get("loop", 1))
	facts = {}
	for id in data.get("facts", []):
		facts[id] = true
	freed = {}
	for id in data.get("freed", []):
		freed[id] = true
	double_jump = bool(data.get("double_jump", false))
	return true
