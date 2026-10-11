class_name TerrainMapRenderer
extends RefCounted
## 绘制生成地形、探索迷雾与可选前沿；不变更玩法状态。

const DAY_CLEARING: StyleBoxFlat = preload("res://data/ui/camp_ground_day.tres")
const NIGHT_CLEARING: StyleBoxFlat = preload("res://data/ui/camp_ground_night.tres")


static func draw_survey(canvas: Control, state: VillageState, camera: MapViewCamera) -> void:
	var scale_value: float = camera.get_view_transform(canvas.size).get_scale().x
	for y: int in TerrainGrid.SIZE.y:
		for x: int in TerrainGrid.SIZE.x:
			_draw_survey_cell(canvas, state, Vector2i(x, y), scale_value)


static func draw_ground(
	canvas: Control,
	state: VillageState,
	night: bool,
	camp_areas: Array[Rect2],
	camera: MapViewCamera
) -> void:
	var scale_value: float = camera.get_view_transform(canvas.size).get_scale().x
	for y: int in TerrainGrid.SIZE.y:
		for x: int in TerrainGrid.SIZE.x:
			var cell: Vector2i = Vector2i(x, y)
			var area: Rect2 = Rect2(
				Vector2(cell) * TerrainGrid.CELL, Vector2.ONE * TerrainGrid.CELL
			)
			var known: bool = state.progress.explored_cells.has(TerrainGrid.index(cell))
			var color: Color = (
				TerrainGrid.COLORS[state.terrain_grid.biome(cell)] if known else Color("15252c")
			)
			canvas.draw_rect(area, color.darkened(0.35 if night else 0.12 + state.slot * 0.05))
			if known and cell != TerrainGrid.CAMP:
				canvas.draw_rect(area.grow(-1), Color(0.7, 0.8, 0.7, 0.12), false, 1)
				canvas.draw_string(
					canvas.get_theme_default_font(),
					area.position + Vector2(5, 18),
					TerrainGrid.NAMES[state.terrain_grid.biome(cell)],
					HORIZONTAL_ALIGNMENT_LEFT,
					88,
					roundi(12.0 / scale_value),
					Color("c3cbb9")
				)
	# 清理地面跟随已建设施与连接道路，不再覆盖一块固定的大矩形。
	var ground: Color = Color("62694c").darkened(0.35 if night else 0.0)
	for area: Rect2 in camp_areas:
		canvas.draw_line(WorldLayout.CENTER, area.get_center(), ground, 22)
		canvas.draw_style_box(NIGHT_CLEARING if night else DAY_CLEARING, area)


static func draw_obstacle(canvas: Control, cell: Vector2i, kind: TerrainGrid.Biome) -> void:
	var area: Rect2 = Rect2(Vector2(cell) * WorldLayout.CELL + Vector2(3, 3), Vector2(18, 18))
	match kind:
		TerrainGrid.Biome.RIVER:
			canvas.draw_line(
				area.position + Vector2(0, 8), area.end - Vector2(0, 8), Color("9acbd2"), 2
			)
		TerrainGrid.Biome.RUINS, TerrainGrid.Biome.FUEL:
			canvas.draw_rect(area, Color("8e877d"), false, 3)
			if kind == TerrainGrid.Biome.FUEL:
				canvas.draw_circle(area.get_center(), 4, Color("c59757"))
		_:
			canvas.draw_colored_polygon(
				PackedVector2Array(
					[
						area.position + Vector2(2, 15),
						area.position + Vector2(6, 2),
						area.position + Vector2(15, 5),
						area.end
					]
				),
				Color("8c8579")
			)


static func _draw_survey_cell(
	canvas: Control, state: VillageState, cell: Vector2i, scale_value: float
) -> void:
	var value: int = TerrainGrid.index(cell)
	var area: Rect2 = Rect2(Vector2(cell) * TerrainGrid.CELL, Vector2.ONE * TerrainGrid.CELL)
	var explored: bool = state.progress.explored_cells.has(value)
	var frontier: bool = TerrainGrid.is_frontier(cell, state.progress.explored_cells)
	canvas.draw_rect(
		area.grow(-1),
		TerrainGrid.COLORS[state.terrain_grid.biome(cell)] if explored else Color("24343b")
	)
	if frontier or value == state.progress.exploration_target:
		canvas.draw_rect(
			area.grow(-3),
			Color("f3c979") if value == state.progress.exploration_target else Color("89aa9a"),
			false,
			3
		)
	var title: String = (
		"营地"
		if cell == TerrainGrid.CAMP
		else (
			TerrainGrid.NAMES[state.terrain_grid.biome(cell)]
			if explored
			else "?" if frontier else "未知"
		)
	)
	canvas.draw_string(
		canvas.get_theme_default_font(),
		area.position + Vector2(4, 43),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		88,
		roundi(14.0 / scale_value),
		Color("f1eed9")
	)
	if frontier:
		canvas.draw_string(
			canvas.get_theme_default_font(),
			area.position + Vector2(4, 65),
			"距离 %d 格" % TerrainGrid.distance(cell),
			HORIZONTAL_ALIGNMENT_CENTER,
			88,
			roundi(10.0 / scale_value),
			Color("bbcbbd")
		)
