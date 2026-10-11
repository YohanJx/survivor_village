class_name TerrainValidation
extends RefCounted
## 地形存档与卡牌依赖图校验；生成独立临时地图，不触碰当前局。


static func valid_progress(
	progress: VillageProgress, catalog: CardCatalog, seed_value: int
) -> bool:
	if progress == null or not catalog.is_valid:
		return false
	var map: MapDefinition = catalog.library.progression_rules.map_for(progress.region)
	if map == null:
		return false

	if (
		progress.explored_cells.is_empty()
		or progress.explored_cells[0] != TerrainGrid.index(TerrainGrid.CAMP)
	):
		return false
	if progress.terrain_surveys != progress.explored_cells.size() - 1:
		return false
	var visited: PackedInt32Array = PackedInt32Array([TerrainGrid.index(TerrainGrid.CAMP)])
	for offset: int in range(1, progress.explored_cells.size()):
		var value: int = progress.explored_cells[offset]
		if value < 0 or value >= TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
			return false
		if not TerrainGrid.is_frontier(TerrainGrid.position(value), visited):
			return false
		visited.append(value)
	if progress.exploration_target != -1:
		if (
			progress.exploration_target < 0
			or progress.exploration_target >= TerrainGrid.SIZE.x * TerrainGrid.SIZE.y
		):
			return false
		if not TerrainGrid.is_frontier(TerrainGrid.position(progress.exploration_target), visited):
			return false
	var grid: TerrainGrid = TerrainGrid.new()
	grid.generate(seed_value, map)
	if TerrainGrid.discoveries_for(grid, visited) != progress.discoveries:
		return false
	var completed: Dictionary[String, bool] = {}
	for id: String in progress.completed_cards:
		if not catalog.cards.has(id) or completed.has(id):
			return false
		completed[id] = true
	return true


static func card_graph_error(cards: Dictionary[String, CardDefinition]) -> String:
	var resolved: PackedStringArray = []
	for card: CardDefinition in cards.values():
		for id: String in card.required_cards:
			if not cards.has(id):
				return "卡牌前置未注册：" + id
	for iteration: int in cards.size():
		for card: CardDefinition in cards.values():
			if resolved.has(card.id):
				continue
			var available: bool = true
			for id: String in card.required_cards:
				if not resolved.has(id):
					available = false
			if available:
				resolved.append(card.id)
	return "" if resolved.size() == cards.size() else "卡牌前置形成循环"
