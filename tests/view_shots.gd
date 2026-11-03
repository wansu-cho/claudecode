extends SceneTree
## 관측 화면 몇 개를 열어 화면을 찍습니다. (그림 확인용)
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for spec in [["pendulum", "res://scripts/views/pendulum_view.gd"], ["orrery", "res://scripts/views/orrery_view.gd"]]:
		root.get_node("Game").night["pend"] = []
		var v: Control = load(spec[1]).new()
		root.add_child(v)
		for i in 5:
			await process_frame
		root.get_texture().get_image().save_png(out + "/view_%s.png" % spec[0])
		v.queue_free()
		await process_frame
	quit()
