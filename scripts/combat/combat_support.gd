class_name CombatSupport
extends RefCounted
## 夜战持有独立耗材预算，辅助行为与伤亡不会写回白天模型。

var supplies: PackedInt32Array = []
var consumed: PackedInt32Array = []


func initialize(stats: VillageStats) -> void:
	supplies = stats.supplies.duplicate()
	supplies.resize(GameTypes.Stock.COUNT)
	consumed.resize(GameTypes.Stock.COUNT)
	consumed.fill(0)


func configure(
	guard: CombatActor,
	person: SurvivorRecord,
	stats: VillageStats,
	rules: ProgressionRules,
	bows: bool
) -> void:
	guard.person_id = person.id
	guard.unit = kind_for(person, bows)
	var definition: UnitDefinition = rules.units[guard.unit]
	guard.hp *= definition.health_multiplier
	guard.max_hp = guard.hp
	guard.attack_range = (
		minf(stats.attack_range, definition.range_limit) * definition.range_multiplier
	)
	guard.attack_multiplier = definition.attack_multiplier
	guard.speed_multiplier = definition.speed_multiplier


func spend(key: GameTypes.Stock, amount: int = 1) -> bool:
	if supplies[key] < amount:
		return false
	supplies[key] -= amount
	consumed[key] += amount
	return true


func update(simulation: BattleSimulation, delta: float) -> void:
	for guard: CombatActor in simulation.guards:
		if guard.hp <= 0:
			continue
		guard.support_timer -= delta
		if guard.support_timer > 0:
			continue
		guard.support_timer = (
			simulation.state.catalog.library.progression_rules.units[guard.unit].support_interval
		)
		match guard.unit:
			GameTypes.Unit.MEDIC:
				_heal(guard, simulation)
			GameTypes.Unit.REPAIRER:
				_repair(guard, simulation)
			GameTypes.Unit.ENGINEER:
				if (
					simulation.core_health < simulation.state.core_max_health
					and guard.pos.distance_to(WorldLayout.CENTER) < 110
					and spend(GameTypes.Stock.PARTS)
				):
					simulation.core_health = minf(
						simulation.state.core_max_health, simulation.core_health + 8
					)


func visible(enemy: CombatActor, observer: CombatActor, simulation: BattleSimulation) -> bool:
	if enemy.kind != GameTypes.Enemy.LURKER:
		return true
	if (
		enemy.pos.distance_to(observer.pos)
		< (140.0 if observer.unit == GameTypes.Unit.SCOUT else 42.0)
	):
		return true
	var light_range: float = (
		240.0 if simulation.stats.lights_active else 115.0 if simulation.stats.torch else 0.0
	)
	return enemy.pos.distance_to(WorldLayout.CENTER) < light_range


func target_for(guard: CombatActor, simulation: BattleSimulation) -> CombatActor:
	var target: CombatActor = null
	var best: float = INF
	for enemy: CombatActor in simulation.enemies:
		if (
			enemy.hp <= 0
			or (simulation.stats.modern_combat and not visible(enemy, guard, simulation))
		):
			continue
		var priority: float = 1.0
		if (
			guard.unit in [GameTypes.Unit.ARCHER, GameTypes.Unit.SCOUT]
			and enemy.kind in [GameTypes.Enemy.SCREAMER, GameTypes.Enemy.SPITTER]
		):
			priority = 0.65
		var score: float = guard.pos.distance_to(enemy.pos) * priority
		if score < best:
			best = score
			target = enemy
	return target


func shoot(
	guard: CombatActor, target: CombatActor, distance: float, simulation: BattleSimulation
) -> bool:
	var bow: bool = simulation.state.buildings[GameTypes.Building.BOWS] > 0
	if simulation.stats.modern_combat:
		bow = guard.unit == GameTypes.Unit.ARCHER and spend(GameTypes.Stock.ARROWS)
		if guard.unit == GameTypes.Unit.ARCHER and not bow:
			guard.attack_range = 66.0
			if distance > guard.attack_range:
				return false
	var attack: float = simulation.stats.attack * guard.attack_multiplier
	if simulation.stats.modern_combat and guard.unit == GameTypes.Unit.ARCHER and not bow:
		attack *= 0.6
	simulation.projectiles.append(
		ProjectileState.new(guard.pos + Vector2(0, -9), target, attack, bow)
	)
	guard.cooldown = simulation.stats.cooldown
	guard.flash = 0.15
	return true


static func kind_for(person: SurvivorRecord, bows: bool) -> GameTypes.Unit:
	match person.profession:
		GameTypes.Profession.GATHERER:
			return GameTypes.Unit.SCOUT
		GameTypes.Profession.BUILDER:
			return GameTypes.Unit.REPAIRER
		GameTypes.Profession.ENGINEER:
			return GameTypes.Unit.ENGINEER
		GameTypes.Profession.MEDIC:
			return GameTypes.Unit.MEDIC
		GameTypes.Profession.GUARD:
			return GameTypes.Unit.ARCHER if bows and person.archer else GameTypes.Unit.SPEAR
	return GameTypes.Unit.VILLAGER


func _heal(medic: CombatActor, simulation: BattleSimulation) -> void:
	var target: CombatActor = null
	var lowest: float = 0.7
	for guard: CombatActor in simulation.guards:
		if (
			guard.hp > 0
			and medic.pos.distance_to(guard.pos) < 100
			and guard.hp / guard.max_hp < lowest
		):
			target = guard
			lowest = guard.hp / guard.max_hp
	if target != null and spend(GameTypes.Stock.MEDICINE):
		target.hp = minf(target.max_hp, target.hp + 22)
		simulation.particles.append(CombatParticle.new(target.pos, 1.0, Color("9be2bd"), "+22"))


func _repair(builder: CombatActor, simulation: BattleSimulation) -> void:
	for cell: Vector2i in simulation.walls:
		var wall: WallSegment = simulation.walls[cell]
		if (
			wall.hp > 0
			and wall.hp < wall.max_hp
			and builder.pos.distance_to(WorldLayout.to_point(cell)) < 75
		):
			if spend(GameTypes.Stock.WOOD):
				wall.hp = minf(wall.max_hp, wall.hp + 18)
			return
