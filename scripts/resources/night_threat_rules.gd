class_name NightThreatRules
extends Resource
## 有上限、边际递减的威胁配置；日期不直接增加数量或敌人属性。

@export_range(0, 30) var base_budget: int = 8
@export_range(1, 100) var exploration_weight: int = 12
@export_range(1, 100) var development_weight: int = 16
@export_range(1, 100) var noise_weight: int = 16
@export_range(1, 100) var pollution_weight: int = 8
@export_range(1, 100) var exploration_half: int = 12
@export_range(1, 100) var development_half: int = 8
@export_range(1, 100) var noise_half: int = 24
@export_range(1, 100) var pollution_half: int = 35
@export_range(1, 500) var pollution_cap: int = 100
@export_range(0, 30) var conceal_noise_limit: int = 6
@export_range(0, 30) var conceal_exploration_limit: int = 9
@export_range(0, 30) var conceal_development_limit: int = 3
@export_range(0.1, 1.0) var conceal_multiplier: float = 0.55
@export_range(1, 200) var boss_budget: int = 34
@export_range(1, 100) var boss_development: int = 10
@export_range(0.0, 1.0) var boss_chance: float = 0.25
