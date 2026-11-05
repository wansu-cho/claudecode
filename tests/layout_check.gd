extends SceneTree
## 화면 배치 점검: 모든 퀴즈 단계와 선택지가 상자·화면 안에 들어가는지 확인합니다.
##   godot --path . --script res://tests/layout_check.gd
## 틀린 곳을 모두 출력하고, 없으면 "LAYOUT OK"
var bad := 0
var checked := 0


func _initialize() -> void:
	var story = load("res://scripts/story.gd")
	var quiz = load("res://scripts/ui/quiz_view.gd")
	var specs := []
	for id in story.QUIZ:
		specs.append([id, story.QUIZ[id], false])
	for id in story.PREDICT:
		specs.append(["예측 " + id, story.PREDICT[id], true])
	specs.append(["한 장 정리", story.SUMMARY, false])
	var screen := Rect2(Vector2.ZERO, Vector2(640, 360))
	for sp in specs:
		var spec: Dictionary = sp[1].duplicate()
		spec["predict"] = sp[2]
		var q: Control = quiz.new(spec)
		root.add_child(q)
		for st in spec["steps"].size():
			q._step = st
			q._show_step()
			for k in 3:
				await process_frame
			var box: Rect2 = q.BOX
			for b in q._buttons.get_children():
				checked += 1
				var r: Rect2 = b.get_global_rect()
				if not box.encloses(r):
					bad += 1
					print("퀴즈 넘침: %s 단계 %d  단추 %s  상자 %s  '%s'" % [sp[0], st + 1, r, box, b.text])
			q._tries = 1
			q._msg = "x"
		q.queue_free()
		await process_frame
	# 대사창 선택지: 긴 것, 짧은 것을 차례로 (폭이 남지 않는지)
	var dlg: Control = load("res://scripts/ui/dialogue_box.gd").new()
	root.add_child(dlg)
	await process_frame
	for opts in [["아주 아주 긴 선택지 문장이 하나 있어서 화면 밖으로 나가는지 보기", "짧음"], ["짧음", "그만두기"], story.REALIZE_CHOICES.map(func(c): return c[0])]:
		dlg.choose(opts, "질문")
		for k in 3:
			await process_frame
		for b in dlg._choices.get_children():
			checked += 1
			var r: Rect2 = b.get_global_rect()
			if not screen.encloses(r):
				bad += 1
				print("선택지 넘침: %s '%s'" % [r, b.text])
		dlg._picked.emit(0)
		await process_frame
	print("점검한 단추: %d" % checked)
	print("LAYOUT OK" if bad == 0 else "LAYOUT FAIL: %d" % bad)
	quit()
