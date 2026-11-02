extends SceneTree
## 좌우 뒤집기 확인: 같은 발 위치에 오른쪽/왼쪽 보는 그림을 그려 몸 가운데가 같은지 봅니다.
class Painter extends Node2D:
	var flip := false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 400, 300), Color.BLACK)
		SheetSprite.named("hero").draw(self, "idle", 0, Vector2(200, 250), flip, 160.0)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for f in [false, true]:
		var p := Painter.new()
		p.flip = f
		root.add_child(p)
		await process_frame
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(out + "/flip_%s.png" % str(f))
		p.queue_free()
		await process_frame
	quit()
