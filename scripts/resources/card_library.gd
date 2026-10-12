class_name CardLibrary
extends Resource

@export var keyword_library: KeywordLibrary

@export var progression_rules: ProgressionRules

@export var weather_rules: WeatherRules

@export var workforce_rules: WorkforceRules

@export var cards: Array[CardDefinition] = []
@export var buildings: Array[BuildingDefinition] = []
@export var starting_cards: Array[CardDefinition] = []
