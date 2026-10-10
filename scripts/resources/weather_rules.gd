class_name WeatherRules
extends Resource
## 天气使用独立的种子/日期序列；不会消耗奖励或战斗的随机数。

const SEED_OFFSET: int = 73129
const DAY_STRIDE: int = 104729
const PERIOD_COUNT: int = 4

@export var definitions: Array[WeatherDefinition] = []
@export var ground_colors: PackedColorArray = []
@export var background_colors: PackedColorArray = []
@export var light_colors: PackedColorArray = []


func for_kind(kind: WeatherDefinition.Kind) -> WeatherDefinition:
	for definition: WeatherDefinition in definitions:
		if definition.kind == kind:
			return definition
	return null


func for_day(run_seed: int, day: int) -> WeatherDefinition:
	# 第一天保留晴朗，让玩家先熟悉基础经营；其后按权重抽取。
	if day <= 1:
		return for_kind(WeatherDefinition.Kind.CLEAR)
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = run_seed ^ (day * DAY_STRIDE + SEED_OFFSET)
	var total: int = 0
	for definition: WeatherDefinition in definitions:
		total += definition.weight
	var roll: int = generator.randi_range(0, total - 1)
	for definition: WeatherDefinition in definitions:
		roll -= definition.weight
		if roll < 0:
			return definition
	return null


func validation_error() -> String:
	var kinds: Dictionary[int, bool] = {}
	for definition: WeatherDefinition in definitions:
		if definition == null:
			return "天气配置为空"
		var error: String = definition.validation_error()
		if not error.is_empty():
			return error
		if kinds.has(definition.kind):
			return "天气枚举重复"
		kinds[definition.kind] = true
	if kinds.size() != WeatherDefinition.Kind.COUNT:
		return "天气配置不完整"
	if (
		ground_colors.size() != PERIOD_COUNT
		or background_colors.size() != PERIOD_COUNT
		or light_colors.size() != PERIOD_COUNT
	):
		return "四时段色板不完整"
	for index: int in PERIOD_COUNT:
		if (
			not WeatherDefinition.valid_color(ground_colors[index])
			or not WeatherDefinition.valid_color(background_colors[index])
			or not WeatherDefinition.valid_color(light_colors[index])
		):
			return "时段色板非法"
	return ""
