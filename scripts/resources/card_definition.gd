class_name CardDefinition
extends Resource

enum Kind {
	ACTION = 0,
	BUILDING = 1,
	TECHNOLOGY = 2,
	EVENT = 3,
}
const KIND_NAMES: PackedStringArray = ["行动", "建造", "科技", "事件"]

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.ACTION
@export var icon: GameTypes.Icon = GameTypes.Icon.LEAF
@export var color: GameTypes.Palette = GameTypes.Palette.GREEN
@export_multiline var description: String = ""
@export_multiline var positive: String = ""
@export_multiline var negative: String = ""
@export var keywords: Array[KeywordDefinition] = []
@export var reusable: bool = false
@export var profession: GameTypes.Profession = GameTypes.Profession.GENERAL
@export var labor: GameTypes.Labor = GameTypes.Labor.NONE
@export var expedition: bool = false
@export var crew_stamina: int = 0
@export var crew_water: int = 0
@export var crew_output: int = 0
@export var mood_delta: int = 0
@export var reset_labor: bool = false
@export var vent: bool = false
@export var strategy: GameTypes.Strategy = GameTypes.Strategy.NONE
@export var regions: PackedInt32Array = []
@export var required_cards: PackedStringArray = []
@export var guaranteed_unlock: bool = false
@export var costs: Array[ResourceCost] = []
@export var prerequisites: Array[BuildingRequirement] = []
@export var effects: Array[CardEffect] = []
@export var building: BuildingDefinition


func kind_name() -> String:
	return KIND_NAMES[kind]


func keyword_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for keyword: KeywordDefinition in keywords:
		names.append(keyword.title)
	return names
