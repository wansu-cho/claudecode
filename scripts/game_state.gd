extends Node
## 한 판의 게임 상태를 기억하는 곳입니다. (어느 화면에서든 GameState로 부를 수 있습니다)
##
## - 몇 명이 참가했는지
## - 어느 단계를 몇 번 대원이 맡는지 (0번 = 전원 참여)
## - 반 전체가 함께 모으는 '탐사 데이터' 양

signal data_changed(value: int)

const MIN_PLAYERS := 5
const MAX_PLAYERS := 10

## 인원이 적을 때 전원 참여로 바꿀 단계의 순서입니다. (고르기 문제 형태부터)
const GROUP_PRIORITY := [5, 8, 3, 7, 4]

## 탐사 데이터를 얼마나 올릴지 정합니다. 데이터는 늘기만 하고 줄지 않습니다.
const GAIN_SUCCESS := 10     # 대원이 스스로 해냄
const GAIN_ASSISTED := 6     # 시간이 다 되어 본부 지원으로 완료
const GAIN_GROUP := 8        # 전원 참여 단계 완료
const GAIN_BONUS := 3        # 진행자가 주는 예측 보너스 (B 키)

var player_count := 10
var assignments := {}   # 단계 번호 -> 대원 번호 (0이면 전원 참여)
var data := 0


func new_game(count: int) -> void:
	player_count = clampi(count, MIN_PLAYERS, MAX_PLAYERS)
	data = 0
	data_changed.emit(data)
	_assign_stages()


func _assign_stages() -> void:
	assignments.clear()
	var group_count := StageData.STAGES.size() - player_count
	var group_ids: Array = GROUP_PRIORITY.slice(0, group_count)

	# 대원 번호를 무작위로 섞어서, 개인 단계에 순서대로 배정합니다.
	var players := range(1, player_count + 1)
	players.shuffle()
	var next := 0
	for s in StageData.STAGES:
		var id: int = s["id"]
		if id in group_ids:
			assignments[id] = 0
		else:
			assignments[id] = players[next]
			next += 1


func is_group(stage_id: int) -> bool:
	return assignments.get(stage_id, 0) == 0


## 이 단계 다음에 플레이할 대원 번호 (없으면 0)
func next_player_after(stage_id: int) -> int:
	for s in StageData.STAGES:
		var id: int = s["id"]
		if id > stage_id and not is_group(id):
			return assignments[id]
	return 0


func add_data(amount: int) -> void:
	data = mini(data + amount, 100)
	data_changed.emit(data)
