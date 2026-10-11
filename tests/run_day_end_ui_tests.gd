extends SceneTree
## 后台实例化实际场景，验证日终输入和布局；不请求系统焦点或移动光标。

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1440, 960)
	var game: VillageGame = MAIN_SCENE.instantiate() as VillageGame
	game.state.persistence_enabled = false
	root.add_child(game)
	game.state.new_run(12345, GameTypes.Region.RURAL)
	await process_frame
	_check(
		not (game.get_node("Dashboard") as VillageDashboard).overlay.visible,
		"Dawn starts without a modal"
	)
	await SurvivalUiRegression.run(self, game, _check, _capture)
	await ProgressionUiRegression.run(self, game, _check, _capture)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	await CardInspectionUiRegression.run(self, game, _check, _capture)
	await DayEndEventUiRegression.run(self, game, _check, _capture)
	print("DAY END UI RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _capture(_name: String) -> void:
	# 无窗口验证不读取渲染纹理；实际渲染证据另见验收记录。
	return
