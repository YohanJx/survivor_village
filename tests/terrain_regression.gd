class_name TerrainRegression
extends RefCounted
## 生成、前沿、费用、线索、依赖图及存档失败原子性。


static func run(check: Callable) -> void:
	_test_generation(check)
	_test_exploration(check)
	_test_dependencies(check)
	_test_restore(check)


static func _fresh(
	seed_value: int = 91273, region: GameTypes.Region = GameTypes.Region.RURAL
) -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(seed_value, region)
	state.choose_daily_event(1)
	return state


static func _test_generation(check: Callable) -> void:
	for region: int in GameTypes.Region.COUNT:
		var state: VillageState = _fresh(91273, region as GameTypes.Region)
		var copy: VillageState = _fresh(91273, region as GameTypes.Region)
		var other: VillageState = _fresh(91274, region as GameTypes.Region)
		var changed: bool = false
		for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
			var cell: Vector2i = TerrainGrid.position(value)
			check.call(
				state.terrain_grid.biome(cell) == copy.terrain_grid.biome(cell),
				"Same seed reproduces each terrain cell"
			)
			changed = changed or state.terrain_grid.biome(cell) != other.terrain_grid.biome(cell)
			if region in [GameTypes.Region.MOUNTAIN, GameTypes.Region.RUINS]:
				check.call(
					not state.terrain_grid.sources(cell).has(GameTypes.Discovery.RIVER),
					"Dry regions never invent a river"
				)
		check.call(changed, "Different seeds change geographic distribution")
		check.call(
			state.progress.discoveries.is_empty(), "Generating a map never unlocks hidden sources"
		)


static func _test_exploration(check: Callable) -> void:
	var state: VillageState = _fresh()
	var card: CardDefinition = state.catalog.get_card("explore")
	var uid: int = state.hand[0].uid
	var before: VillageSaveData = state.snapshot()
	check.call(not state.play_card(uid), "Survey requires selected target")
	check.call(
		(
			state.resources == before.resources
			and state.rng.state == before.rng_state
			and state.slot == 0
		),
		"Unselected survey is an atomic rejection"
	)
	check.call(not state.select_exploration(TerrainGrid.CAMP), "Camp cannot be surveyed twice")
	check.call(
		not state.select_exploration(TerrainGrid.CAMP + Vector2i(1, 1)),
		"Diagonal cell is not adjacent"
	)
	check.call(not state.select_exploration(Vector2i(-1, 3)), "Out-of-bounds target rejected")
	var first: Vector2i = TerrainGrid.CAMP + Vector2i.RIGHT
	check.call(state.select_exploration(first), "Orthogonal frontier selectable")
	var base_cost: int = EffectResolver.cost_totals(card, state)[GameTypes.Stock.STAMINA]
	before = state.snapshot()
	state.preview_card(card)
	check.call(
		(
			state.progress.explored_cells == before.progress.explored_cells
			and state.rng.state == before.rng_state
		),
		"Preview reveals no actual terrain and consumes no randomness"
	)
	check.call(state.play_card(uid), "Selected frontier commits")
	check.call(
		(
			state.progress.discoveries
			== TerrainGrid.discoveries_for(state.terrain_grid, state.progress.explored_cells)
		),
		"Only visited cells contribute discovery unlocks"
	)
	check.call(
		state.progress.exploration_target == -1 and state.progress.terrain_surveys == 1,
		"Commit clears target and records one explored cell"
	)
	check.call(
		SurvivalRules.exploration_summary(state).contains("侧线索"),
		"Survey returns directional environment clues"
	)
	check.call(not state.select_exploration(first), "Explored cell cannot be reused")
	check.call(
		state.select_exploration(first + Vector2i.RIGHT), "Frontier extends from the new discovery"
	)
	check.call(
		EffectResolver.cost_totals(card, state)[GameTypes.Stock.STAMINA] == base_cost + 2,
		"Travel cost increases with distance before profession multipliers"
	)
	state.resources[GameTypes.Stock.STAMINA] = 0
	before = state.snapshot()
	check.call(not state.play_card(uid), "Insufficient stamina rejects selected survey")
	check.call(
		(
			state.progress.explored_cells == before.progress.explored_cells
			and state.progress.exploration_target == before.progress.exploration_target
		),
		"Failed payment preserves terrain and selection"
	)
	state.resources[GameTypes.Stock.STAMINA] = 100
	check.call(state.play_card(uid), "Frontier can be explored after restoring stamina")


static func _test_dependencies(check: Callable) -> void:
	var state: VillageState = _fresh()
	for card: CardDefinition in state.catalog.library.cards:
		if SurvivalRules.is_survey(card):
			continue
		check.call(
			not SurvivalRules.unlock_error(state, card).is_empty(),
			"Every non-root card requires prior exploration and a later day"
		)
	SurvivalTestSetup.developed(state)
	state.progress.completed_cards.clear()
	var arrows: CardDefinition = state.catalog.get_card("arrows")
	check.call(
		not SurvivalRules.unlock_error(state, arrows).is_empty(),
		"Arrow crafting is closed without workshop construction"
	)
	state.progress.completed_cards.append("workshop")
	check.call(
		SurvivalRules.unlock_error(state, arrows).is_empty(),
		"Workshop completion opens arrow crafting for builders"
	)
	state.profession_counts = PackedInt32Array([5, 0, 0, 0, 0, 0])
	check.call(
		not SurvivalRules.unlock_error(state, arrows).is_empty(),
		"Recipe knowledge cannot replace the required profession"
	)
	var cards: Dictionary[String, CardDefinition] = {}
	var left: CardDefinition = arrows.duplicate(false) as CardDefinition
	var right: CardDefinition = (
		state.catalog.get_card("workshop").duplicate(false) as CardDefinition
	)
	left.required_cards = PackedStringArray([right.id])
	right.required_cards = PackedStringArray([left.id])
	cards[left.id] = left
	cards[right.id] = right
	check.call(
		not TerrainValidation.card_graph_error(cards).is_empty(), "Cyclic recipe graph rejected"
	)
	right.required_cards = PackedStringArray(["missing"])
	check.call(
		not TerrainValidation.card_graph_error(cards).is_empty(),
		"Unknown recipe prerequisite rejected"
	)


static func _test_restore(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.select_exploration(TerrainGrid.CAMP + Vector2i.UP)
	state.play_card(state.hand[0].uid)
	state.select_exploration(TerrainGrid.CAMP + Vector2i.RIGHT)
	var data: VillageSaveData = state.snapshot()
	var copy: VillageState = _fresh(1)
	check.call(copy.restore(data), "Explored map and selected frontier roundtrip")
	check.call(
		(
			copy.progress.explored_cells == state.progress.explored_cells
			and copy.progress.exploration_target == state.progress.exploration_target
		),
		"Restore preserves exact exploration route and pending selection"
	)
	data.progress.explored_cells.append(0)
	data.progress.terrain_surveys += 1
	var before: VillageSaveData = copy.snapshot()
	check.call(not copy.restore(data), "Disconnected explored cell rejected")
	check.call(
		(
			copy.progress.explored_cells == before.progress.explored_cells
			and copy.run_seed == before.run_seed
		),
		"Rejected save leaves current map intact"
	)
	data = state.snapshot()
	data.progress.completed_cards.append("not_registered")
	check.call(not copy.restore(data), "Unknown completion record rejected")
	data = state.snapshot()
	data.progress.exploration_target = TerrainGrid.index(TerrainGrid.CAMP)
	check.call(not copy.restore(data), "Save cannot target an already explored cell")
	data = state.snapshot()
	data.version = 6
	data.progress.explored_cells.clear()
	data.progress.exploration_target = -1
	data.progress.terrain_surveys = 3
	data.progress.discoveries = (
		state
		. catalog
		. library
		. progression_rules
		. map_for(state.progress.region)
		. discoveries
		. duplicate()
	)
	check.call(
		copy.restore(data) and copy.restore(copy.snapshot()),
		"Version six migrates to a connected geographic save"
	)
	check.call(
		data.progress.explored_cells.is_empty(), "Migration does not mutate original save resource"
	)
