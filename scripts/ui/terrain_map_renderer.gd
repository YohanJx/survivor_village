class_name TerrainMapRenderer
extends RefCounted
## 真实发现的纹理地形与统一灰褐迷雾；不变更状态、不提前暴露未知区域资源。


static func draw_survey(
	canvas: Control, state: VillageState, camera: MapViewCamera, art: ApocalypseMapArt
) -> void:
	var scale_value: float = camera.get_view_transform(canvas.size).get_scale().x
	for y: int in TerrainGrid.SIZE.y:
		for x: int in TerrainGrid.SIZE.x:
			_draw_survey_cell(canvas, state, Vector2i(x, y), scale_value, art)


static func draw_ground(
	canvas: Control,
	state: VillageState,
	night: bool,
	art: ApocalypseMapArt,
	structures: Array[StructurePlacement]
) -> void:
	var pigment: Color = Color(0.58, 0.58, 0.55) if night else Color(0.82, 0.80, 0.75)
	for y: int in TerrainGrid.SIZE.y:
		for x: int in TerrainGrid.SIZE.x:
			var cell: Vector2i = Vector2i(x, y)
			var area: Rect2 = Rect2(
				Vector2(cell) * TerrainGrid.CELL, Vector2.ONE * TerrainGrid.CELL
			)
			art.draw_soil(canvas, area, pigment)
			var known: bool = state.progress.explored_cells.has(TerrainGrid.index(cell))
			var kind: TerrainGrid.Biome = (
				state.terrain_grid.biome(cell) if known else TerrainGrid.Biome.PLAIN
			)
			if known and kind != TerrainGrid.Biome.PLAIN:
				art.draw_ground_patch(canvas, area, kind, pigment)
			if not known:
				canvas.draw_rect(area, Color(0.08, 0.075, 0.065, 0.90))
	for structure: StructurePlacement in structures:
		var center: Vector2 = (
			(Vector2(structure.rect.position) + Vector2(structure.rect.size) * 0.5)
			* WorldLayout.CELL
		)
		canvas.draw_line(WorldLayout.CENTER, center, Color(0.36, 0.31, 0.23, 0.22), 14)


static func _draw_survey_cell(
	canvas: Control, state: VillageState, cell: Vector2i, scale_value: float, art: ApocalypseMapArt
) -> void:
	var value: int = TerrainGrid.index(cell)
	var area: Rect2 = Rect2(Vector2(cell) * TerrainGrid.CELL, Vector2.ONE * TerrainGrid.CELL)
	var explored: bool = state.progress.explored_cells.has(value)
	var frontier: bool = TerrainGrid.is_frontier(cell, state.progress.explored_cells)
	var kind: TerrainGrid.Biome = (
		state.terrain_grid.biome(cell) if explored else TerrainGrid.Biome.PLAIN
	)
	art.draw_ground(canvas, area, kind, Color(0.80, 0.77, 0.70))
	if not explored:
		canvas.draw_rect(area, Color(0.075, 0.07, 0.06, 0.92))
	canvas.draw_rect(area.grow(-1), Color(0.63, 0.57, 0.44, 0.22), false, 1)
	if frontier or value == state.progress.exploration_target:
		canvas.draw_rect(
			area.grow(-3),
			UiElements.EMPHASIS if value == state.progress.exploration_target else Color("918a75"),
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
		UiElements.TEXT_PRIMARY
	)
	if frontier:
		canvas.draw_string(
			canvas.get_theme_default_font(),
			area.position + Vector2(4, 65),
			"距离 %d 格" % TerrainGrid.distance(cell),
			HORIZONTAL_ALIGNMENT_CENTER,
			88,
			roundi(10.0 / scale_value),
			UiElements.TEXT_SECONDARY
		)
