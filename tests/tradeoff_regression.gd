class_name TradeoffRegression
extends RefCounted
## 验证原生取舍卡的事务、跨夜代价、预览隔离和日终事件独立性。


static func run(check: Callable) -> void:
	_test_cards(check)
	_test_payment(check)
	_test_debt(check)
	_test_availability(check)


static func _test_cards(check: Callable) -> void:
	for id: String in [
		"forced_march", "emergency_rations", "lure", "overcharge", "hold_position", "cache"
	]:
		var state: VillageState = _fresh()
		state.buildings[GameTypes.Building.WALL] = 1
		state.buildings[GameTypes.Building.GENERATOR] = 1
		state.resources[GameTypes.Stock.STAMINA] = 40
		var uid: int = _uid(state, id)
		var card: CardDefinition = state.find_card(uid)
		var before: VillageSaveData = state.snapshot()
		var preview: VillageStats = state.preview_card(card)
		check.call(
			(
				state.resources == before.resources
				and state.modifiers.is_empty()
				and state.rng.state == before.rng_state
				and state.hand.size() == before.hand.size()
				and state.slot == before.slot
				and state.history.size() == before.history.size()
			),
			"Tradeoff preview has no side effects: " + id
		)
		check.call(state.play_card(uid), "Tradeoff is playable: " + id)
		check.call(state.find_card(uid) == null, "Tradeoff consumes its instance: " + id)
		check.call(
			preview.values == EffectResolver.derive(state).values,
			"Tradeoff preview matches execution: " + id
		)
		for effect: CardEffect in card.effects:
			if effect.type == CardEffect.Type.MODIFIER:
				check.call(
					effect.modifier.remaining == 0 and effect.modifier.source.is_empty(),
					"Shared tradeoff modifier stays immutable: " + id
				)
		match id:
			"emergency_rations":
				check.call(
					state.resources[2] == 18 and state.resources[1] == 42,
					"Rations exchange water for food"
				)
				check.call(is_equal_approx(preview.health, 52.0), "Rations weaken guards")
			"lure":
				check.call(
					state.wave_count() > 11 and preview.wave_size == 1.5,
					"Loud salvage increases the actual upcoming wave"
				)
			"overcharge":
				check.call(
					(
						state.resources[3] == 16
						and state.resources[4] == 14
						and state.resources[6] == 12
					),
					"Overcharge grants power with real costs"
				)
			"hold_position":
				check.call(
					(
						is_equal_approx(preview.wall_health, 144.0)
						and is_equal_approx(preview.speed, 46.2)
					),
					"Fortification slows support"
				)
			"cache":
				check.call(is_equal_approx(preview.health, 55.25), "Cache has a combat penalty")


static func _test_payment(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.WATER] = 5
	var uid: int = _uid(state, "emergency_rations")
	var before: VillageSaveData = state.snapshot()
	check.call(not state.play_card(uid), "Negative water effect cannot be paid with five water")
	check.call(
		(
			state.resources == before.resources
			and state.modifiers.is_empty()
			and state.slot == before.slot
			and state.find_card(uid) != null
		),
		"Rejected tradeoff preserves stocks, effects, time and card"
	)
	state.resources[GameTypes.Stock.WATER] = 6
	check.call(state.play_card(uid) and state.resources[2] == 0, "Exact negative effect is payable")
	state = _fresh()
	uid = _uid(state, "overcharge")
	check.call(not state.can_play(uid).is_empty(), "Overcharge requires a generator")
	uid = _uid(state, "hold_position")
	check.call(not state.can_play(uid).is_empty(), "Fortification requires a wall")


static func _test_debt(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.STAMINA] = 10
	check.call(state.play_card(_uid(state, "forced_march")), "Overwork starts immediately")
	check.call(
		state.resources[0] == 45 and state.progress.frustration == 2,
		"Overwork gives stamina and frustration"
	)
	state.begin_night()
	check.call(
		state.night_stats.stamina_recovery == 30, "New overwork uses mood instead of recovery debt"
	)
	var restored: VillageState = _fresh()
	check.call(restored.restore(state.snapshot()), "Mood survives night restoration")
	check.call(restored.progress.frustration == 2, "Restored overwork preserves mood")
	# 旧存档已经生效的恢复债务仍按原期限结算，不能因重做卡牌而删除。
	var debt: StatModifier = StatModifier.new()
	debt.key = GameTypes.Stat.STAMINA_RECOVERY
	debt.amount = -18
	debt.duration = 2
	debt.remaining = 2
	debt.source = "旧版透支劳作"
	state.modifiers.append(debt)
	check.call(
		EffectResolver.derive(state).stamina_recovery == 12, "Legacy runtime debt still applies"
	)
	check.call(
		restored.restore(state.snapshot()),
		"Existing debt roundtrips independently of card definition"
	)
	EffectResolver.expire_after_night(restored)
	check.call(
		restored.modifiers[0].remaining == 1 and state.modifiers[0].remaining == 2,
		"Legacy debt copies are isolated"
	)
	EffectResolver.expire_after_night(restored)
	check.call(restored.modifiers.is_empty(), "Legacy debt expires after two nights")


static func _test_availability(check: Callable) -> void:
	var state: VillageState = _fresh()
	check.call(
		_has_card(state, "forced_march") and _has_card(state, "emergency_rations"),
		"Both emergency decisions appear in the starting hand"
	)
	state.buildings[GameTypes.Building.WALL] = 1
	state.buildings[GameTypes.Building.GENERATOR] = 1
	var hand_before: int = state.hand.size()
	var event: DailyEvent = DayEndEvents.for_day(state)
	check.call(event != null, "Day-end opportunity exists without awarding tradeoff cards")
	check.call(state.hand.size() == hand_before, "Event queries never stuff cards into the hand")


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(12345)
	SurvivalTestSetup.developed(state)
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	return state


static func _has_card(state: VillageState, id: String) -> bool:
	for card: CardInstance in state.hand:
		if card.definition.id == id:
			return true
	return false


static func _uid(state: VillageState, id: String) -> int:
	for card: CardInstance in state.hand:
		if card.definition.id == id:
			return card.uid
	state.add_card(state.catalog.get_card(id))
	return state.hand.back().uid
