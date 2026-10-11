class_name CardLibrary
extends Resource

@export var keyword_library: KeywordLibrary = preload("res://data/ui/keywords.tres")

@export var progression_rules: ProgressionRules = preload("res://data/progression_rules.tres")

@export var weather_rules: WeatherRules

@export var workforce_rules: WorkforceRules = preload("res://data/workforce_rules.tres")

@export var cards: Array[CardDefinition] = []
@export var buildings: Array[BuildingDefinition] = []
@export var starting_cards: Array[CardDefinition] = []
