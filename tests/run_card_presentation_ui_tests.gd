extends SceneTree
## 卡牌通知与详情的独立窗口验收；不写玩家存档。

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1440, 960)
	var game: VillageGame = MAIN_SCENE.instantiate() as VillageGame
	game.state.persistence_enabled = false
	game.state.save_path = "res://test-results/card_presentation_roundtrip.tres"
	root.add_child(game)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
	await process_frame
	await process_frame
	await CardUiRegression.run(
		self, game.get_node("Dashboard") as VillageDashboard, _check, _capture
	)
	await CardInspectionUiRegression.run(self, game, _check, _capture)
	await CardAcquisitionUiRegression.run(self, game, _check, _capture)
	await _test_notice_animation(game)
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	dashboard.overlay.show_card(game.state.hand[0].uid)
	await _capture("ui_card_survey")
	dashboard.overlay.close_modal()
	print("CARD PRESENTATION UI RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw()
	var image: Image = root.get_texture().get_image()
	_check(image.save_png("res://test-results/" + name + ".png") == OK, "Saved " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("CARD PRESENTATION UI FAIL: " + message)


func _test_notice_animation(game: VillageGame) -> void:
	var notice: CardAcquisitionNotice = (
		game.get_node("Dashboard/%CardAcquisition") as CardAcquisitionNotice
	)
	var timer: Timer = notice.get_node("Timer") as Timer
	_move_pointer(Vector2(5, 5))
	game.state.cards_acquired.emit(PackedInt32Array([game.state.hand[1].uid]))
	await create_timer(0.3).timeout
	_check(is_equal_approx(notice.modulate.a, 1.0), "Acquisition notice fades in fully")
	_move_pointer(notice.get_global_rect().position + Vector2(5, 5))
	await process_frame
	_check(timer.is_stopped(), "Actual pointer hover keeps the notification visible")
	_move_pointer(Vector2(5, 5))
	await process_frame
	_check(not timer.is_stopped(), "Leaving the notification restarts its display timer")
	timer.start(0.05)
	await create_timer(0.15).timeout
	_check(notice.modulate.a > 0.0 and notice.modulate.a < 1.0, "Expiration fades out gradually")
	await _capture("ui_card_acquisition_fading")
	await create_timer(0.5).timeout
	_check(not notice.visible, "Expired notification clears after its fade")


func _move_pointer(point: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(point)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
