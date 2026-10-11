extends SceneTree
## 隐藏后台渲染入口：仅保存离屏游戏视口，不截桌面、不移动光标、不写玩家存档。

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _viewport: SubViewport
var _game: VillageGame
var _dashboard: VillageDashboard
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	root.unfocusable = true
	root.mode = Window.MODE_MINIMIZED
	var pid: FileAccess = FileAccess.open("res://test-results/capture_pid.txt", FileAccess.WRITE)
	pid.store_string(str(OS.get_process_id()))
	call_deferred(&"_run")


func _run() -> void:
	_viewport = SubViewport.new()
	_set_capture_size(Vector2i(1440, 960))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	DisplayServer.register_additional_output(_viewport)
	_game = MAIN_SCENE.instantiate() as VillageGame
	_game.state.persistence_enabled = false
	_game.state.save_path = "res://test-results/background_roundtrip.tres"
	_viewport.add_child(_game)
	_dashboard = _game.get_node("Dashboard") as VillageDashboard
	_game.state.new_run(65012, GameTypes.Region.RURAL)
	_select("explore")
	SurvivalTestSetup.select_frontier(_game.state)
	await _capture("survival_opening")
	SurvivalTestSetup.developed(_game.state)
	_game.state.assign_jobs(PackedInt32Array([0, 1, 1, 1, 1, 1]))
	(_dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	_select("wall")
	await _capture("survival_action_costs")
	var selected_art: TextureRect = _dashboard.detail.get_node("%ActionArt") as TextureRect
	_check(
		(
			selected_art.is_visible_in_tree()
			and selected_art.size.x >= 250.0
			and selected_art.size.y >= 90.0
		),
		"Selected action shows a full-width illustration"
	)
	_game.state.resources[GameTypes.Stock.WOOD] = 0
	_game.state.changed.emit()
	await _capture("survival_missing_resource")
	var wood_chip: Label = (
		(
			(_dashboard.detail.get_node("%SelectedCosts") as CardCostStrip)
			. get_child(GameTypes.Stock.WOOD + 1)
			. get_node("Amount")
		)
		as Label
	)
	_check(
		wood_chip.get_theme_color("font_color") == UiElements.NEGATIVE,
		"Selected action marks its missing resource on the cost chip"
	)
	await MixedCardCostsUiRegression.run(self, _game, _check)
	await _capture_inspection()
	await _test_click_confirmation()
	await _capture_sizes()
	_dashboard.overlay.show_village()
	await _capture("survival_village")
	_dashboard.overlay.close_modal()
	_game.state.cards_acquired.emit(PackedInt32Array([_game.state.hand[0].uid]))
	await create_timer(0.3).timeout
	await _capture("survival_acquired")
	await _capture_camp_conditions()
	var result: String = "BACKGROUND UI RESULT: %d checks, %d failures" % [_checks, _failures]
	print(result)
	var file: FileAccess = FileAccess.open(
		"res://test-results/capture_complete.txt", FileAccess.WRITE
	)
	file.store_string(result)
	DisplayServer.unregister_additional_output(_viewport)
	quit(0 if _failures == 0 else 1)


func _capture_camp_conditions() -> void:
	for texture: Texture2D in [ApocalypseMapArt.CAMP_ATLAS, ApocalypseMapArt.PEOPLE_ATLAS]:
		_check(
			texture.get_image().detect_alpha() != Image.ALPHA_NONE,
			"Painted sprites retain transparency"
		)
	(_dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	for building: GameTypes.Building in [
		GameTypes.Building.WELL,
		GameTypes.Building.GENERATOR,
		GameTypes.Building.LIGHTS,
		GameTypes.Building.WORKSHOP,
		GameTypes.Building.CLINIC,
		GameTypes.Building.GREENHOUSE,
		GameTypes.Building.FOOD_STORE,
		GameTypes.Building.WATER_TANK,
		GameTypes.Building.BATTERY
	]:
		_game.state.buildings[building] = 1
	_game.state.changed.emit()
	var map: VillageMap = _dashboard.get_node("%VillageMap") as VillageMap
	map.fit_world()
	await _capture("survival_camp_developed")
	_game.state.weather = _game.state.catalog.library.weather_rules.for_kind(
		WeatherDefinition.Kind.THUNDERSTORM
	)
	_game.state.changed.emit()
	await create_timer(0.4).timeout
	await _capture("survival_camp_storm")
	_game.state.begin_night()
	await create_timer(0.7).timeout
	map.fit_world()
	await _capture("survival_camp_night")


func _capture(name: String) -> void:
	for frame: int in 3:
		await process_frame
		RenderingServer.force_draw(false)
	var image: Image = _viewport.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Rendered game image: " + name)
	if image != null and not image.is_empty():
		_check(image.save_png("res://test-results/" + name + ".png") == OK, "Saved " + name)


func _capture_inspection() -> void:
	for entry: CardInstance in _game.state.hand:
		if entry.definition.id == "wall":
			_dashboard.overlay.show_card(entry.uid)
			break
	await _capture("survival_card_inspection")
	var risk: RichTextLabel = (
		_dashboard.overlay.get_node("%CardInspection/%InspectionFace/%FaceRisk") as RichTextLabel
	)
	_check(
		risk.is_visible_in_tree() and risk.size.y > 0.0,
		"Rendered inspection includes complete risk"
	)
	_dashboard.overlay.close_modal()


func _capture_sizes() -> void:
	for size: Vector2i in [Vector2i(1024, 768), Vector2i(1920, 820)]:
		_set_capture_size(size)
		await _capture("survival_layout_%dx%d" % [size.x, size.y])
		var footer: Control = _dashboard.get_node("Margin/Layout/Footer") as Control
		_check(
			Rect2(Vector2.ZERO, _game.size).encloses(footer.get_global_rect()),
			"Footer stays within offscreen game viewport"
		)
		_check(
			Rect2(Vector2.ZERO, _game.size).encloses(_dashboard.detail.get_global_rect()),
			"Action plan stays within offscreen game viewport"
		)
	_set_capture_size(Vector2i(1440, 960))


func _test_click_confirmation() -> void:
	_game.state.resources[GameTypes.Stock.WOOD] = 40
	_game.state.changed.emit()
	_select("wall")
	await process_frame
	await process_frame
	var button: Button = _dashboard.detail.get_node("%ExecuteButton") as Button
	var before: int = _game.state.actions_used
	var before_slot: int = _game.state.slot
	var levels: int = _game.state.buildings[GameTypes.Building.WALL]
	_check(not button.disabled, "Prepared action has an enabled confirmation")
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		_viewport.push_input(event, true)
	await process_frame
	_check(
		(
			(
				_game.state.actions_used == before + 1
				or (_game.state.slot == before_slot + 1 and _game.state.actions_used == 0)
			)
			and _game.state.buildings[GameTypes.Building.WALL] == levels + 1
		),
		"Offscreen mouse confirmation commits the action once"
	)
	_select("forage")


func _select(id: String) -> void:
	for child: Node in _dashboard.hand_panel.get_node("%HandContainer").get_children():
		var card: VillageCardButton = child as VillageCardButton
		if card.card.id == id:
			card.pressed.emit()
			(
				(_dashboard.hand_panel.get_node("HandScroll") as ScrollContainer)
				. ensure_control_visible(card)
			)
			return
	push_error("Capture card missing: " + id)
	_failures += 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("BACKGROUND UI FAIL: " + message)


func _set_capture_size(size: Vector2i) -> void:
	_viewport.size = size
	var ratio: float = minf(float(size.x) / 1280.0, float(size.y) / 854.0)
	_viewport.size_2d_override = Vector2i(Vector2(size) / ratio)
	_viewport.size_2d_override_stretch = true
