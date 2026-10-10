class_name WorkforceRules
extends Resource
## 人口行动预算与职业效率配置；查询和名册调整不修改输入集合。

@export_range(1, 100) var people_per_action: int = 5
@export_range(1, 10) var max_actions_per_slot: int = 4
@export_range(1.0, 3.0) var missing_profession_multiplier: float = 1.5
@export_range(0.0, 0.5) var reduction_per_extra_worker: float = 0.1
@export_range(0.1, 1.0) var minimum_multiplier: float = 0.6
@export var initial_roster: PackedInt32Array = [0, 1, 1, 1, 1, 1]


func validation_error() -> String:
	if people_per_action < 1 or max_actions_per_slot < 1 or max_actions_per_slot > 10:
		return "人口行动配置非法"
	if not is_finite(missing_profession_multiplier) or missing_profession_multiplier < 1.0:
		return "缺少职业的体力倍率非法"
	if not is_finite(reduction_per_extra_worker) or reduction_per_extra_worker < 0.0:
		return "职业减耗配置非法"
	if not is_finite(minimum_multiplier) or minimum_multiplier <= 0.0 or minimum_multiplier > 1.0:
		return "职业最低体力倍率非法"
	if not valid_roster(initial_roster, 5):
		return "初始职业人数必须合计为 5"
	return ""


func action_capacity(population: int) -> int:
	return clampi(int(population / float(people_per_action)), 1, max_actions_per_slot)


func stamina_multiplier(profession: GameTypes.Profession, roster: PackedInt32Array) -> float:
	if profession == GameTypes.Profession.GENERAL:
		return 1.0
	var workers: int = roster[profession]
	if workers == 0:
		return missing_profession_multiplier
	return maxf(minimum_multiplier, 1.0 - (workers - 1) * reduction_per_extra_worker)


func valid_roster(roster: PackedInt32Array, population: int) -> bool:
	if roster.size() != GameTypes.Profession.COUNT:
		return false
	var total: int = 0
	for count: int in roster:
		if count < 0 or count > population:
			return false
		total += count
	return total == population


## 新人依次补充人数最少的专业；战损从人数最多的职业扣除，同人数按枚举顺序。
func resized_roster(roster: PackedInt32Array, population: int) -> PackedInt32Array:
	var result: PackedInt32Array = roster.duplicate()
	if result.size() != GameTypes.Profession.COUNT:
		result = initial_roster.duplicate()
	var total: int = 0
	for count: int in result:
		total += count
	while total != population:
		var selected: int = 1 if total < population else 0
		for profession: int in range(selected + 1, result.size()):
			if (
				(total < population and result[profession] < result[selected])
				or (total > population and result[profession] > result[selected])
			):
				selected = profession
		result[selected] += 1 if total < population else -1
		total += 1 if total < population else -1
	return result
