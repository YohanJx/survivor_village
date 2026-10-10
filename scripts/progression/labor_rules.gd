class_name LaborRules
extends RefCounted
## 无副作用费用/产出查询与提交后的劳动记录，统一供事务和预览使用。


static func crew_size(state: VillageState, card: CardDefinition) -> int:
    if not card.expedition or state.progress.region == GameTypes.Region.LEGACY:
        return 1
    if renewable_fallback(state, card):
        return 1
    var limit: int = mini(state.population, mini(4, maxi(1, int(state.population / 5.0))))
    return limit if state.progress.crew == 0 else clampi(state.progress.crew, 1, limit)


static func repeating(state: VillageState, card: CardDefinition) -> bool:
    return card.labor != GameTypes.Labor.NONE and state.progress.last_labor == card.labor


static func event_for(state: VillageState) -> DailyEvent:
    return state.catalog.library.progression_rules.event_for(state.progress.event_id)


static func cost_multiplier(state: VillageState, card: CardDefinition) -> float:
    var result: float = 1.0
    if card.labor != GameTypes.Labor.NONE:
        result += (
            state.progress.frustration * state.catalog.library.progression_rules.frustration_cost
        )
    var event: DailyEvent = event_for(state)
    if event != null and state.progress.event_choice == 0:
        if event.labor == card.labor or (event.labor == GameTypes.Labor.NONE and card.expedition):
            result *= event.cost_multiplier
    return result


static func output_multiplier(state: VillageState, card: CardDefinition, key: int) -> float:
    var result: float = 1.0
    if card.labor != GameTypes.Labor.NONE:
        if repeating(state, card) and state.progress.strategies[GameTypes.Strategy.PRACTICE] > 0:
            result *= 1.25
        if (
            not repeating(state, card)
            and state.progress.last_labor != GameTypes.Labor.NONE
            and state.progress.strategies[GameTypes.Strategy.ROTATION] > 0
        ):
            result *= 1.2
    var event: DailyEvent = event_for(state)
    if (
        event != null
        and state.progress.event_choice == 0
        and event.labor == card.labor
        and (event.output_stocks.is_empty() or event.output_stocks.has(key))
    ):
        result *= event.output_multiplier
    if state.progress.region != GameTypes.Region.LEGACY and card.expedition:
        result *= (
            state.catalog.library.progression_rules.map_for(state.progress.region).abundance[key]
        )
    return result


static func material_key(state: VillageState, card: CardDefinition) -> GameTypes.Stock:
    if state.progress.region == GameTypes.Region.LEGACY:
        return GameTypes.Stock.MATERIALS
    if card.building != null:
        match card.building.id:
            GameTypes.Building.WELL:
                return GameTypes.Stock.STONE
            GameTypes.Building.GENERATOR, GameTypes.Building.LIGHTS, GameTypes.Building.FILTER, GameTypes.Building.WORKSHOP, GameTypes.Building.GREENHOUSE:
                return GameTypes.Stock.PARTS
    return GameTypes.Stock.WOOD


static func deposit_index(card: CardDefinition) -> int:
    match card.labor:
        GameTypes.Labor.SALVAGE:
            return 2
        GameTypes.Labor.WATER:
            return 1
    return 0


static func commit(state: VillageState, card: CardDefinition) -> void:
    var progress: VillageProgress = state.progress
    var added: int = 0
    if card.labor != GameTypes.Labor.NONE and not card.vent:
        if repeating(state, card):
            added = mood_gain(state, card)
            var event: DailyEvent = event_for(state)
            if (
                event != null
                and progress.event_choice == 0
                and event.low_mood
                and not progress.low_mood_used
            ):
                progress.low_mood_used = true
            progress.streak += 1
        else:
            progress.streak = 1
        progress.last_labor = card.labor
    var before: int = progress.frustration
    progress.frustration = clampi(before + added + card.mood_delta, 0, 5)
    if (
        added > 0
        and progress.frustration > before
        and progress.strategies[GameTypes.Strategy.CHANT] > 0
        and progress.chant_uses < 2
    ):
        state.add_resource(GameTypes.Stock.STAMINA, 3)
        progress.chant_uses += 1
    if card.reset_labor:
        progress.last_labor = GameTypes.Labor.NONE
        progress.streak = 0
    if card.strategy != GameTypes.Strategy.NONE:
        progress.strategies[card.strategy] = 1
    if card.expedition and progress.region != GameTypes.Region.LEGACY:
        var index: int = deposit_index(card)
        progress.deposits[index] = maxi(0, progress.deposits[index] - crew_size(state, card))


static func summary(state: VillageState, card: CardDefinition) -> String:
    var result: String = (
        "烦躁 %d / 5 · %s" % [state.progress.frustration, GameTypes.LABOR_NAMES[card.labor]]
    )
    var after: int = clampi(
        (
            state.progress.frustration
            + card.mood_delta
            + mood_gain(state, card)
            - (mini(3, state.progress.frustration) if card.vent else 0)
        ),
        0,
        5
    )
    if after != state.progress.frustration:
        result += " · 执行后烦躁 %d→%d" % [state.progress.frustration, after]
    if card.labor != GameTypes.Labor.NONE:
        result += " · 情绪/事件体力 ×%.2f" % cost_multiplier(state, card)
    if card.expedition:
        result += " · 出队 %d 人" % crew_size(state, card)
        if state.progress.region != GameTypes.Region.LEGACY:
            result += " · 资源点剩余 %d 份" % state.progress.deposits[deposit_index(card)]
    if renewable_fallback(state, card):
        result += " · 资源点枯竭，基础采集仅提供 2 份补给"
    if card.vent:
        result += (
			" · 消耗 %d 烦躁，今晚攻击 +%d%%"
            % [mini(3, state.progress.frustration), mini(3, state.progress.frustration) * 8]
        )
    return result


static func renewable_fallback(state: VillageState, card: CardDefinition) -> bool:
    return (
        state.progress.region != GameTypes.Region.LEGACY
        and card.expedition
        and card.id in ["forage", "water"]
        and state.progress.deposits[deposit_index(card)] == 0
    )


static func mood_gain(state: VillageState, card: CardDefinition) -> int:
    if card.vent or not repeating(state, card):
        return 0
    var event: DailyEvent = event_for(state)
    return (
        2
        if (
            event != null
            and state.progress.event_choice == 0
            and event.low_mood
            and not state.progress.low_mood_used
        )
        else 1
    )
