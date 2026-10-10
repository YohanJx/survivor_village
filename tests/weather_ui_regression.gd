class_name WeatherUiRegression
extends RefCounted
## 真实场景渲染四时段与天气，并验证地图表现层不会截获鼠标。


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var state: VillageState = game.state
	var original: VillageSaveData = state.snapshot()
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var atmosphere: MapAtmosphere = dashboard.get_node("%MapAtmosphere") as MapAtmosphere
	check.call(
		atmosphere.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Weather layer passes mouse input"
	)
	var period_names: PackedStringArray = ["morning", "afternoon", "dusk", "night"]
	var backgrounds: Array[Color] = []
	for period: int in 4:
		var data: VillageSaveData = original.duplicate(true) as VillageSaveData
		data.slot = mini(period, 2)
		if period == 3:
			state.restore(data)
			state.begin_night()
		else:
			check.call(state.restore(data), "Day period restores for visual check")
		await tree.process_frame
		var background: Color = (dashboard.get_node("Background") as ColorRect).color
		check.call(not backgrounds.has(background), "Each time period has a distinct background")
		backgrounds.append(background)
		await capture.call("ui_time_" + period_names[period])
	for kind: WeatherDefinition.Kind in [
		WeatherDefinition.Kind.CLOUDY,
		WeatherDefinition.Kind.RAIN,
		WeatherDefinition.Kind.THUNDERSTORM,
		WeatherDefinition.Kind.FOG,
	]:
		var data: VillageSaveData = original.duplicate(true) as VillageSaveData
		data.weather_kind = kind
		check.call(state.restore(data), "Weather restores in graphical scene")
		var label: Label = dashboard.get_node("%WeatherLabel") as Label
		check.call(label.text.contains(state.weather.display_name), "HUD displays current weather")
		check.call(label.tooltip_text == state.weather.description, "HUD explains gameplay effects")
		await capture.call("ui_weather_%d" % kind)
		if kind == WeatherDefinition.Kind.THUNDERSTORM:
			await tree.create_timer(12.12).timeout
			await capture.call("ui_weather_lightning")
	check.call(state.restore(original), "Visual checks restore original run")
