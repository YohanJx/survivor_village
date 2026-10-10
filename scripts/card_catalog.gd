class_name CardCatalog
extends RefCounted
## 仅在整个资源库通过校验后发布索引；无效目录保持空且不能开局。

var library: CardLibrary
var cards: Dictionary[String, CardDefinition] = {}
var buildings: Array[BuildingDefinition] = []
var is_valid: bool = false
var validation_error: String = ""


func _init(source: CardLibrary = null, use_default: bool = true) -> void:
	var candidate: CardLibrary = source
	if candidate == null and use_default:
		candidate = load("res://data/card_library.tres") as CardLibrary
	validation_error = ResourceValidation.library_error(candidate)
	if not validation_error.is_empty():
		return
	buildings.resize(GameTypes.Building.COUNT)
	for building: BuildingDefinition in candidate.buildings:
		buildings[building.id] = building
	for card: CardDefinition in candidate.cards:
		cards[card.id] = card
	library = candidate
	is_valid = true


func get_card(id: String) -> CardDefinition:
	return cards.get(id)


func cost_text(card: CardDefinition, state: VillageState = null) -> String:
	var parts: PackedStringArray = []
	var totals: PackedInt32Array = EffectResolver.cost_totals(card, state)
	for key: int in GameTypes.Stock.COUNT:
		if totals[key] > 0:
			parts.append("%s %d" % [GameTypes.STOCK_NAMES[key], totals[key]])
	return " · ".join(parts) if not parts.is_empty() else "无资源消耗"


func requirement_text(card: CardDefinition) -> String:
	var parts: PackedStringArray = []
	for requirement: BuildingRequirement in card.prerequisites:
		parts.append("%s Lv.%d" % [requirement.building.display_name, requirement.level])
	return "、".join(parts)
