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
	await _capture("categories_collapsed_opening")
	await CardCategoryUiRegression.run(self, _viewport, _game, _check)
	_select("explore")
	SurvivalTestSetup.select_frontier(_game.state)
	await _capture("survival_opening")
	var map: VillageMap = _dashboard.get_node("%VillageMap") as VillageMap
	map.view_camera.zoom_by(100.0, map.size * 0.5, map.size)
	var camp_center: Vector2 = (Vector2(TerrainGrid.CAMP) + Vector2.ONE * 0.5) * TerrainGrid.CELL
	map.view_camera.pan_by(
		map.size * 0.5 - map.view_camera.get_view_transform(map.size) * camp_center, map.size
	)
	map.queue_redraw()
	await _capture("defense_map_text_max_zoom")
	map.view_camera.focus_village()
	map.queue_redraw()
	var clues: Label = _dashboard.get_node("%ExplorationClues") as Label
	_check(
		(
			clues.is_visible_in_tree()
			and clues.text.contains("北：")
			and (
				clues.get_global_rect().end.y
				< (_dashboard.get_node("%StatusLabel") as Label).get_global_rect().position.y
			)
		),
		"Directional opening clues are visible beside the map without scrolling"
	)
	var opening_report: Label = _dashboard.detail.get_node("%SurveyReport") as Label
	_check(
		opening_report.text.contains("北：") and opening_report.text.contains("南："),
		"Opening shows directional clues before any actual discovery"
	)
	_check(
		(_dashboard.get_node("%StatusLabel") as Label).text.contains("目标："),
		"Development objective is visible beside the map"
	)
	SurvivalTestSetup.developed(_game.state)
	_game.state.assign_jobs(PackedInt32Array([0, 1, 1, 1, 1, 1]))
	(_dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	await CardCategoryUiRegression.run(self, _viewport, _game, _check)
	var building_button: Button = _dashboard.get_node("%CardCategoryBar/Building/Button") as Button
	await _drag_pointer(building_button.get_global_rect().get_center(), building_button.get_global_rect().get_center())
	await _capture("categories_building")
	(_dashboard.get_node("%CardCategoryBar/All/Button") as Button).pressed.emit()
	_select("wall")
	await _capture("survival_action_costs")
	await _capture_layout_options()
	await _test_action_dock()
	_check(
		(_dashboard.detail.get_node("%CardTitle") as Label).is_visible_in_tree(),
		"Floating confirmation shows the selected card title"
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
	await _test_event_flow()
	await _test_environment_views()
	_game.hide()
	await CardGalleryCapture.run(_viewport, _game.state, _check, _capture)
	_game.show()
	var result: String = "BACKGROUND UI RESULT: %d checks, %d failures" % [_checks, _failures]
	print(result)
	var file: FileAccess = FileAccess.open(
		"res://test-results/capture_complete.txt", FileAccess.WRITE
	)
	file.store_string(result)
	DisplayServer.unregister_additional_output(_viewport)
	quit(0 if _failures == 0 else 1)


func _capture_layout_options() -> void:
	var dock: ActionDock = _dashboard.get_node("%ActionSplit") as ActionDock
	dock.popup_width = 1120.0
	dock.popup_height = 420.0
	dock.refresh_layout()
	await _capture("popup_layout_a_wide")
	dock.popup_width = 1000.0
	dock.popup_height = 420.0
	dock.refresh_layout()
	await _capture("popup_layout_b_compact")
	dock.popup_width = 1000.0
	dock.popup_height = 360.0
	dock.refresh_layout()
	await _capture("popup_layout_c_shallow")
	dock.popup_height = 420.0
	dock.refresh_layout()
	await _capture("popup_layout_final")
	(_dashboard.get_node("%CardCategoryBar/Event/Button") as Button).pressed.emit()
	await _capture("popup_empty_category")
	(_dashboard.get_node("%CardCategoryBar/All/Button") as Button).pressed.emit()
	_select("wall")
	await _capture("popup_selected_context")


func _test_action_dock() -> void:
	var dock: ActionDock = _dashboard.get_node("%ActionSplit") as ActionDock
	var tray: Control = dock.get_node("ActionTray") as Control
	var map: VillageMap = _dashboard.get_node("%VillageMap") as VillageMap
	var original_map: Rect2 = map.get_global_rect()
	var actions: int = _game.state.actions_used
	await _capture("cards_floating_panel")
	_check(tray.get_global_rect().intersects(original_map), "Card popup overlaps the map")
	var navigation: CardCategoryBar = _dashboard.get_node("%CardCategoryBar") as CardCategoryBar
	_check(
		tray.get_global_rect().end.y < navigation.get_global_rect().position.y,
		"Entire card popup floats above the category buttons"
	)
	var connector: Polygon2D = dock.get_node("Connector") as Polygon2D
	_check(
		connector.visible and connector.polygon.size() == 3,
		"Popup has an ownership pointer to the active category"
	)
	var execute: Button = _dashboard.detail.get_node("%ExecuteButton") as Button
	_check(tray.get_global_rect().encloses(execute.get_global_rect()), "Popup keeps confirmation visible")
	_check(
		tray.get_global_rect().encloses(
			(_dashboard.detail.get_node("%SelectedCosts") as Control).get_global_rect()
		),
		"Popup keeps costs inside the card panel"
	)
	await _test_tray_visibility(dock, tray, map)
	_check(_game.state.actions_used == actions, "Popup gestures consume no actions")


func _test_tray_visibility(dock: ActionDock, tray: Control, map: VillageMap) -> void:
	var toggle: Button = _dashboard.get_node("%ToggleCards") as Button
	var original_map: Rect2 = map.get_global_rect()
	var original_tray: Rect2 = tray.get_global_rect()
	var actions: int = _game.state.actions_used
	var point: Vector2 = (_dashboard.get_node("%CloseCards") as Button).get_global_rect().get_center()
	await _drag_pointer(point, point)
	await _capture("survival_cards_hidden")
	_check(not tray.is_visible_in_tree(), "Hide button hides cards and confirmation together")
	_check(map.get_global_rect().is_equal_approx(original_map), "Closing popup does not resize the map")
	_check(toggle.is_visible_in_tree(), "Expand control remains accessible with popup closed")
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	_viewport.push_input(enter, true)
	await process_frame
	_check(_game.state.actions_used == actions, "Enter cannot execute an invisible card")
	point = toggle.get_global_rect().get_center()
	await _drag_pointer(point, point)
	await _capture("survival_cards_restored")
	_check(dock.is_expanded(), "Expand button restores the card popup")
	_check(tray.get_global_rect().is_equal_approx(original_tray), "Popup restores the same location")
	_check(map.get_global_rect().is_equal_approx(original_map), "Opening popup does not resize the map")


func _drag_pointer(start: Vector2, finish: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = start
	move.global_position = start
	_viewport.push_input(move, true)
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.global_position = start
	_viewport.push_input(press, true)
	await process_frame
	move = InputEventMouseMotion.new()
	move.position = finish
	move.global_position = finish
	move.relative = finish - start
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(move, true)
	await process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = finish
	press.global_position = finish
	_viewport.push_input(press, true)
	await process_frame


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


func _test_environment_views() -> void:
	_game.set_process(false)
	_set_capture_size(Vector2i(1440, 960))
	_game.state.new_run(65012, GameTypes.Region.RURAL)
	for action: int in 3:
		SurvivalTestSetup.select_frontier(_game.state)
		_game.state.play_card(_game.state.hand[0].uid)
	for tick: int in 300:
		_game.battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	_dashboard.update_playback(_game.state, _game.battle, false, 1.0)
	await _capture("environment_stationary_camp")
	while _game.battle.active:
		_game.battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	SurvivalTestSetup.settle_day_end(_game.state)
	(_dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	_select("quiet")
	await _capture("environment_concealment_card")
	var uid: int = -1
	for entry: CardInstance in _game.state.hand:
		if entry.definition.id == "quiet":
			uid = entry.uid
	_check(_game.state.play_card(uid), "Rendered concealment executes real card costs")
	_game.state.skip_slot()
	_game.state.skip_slot()
	_check(
		(
			_game.state.phase == GameTypes.Phase.NIGHT
			and _game.state.night_stats.concealed
			and _game.state.wave_count() == 0
		),
		"Quiet opening freezes an undetected night"
	)
	await _capture("environment_hidden_camp")
	_game.battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	var event: DailyEvent = _game.state.current_day_end_event()
	if event != null and event.trigger == DailyEvent.Trigger.AMBIENT:
		var ignore: Button = _dashboard.overlay.get_node("%DayEndSkip") as Button
		_check(ignore.is_visible_in_tree(), "Ordinary encounter actually offers ignore")
		await _capture("environment_optional_encounter")
		ignore.pressed.emit()
	SurvivalTestSetup.settle_day_end(_game.state)
	_check(_game.state.resources[GameTypes.Stock.NOISE] == 0, "Rendered next day starts quiet")


func _test_event_flow() -> void:
	_game.set_process(false)
	_set_capture_size(Vector2i(1440, 960))
	_game.state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(_game.state)
	_game.state.core_health = 200.0
	_game.state.resources[GameTypes.Stock.FOOD] = 0
	_game.state.resources[GameTypes.Stock.WATER] = 0
	_game.state.resources[GameTypes.Stock.MEDICINE] = 0
	_game.state.weather = _game.state.catalog.library.weather_rules.for_kind(
		WeatherDefinition.Kind.CLEAR
	)
	_game.state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.core_health = _game.state.core_health
	report.started_survivors = _game.state.population
	report.survivors = _game.state.population
	report.has_identities = true
	report.consumed.resize(GameTypes.Stock.COUNT)
	for person: SurvivorRecord in _game.state.progress.survivors:
		report.survivor_ids.append(person.id)
	_game.state.finish_night(report)
	(_dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	_check(
		_game.state.phase == GameTypes.Phase.DAY_END,
		"Synthetic background report belongs to the actual night"
	)
	_game.state.day_end_event_id = "day_end_ration"
	_game.state.pending_day_end_events.clear()
	_game.state.changed.emit()
	await _capture("events_empty_food")
	var row: HBoxContainer = _dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	_check(
		(row.get_child(0).get_node("%SelectButton") as Button).disabled,
		"Rendered hot meal rejects empty food"
	)
	await _click_event_fallback()
	await _capture("events_hunger_and_thirst")
	_check(
		(_dashboard.overlay.get_node("%DayEndTitle") as Label).text.contains("剩余 2 项"),
		"Rendered morning shows both mandatory shortages"
	)
	_check(
		not (_dashboard.overlay.get_node("%DayEndSkip") as Button).visible,
		"Mandatory crisis has no skip control"
	)
	_set_capture_size(Vector2i(1024, 768))
	await _capture("events_hunger_small")
	row = _dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	var button: Button = row.get_child(1).get_node("%SelectButton") as Button
	_check(
		Rect2(Vector2.ZERO, _game.size).encloses(button.get_global_rect()),
		"Small viewport keeps hunger confirmation visible"
	)
	await _click_event_fallback()
	await _capture("events_thirst_small")
	_check(
		_game.state.current_day_end_event().trigger == DailyEvent.Trigger.THIRST,
		"Offscreen input advances from hunger to thirst"
	)
	await _click_event_fallback()
	_check(
		_game.state.phase == GameTypes.Phase.DAY and _game.state.modifiers.size() == 2,
		"Both offscreen crisis decisions retain next-night penalties"
	)
	_set_capture_size(Vector2i(1440, 960))


func _click_event_fallback() -> void:
	var row: HBoxContainer = _dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	var button: Button = row.get_child(1).get_node("%SelectButton") as Button
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		_viewport.push_input(event, true)
	await process_frame
