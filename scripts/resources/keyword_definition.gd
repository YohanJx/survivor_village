class_name KeywordDefinition
extends Resource
## 稳定词条定义：主题只分类和解释，地形与人物同时构成卡牌前置。

enum Category {
	TOPIC,
	TERRAIN,
	PROFESSION,
}

const CATEGORY_NAMES: PackedStringArray = ["主题", "地形", "人物"]

@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.TOPIC
@export_multiline var description: String = ""
@export var discovery: int = -1
@export var biome: int = -1
@export var profession: GameTypes.Profession = GameTypes.Profession.GENERAL
@export_range(1, 999) var minimum_count: int = 1


func validation_error() -> String:
	if id.is_empty() or title.is_empty() or description.is_empty():
		return "词条缺少标识、名称或解释"
	if category < Category.TOPIC or category > Category.PROFESSION:
		return "词条分类非法"
	if minimum_count < 1 or minimum_count > 999:
		return "词条要求数量非法"
	match category:
		Category.TERRAIN:
			if not (
				(discovery >= 0 and discovery < GameTypes.Discovery.COUNT and biome == -1)
				or (biome >= 0 and biome < TerrainGrid.Biome.COUNT and discovery == -1)
			):
				return "地形词条必须指定一种有效发现或地貌"
			if profession != GameTypes.Profession.GENERAL or minimum_count != 1:
				return "地形词条不能配置职业或人数"
		Category.PROFESSION:
			if (
				profession <= GameTypes.Profession.GENERAL
				or profession >= GameTypes.Profession.COUNT
			):
				return "人物词条必须指定专业职业"
			if discovery != -1 or biome != -1:
				return "人物词条不能配置地形"
		Category.TOPIC:
			if discovery != -1 or biome != -1 or profession != GameTypes.Profession.GENERAL:
				return "主题词条不能隐含前置"
			if minimum_count != 1:
				return "主题词条不能配置人数"
	return ""
