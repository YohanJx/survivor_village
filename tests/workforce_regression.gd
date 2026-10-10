class_name WorkforceRegression
extends RefCounted
## 职业费用、人口行动与存档迁移的行为边界。


static func run(check: Callable) -> void:
	var state: VillageState = _fresh()
	var rules: WorkforceRules = state.catalog.library.workforce_rules
	check.call(state.actions_per_slot == 1, "Five people have one action per slot")
	check.call(
		rules.action_capacity(10) == 2 and rules.action_capacity(20) == 4,
		"Action budget grows with population"
	)
	check.call(
		rules.action_capacity(1) == 1 and rules.action_capacity(100) == 4,
		"Action capacity has floor and ceiling"
	)
	var card: CardDefinition = state.catalog.get_card("forage")
	state.profession_counts = PackedInt32Array([0, 0, 2, 1, 1, 1])
	check.call(
		EffectResolver.cost_totals(card, state)[0] == 18, "Missing gatherer uses 1.5 times stamina"
	)
	state.profession_counts = PackedInt32Array([0, 2, 0, 1, 1, 1])
	check.call(
		EffectResolver.cost_totals(card, state)[0] == 11,
		"Two gatherers reduce stamina and round up"
	)
	state.population = 30
	check.call(rules.valid_roster(state.profession_counts, 30), "Recruiting reconciles job totals")
	check.call(
		EffectResolver.cost_totals(card, state)[0] == 8, "Many specialists reach the 0.6 cost floor"
	)
	state.population = 3
	check.call(rules.valid_roster(state.profession_counts, 3), "Casualties reconcile job totals")
	_test_atomic_costs(check)
	_test_actions(check)
	_test_saves(check)


static func _test_atomic_costs(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.profession_counts = PackedInt32Array([0, 0, 2, 1, 1, 1])
	var uid: int = _uid(state, "forage")
	state.resources[0] = 17
	var before: VillageSaveData = state.snapshot()
	check.call(not state.play_card(uid), "Adjusted stamina is enforced by execution")
	check.call(
		(
			state.resources == before.resources
			and state.slot == before.slot
			and state.actions_used == before.actions_used
		),
		"Rejected cost has no side effects"
	)
	state.resources[0] = 18
	check.call(
		state.play_card(uid) and state.resources[0] == 0, "Adjusted preview and actual debit agree"
	)
	var definition: CardDefinition = CardDefinition.new()
	definition.profession = GameTypes.Profession.GATHERER
	var first: ResourceCost = ResourceCost.new()
	first.amount = 1
	var second: ResourceCost = ResourceCost.new()
	second.amount = 1
	definition.costs = [first, second]
	check.call(
		EffectResolver.cost_totals(definition, state)[0] == 3,
		"Duplicate stamina fees are summed before multiplier and ceiling"
	)


static func _test_actions(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.population = 10
	state.actions_per_slot = state.catalog.library.workforce_rules.action_capacity(state.population)
	state.resources[0] = 100
	state.play_card(_uid(state, "forage"))
	check.call(state.slot == 0 and state.actions_used == 1, "First action keeps a two-action slot")
	var preview: VillageSaveData = state.snapshot()
	state.preview_card(state.catalog.get_card("water"))
	check.call(
		(
			state.profession_counts == preview.profession_counts
			and state.resources == preview.resources
		),
		"Profession preview does not mutate original"
	)
	var restored: VillageState = _fresh()
	check.call(
		restored.restore(preview) and restored.actions_used == 1 and restored.actions_per_slot == 2,
		"Mid-slot save restores remaining action budget"
	)
	state.skip_slot()
	check.call(state.slot == 1 and state.actions_used == 0, "Second action advances the slot")
	for index: int in 4:
		state.skip_slot()
	check.call(state.phase == GameTypes.Phase.NIGHT, "Six actions reach night for ten people")
	state = _fresh()
	state.population = 10
	check.call(state.actions_per_slot == 1, "Recruitment leaves today's frozen quota unchanged")
	state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.started_survivors = 10
	report.survivors = 10
	report.core_health = state.core_health
	state.finish_night(report)
	state.choose_reward(0)
	check.call(
		state.day == 2 and state.actions_per_slot == 2 and state.actions_used == 0,
		"Dawn recalculates next day's quota from surviving population"
	)


static func _test_saves(check: Callable) -> void:
	var state: VillageState = _fresh()
	var data: VillageSaveData = state.snapshot()
	data.version = VillageSaveData.LEGACY_VERSION
	data.profession_counts.clear()
	check.call(
		state.restore(data) and state.snapshot().version == VillageSaveData.CURRENT_VERSION,
		"Version two migrates to version three in memory"
	)
	check.call(
		state.catalog.library.workforce_rules.valid_roster(state.profession_counts, 5),
		"Legacy migration supplies a complete profession roster"
	)
	check.call(
		data.profession_counts.is_empty() and data.version == 2,
		"Migration leaves source save untouched"
	)
	data = state.snapshot()
	data.profession_counts[1] += 1
	check.call(not state.restore(data), "Mismatched profession totals rejected")
	data = state.snapshot()
	data.actions_used = data.actions_per_slot
	check.call(not state.restore(data), "Out-of-range action counter rejected")
	var rules: WorkforceRules = state.catalog.library.workforce_rules.duplicate() as WorkforceRules
	rules.missing_profession_multiplier = NAN
	check.call(not rules.validation_error().is_empty(), "Non-finite profession multiplier rejected")


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(12345)
	return state


static func _uid(state: VillageState, id: String) -> int:
	for instance: CardInstance in state.hand:
		if instance.definition.id == id:
			return instance.uid
	return -1
