class_name ResourceValidation
extends RefCounted
## 校验配置完整对象图；返回空字符串表示有效，不修改输入资源。


static func modifier_error(modifier: StatModifier, runtime: bool = false) -> String:
	if modifier == null:
		return "修正器为空"
	if modifier.key < 0 or modifier.key >= GameTypes.Stat.COUNT:
		return "修正器属性枚举非法"
	if modifier.operation not in [StatModifier.Operation.ADD, StatModifier.Operation.MULTIPLY]:
		return "修正器操作非法"
	if not is_finite(modifier.amount):
		return "修正器数值必须有限"
	if modifier.operation == StatModifier.Operation.MULTIPLY and modifier.amount <= 0:
		return "修正器倍率必须大于零"
	if modifier.duration < 0 or modifier.duration > 99:
		return "修正器持续时间非法"
	if runtime and (modifier.remaining <= 0 or modifier.remaining > modifier.duration):
		return "运行时修正器剩余时间非法"
	if not runtime and (modifier.remaining != 0 or not modifier.source.is_empty()):
		return "共享修正器含运行时状态"
	return ""


static func library_error(library: CardLibrary) -> String:
	if library == null:
		return "缺少卡牌库资源"
	if library.weather_rules == null:
		return "缺少天气规则资源"
	var weather_error: String = library.weather_rules.validation_error()
	if not weather_error.is_empty():
		return weather_error
	if library.workforce_rules == null:
		return "缺少职业规则资源"
	var workforce_error: String = library.workforce_rules.validation_error()
	if not workforce_error.is_empty():
		return workforce_error
	var buildings: Array[BuildingDefinition] = []
	buildings.resize(GameTypes.Building.COUNT)
	for building: BuildingDefinition in library.buildings:
		if building == null or building.id < 0 or building.id >= buildings.size():
			return "建筑为空或枚举非法"
		if buildings[building.id] != null:
			return "重复建筑：" + building.display_name
		buildings[building.id] = building
	if buildings.has(null):
		return "建筑枚举注册不完整"
	var layout_error: String = _buildings_error(buildings)
	if not layout_error.is_empty():
		return layout_error
	var cards: Dictionary[String, CardDefinition] = {}
	for card: CardDefinition in library.cards:
		var error: String = card_error(card, buildings)
		if not error.is_empty():
			return "%s：%s" % [card.id if card != null else "空卡牌", error]
		if cards.has(card.id):
			return "重复卡牌 ID：" + card.id
		cards[card.id] = card
	if cards.is_empty() or library.starting_cards.is_empty():
		return "卡牌库或初始手牌为空"
	for card: CardDefinition in library.starting_cards:
		if card == null or cards.get(card.id) != card:
			return "初始手牌未引用库中的卡牌"
	var progression_error: String = ProgressionValidation.rules_error(
		library.progression_rules, buildings
	)
	return progression_error if not progression_error.is_empty() else _technology_error(library)


static func card_error(card: CardDefinition, buildings: Array[BuildingDefinition]) -> String:
	if card == null or card.id.strip_edges().is_empty() or card.display_name.is_empty():
		return "缺少卡牌或标识/名称"
	if card.kind < 0 or card.kind >= CardDefinition.KIND_NAMES.size():
		return "卡牌分类非法"
	if card.profession < 0 or card.profession >= GameTypes.Profession.COUNT:
		return "卡牌职业非法"
	if (
		card.labor < 0
		or card.labor >= GameTypes.Labor.COUNT
		or card.strategy < 0
		or card.strategy >= GameTypes.Strategy.COUNT
	):
		return "劳动或策略枚举非法"
	if (
		card.crew_stamina < 0
		or card.crew_water < 0
		or card.crew_output < 0
		or abs(card.mood_delta) > 5
	):
		return "队伍或情绪参数非法"
	for region: int in card.regions:
		if region < 0 or region >= GameTypes.Region.COUNT:
			return "地图限定非法"
	if card.icon < 0 or card.icon > GameTypes.Icon.BOX:
		return "卡牌图标非法"
	if card.color < 0 or card.color > GameTypes.Palette.RED:
		return "卡牌颜色非法"
	if card.positive.is_empty() or card.negative.is_empty() or card.effects.is_empty():
		return "缺少正负效果说明或效果"
	if card.building != null and not _registered(card.building, buildings):
		return "展示建筑未注册"
	for cost: ResourceCost in card.costs:
		if cost == null or cost.key < 0 or cost.key >= GameTypes.Stock.COUNT:
			return "费用为空或资源枚举非法"
		if cost.amount < 0 or cost.amount > GameTypes.STOCK_LIMITS[cost.key]:
			return "费用超出合法范围"
	for requirement: BuildingRequirement in card.prerequisites:
		if requirement == null or not _registered(requirement.building, buildings):
			return "前置引用未注册建筑"
		if requirement.level < 1 or requirement.level > requirement.building.max_level:
			return "前置等级超出上限"
	for effect: CardEffect in card.effects:
		var error: String = _effect_error(effect, buildings)
		if not error.is_empty():
			return error
	return ""


static func _registered(building: BuildingDefinition, buildings: Array[BuildingDefinition]) -> bool:
	return (
		building != null
		and building.id >= 0
		and building.id < buildings.size()
		and buildings[building.id] == building
	)


static func _effect_error(effect: CardEffect, buildings: Array[BuildingDefinition]) -> String:
	if effect == null or effect.type < 0 or effect.type > CardEffect.Type.POPULATION:
		return "效果为空或类型非法"
	if not is_finite(effect.amount):
		return "效果数值必须有限"
	if effect.required_building != null and not _registered(effect.required_building, buildings):
		return "条件建筑未注册"
	if effect.type != CardEffect.Type.BUILD and effect.building != null:
		return "非建造效果携带建筑字段"
	if effect.type != CardEffect.Type.MODIFIER and effect.modifier != null:
		return "非修正效果携带修正器字段"
	match effect.type:
		CardEffect.Type.RESOURCE:
			if effect.key < 0 or effect.key >= GameTypes.Stock.COUNT:
				return "效果资源枚举非法"
			if effect.amount != floor(effect.amount) or absf(effect.amount) > 999:
				return "资源效果必须是范围内整数"
		CardEffect.Type.BUILD:
			if not _registered(effect.building, buildings):
				return "建造效果缺少已注册建筑"
			if effect.amount < 1 or effect.amount > effect.building.max_level:
				return "建造等级增量非法"
			if effect.amount != floor(effect.amount):
				return "建造等级必须为整数"
		CardEffect.Type.MODIFIER:
			var error: String = modifier_error(effect.modifier)
			if not error.is_empty():
				return error
			if effect.modifier.duration == 0:
				return "卡牌修正器需要有效持续时间"
		CardEffect.Type.HEAL:
			if effect.amount < 0:
				return "修复量不能为负"
		CardEffect.Type.POPULATION:
			if effect.amount != floor(effect.amount) or absf(effect.amount) > 99:
				return "人口变化必须是范围内整数"
	return ""


static func _buildings_error(buildings: Array[BuildingDefinition]) -> String:
	var footprints: Array[Rect2i] = []
	var grid: Rect2i = Rect2i(Vector2i.ZERO, WorldLayout.GRID)
	for building: BuildingDefinition in buildings:
		if building.display_name.is_empty() or building.max_level < 1 or building.max_level > 10:
			return "建筑名称或等级非法"
		for modifier: StatModifier in building.modifiers:
			var error: String = modifier_error(modifier)
			if not error.is_empty():
				return building.display_name + "：" + error
		if building.production != null and not _valid_production(building.production):
			return building.display_name + "：产出配置非法"
		if building.synergy != null:
			var error: String = building.synergy.configuration_error()
			if not error.is_empty():
				return building.display_name + "：" + error
		if not building.visible_on_map:
			continue
		var area: Rect2i = building.footprint
		if area.size.x <= 0 or area.size.y <= 0 or not grid.encloses(area):
			return building.display_name + "：占地越界或为空"
		footprints.append(area)
	# 第二间初始住屋也属于固定地图布局。
	footprints.append(WorldLayout.EXTRA_HUT)
	for i: int in footprints.size():
		for j: int in range(i + 1, footprints.size()):
			if footprints[i].intersects(footprints[j]):
				return "建筑占地重叠"
		for cell: Vector2i in WorldLayout.wall_cells() + WorldLayout.gate_cells():
			if footprints[i].has_point(cell):
				return "建筑占地阻塞围墙或入口"
	return ""


static func _valid_production(flow: ProductionProfile) -> bool:
	for value: int in [
		flow.food,
		flow.water,
		flow.power,
		flow.materials,
		flow.food_upkeep,
		flow.water_upkeep,
		flow.materials_upkeep,
		flow.noise,
		flow.pollution,
	]:
		if value < 0 or value > 99:
			return false
	return true


static func _technology_error(library: CardLibrary) -> String:
	var reachable: PackedInt32Array = []
	reachable.resize(GameTypes.Building.COUNT)
	# 按前置等级求不动点；纯循环技术链不会被标记为可达。
	for iteration: int in GameTypes.Building.COUNT * 10:
		var changed: bool = false
		for card: CardDefinition in library.cards:
			var eligible: bool = true
			for requirement: BuildingRequirement in card.prerequisites:
				if reachable[requirement.building.id] < requirement.level:
					eligible = false
			if not eligible:
				continue
			for effect: CardEffect in card.effects:
				if effect.type != CardEffect.Type.BUILD:
					continue
				if effect.required_building != null and reachable[effect.required_building.id] == 0:
					continue
				var id: int = effect.building.id
				if reachable[id] < effect.building.max_level:
					reachable[id] = mini(
						effect.building.max_level, reachable[id] + int(effect.amount)
					)
					changed = true
		if not changed:
			break
	for card: CardDefinition in library.cards:
		for requirement: BuildingRequirement in card.prerequisites:
			if reachable[requirement.building.id] < requirement.level:
				return "不可达技术前置：" + card.id
		for effect: CardEffect in card.effects:
			if effect.required_building != null and reachable[effect.required_building.id] == 0:
				return "不可达条件建筑：" + card.id
	return ""
