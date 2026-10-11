class_name KeywordRules
extends RefCounted
## 关键词准入查询；只读取状态，分类、奖励与执行共享卡牌定义。


static func requirement_error(state: VillageState, keyword: KeywordDefinition) -> String:
	match keyword.category:
		KeywordDefinition.Category.PROFESSION:
			if state.profession_counts[keyword.profession] < keyword.minimum_count:
				return "需要至少 %d 名%s" % [keyword.minimum_count, keyword.title]
		KeywordDefinition.Category.TERRAIN:
			if keyword.discovery >= 0:
				if not state.progress.discoveries.has(keyword.discovery):
					return "尚未发现%s" % keyword.title
			else:
				for value: int in state.progress.explored_cells:
					if value == TerrainGrid.index(TerrainGrid.CAMP):
						continue
					if state.terrain_grid.biome(TerrainGrid.position(value)) == keyword.biome:
						return ""
				return "尚未发现%s" % keyword.title
	return ""


static func card_error(card: CardDefinition) -> String:
	var ids: Dictionary[String, bool] = {}
	var has_worker: bool = card.profession == GameTypes.Profession.GENERAL
	for keyword: KeywordDefinition in card.keywords:
		if keyword == null:
			return "卡牌词条为空"
		var error: String = keyword.validation_error()
		if not error.is_empty():
			return error
		if ids.has(keyword.id):
			return "卡牌词条重复"
		ids[keyword.id] = true
		if keyword.category == KeywordDefinition.Category.PROFESSION:
			if keyword.profession == card.profession:
				has_worker = true
	return "" if has_worker else "执行职业必须在人物前置词条中声明"


static func requirement_text(keyword: KeywordDefinition) -> String:
	match keyword.category:
		KeywordDefinition.Category.PROFESSION:
			return "人物：%s ≥ %d 人" % [keyword.title, keyword.minimum_count]
		KeywordDefinition.Category.TERRAIN:
			return "地形：已发现" + keyword.title
	return ""


static func registered_error(card: CardDefinition, library: KeywordLibrary) -> String:
	for keyword: KeywordDefinition in card.keywords:
		if not library.definitions.has(keyword):
			return "卡牌引用未注册词条：" + keyword.id
	return ""
