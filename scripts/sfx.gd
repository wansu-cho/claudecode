extends Node
## 소리 (전역: Sfx.play("aha")). 소리 파일은 tools/make_sounds.py로 만든 assets/sounds/*.wav
## 밤바다 배경음은 Sfx.ambience(true/false)로 켜고 끕니다.

const NAMES := ["step", "click", "aha", "correct", "wrong", "shutter", "page", "wake", "shelf", "rewind"]
var _sounds := {}
var _players: Array = []
var _next := 0
var _amb: AudioStreamPlayer


func _ready() -> void:
	for n in NAMES:
		_sounds[n] = load("res://assets/sounds/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_amb = AudioStreamPlayer.new()
	var sea: AudioStreamWAV = load("res://assets/sounds/night_sea.wav")
	sea.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sea.loop_end = sea.data.size() / 2                 # 16비트 모노: 2바이트 = 1샘플
	_amb.stream = sea
	_amb.volume_db = -16.0
	add_child(_amb)


func play(name: String, volume_db := 0.0) -> void:
	if not _sounds.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.volume_db = volume_db
	p.play()


func ambience(on: bool) -> void:
	if on and not _amb.playing:
		_amb.play()
	elif not on and _amb.playing:
		_amb.stop()
