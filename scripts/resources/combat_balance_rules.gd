class_name CombatBalanceRules
extends Resource
## 敌人基础能力与压力增益；调节难度不改固定步长或按日期线性加怪。

@export var enemy_health: float = 24.0
@export var pressure_health: float = 12.0
@export var enemy_damage: float = 3.0
@export var pressure_damage: float = 3.0
@export var enemy_speed: float = 24.0
@export var pressure_speed: float = 7.0
@export var spawn_interval_low: float = 1.7
@export var spawn_interval_high: float = 0.8
@export var attack_interval: float = 1.4
@export var boss_attack_interval: float = 1.7
@export var wall_damage_multiplier: float = 1.4


func validation_error() -> String:
	for value: float in [enemy_health, enemy_damage, enemy_speed, spawn_interval_low,
		spawn_interval_high, attack_interval, boss_attack_interval, wall_damage_multiplier]:
		if not is_finite(value) or value <= 0.0:
			return "战斗基础参数非法"
	for value: float in [pressure_health, pressure_damage, pressure_speed]:
		if not is_finite(value) or value < 0.0:
			return "战斗压力增益非法"
	return "" if spawn_interval_high <= spawn_interval_low else "高压力入场间隔不能更长"
