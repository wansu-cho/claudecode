extends SceneTree
## 관측 화면과 퀴즈 화면을 열어 찍습니다. (그림 확인용)
##   godot --path . --script res://tests/view_shots.gd -- [사진 폴더]
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var game := root.get_node("Game")
	game.night["pend"] = []
	var story = load("res://scripts/story.gd")
	var quiz = load("res://scripts/ui/quiz_view.gd")
	var shots := [["pendulum", load("res://scripts/views/pendulum_view.gd").new()], ["orrery", load("res://scripts/views/orrery_view.gd").new()]]
	for id in ["sunset", "pendulum", "ship_horizon", "eclipse_round"]:
		shots.append(["quiz_" + id, quiz.new(story.QUIZ[id])])
	var p: Dictionary = story.PREDICT["telescope"].duplicate()
	p["predict"] = true
	shots.append(["quiz_predict", quiz.new(p)])
	for spec in shots:
		var v: Control = spec[1]
		root.add_child(v)
		for i in 5:
			await process_frame
		root.get_texture().get_image().save_png(out + "/view_%s.png" % spec[0])
		v.queue_free()
		await process_frame
	quit()
