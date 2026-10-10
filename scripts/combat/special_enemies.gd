class_name SpecialEnemies
extends RefCounted
## 特殊威胁采用有限召援与有期限区域，所有单位留在模拟器集合内。

var hazards: Array[CombatHazard] = []
var summons: int = 0


func types_for(day: int, region: GameTypes.Region) -> PackedInt32Array:
	if day < 3:
		return []
	var types: PackedInt32Array = [GameTypes.Enemy.ARMORED, GameTypes.Enemy.LURKER]
	if day >= 5:
		types = [GameTypes.Enemy.SPITTER, GameTypes.Enemy.SCREAMER]
	if day >= 8:
		types = [GameTypes.Enemy.BURNER, GameTypes.Enemy.ARMORED]
	if region == GameTypes.Region.MOUNTAIN and day >= 5:
		types[0] = GameTypes.Enemy.LURKER
	return types


func update(simulation: BattleSimulation, delta: float) -> void:
	for enemy: CombatActor in simulation.enemies:
		if enemy.hp <= 0:
			continue
		var definition: EnemyDefinition = (
			simulation.state.catalog.library.progression_rules.enemies[enemy.kind]
		)
		if enemy.kind in [GameTypes.Enemy.SCREAMER, GameTypes.Enemy.BOSS]:
			enemy.support_timer -= delta
			if enemy.support_timer <= 0 and enemy.summons < definition.summon_limit and summons < 4:
				enemy.support_timer = definition.summon_interval
				enemy.summons += 1
				summons += 1
				simulation.total_to_spawn += 1
	for index: int in range(hazards.size() - 1, -1, -1):
		var hazard: CombatHazard = hazards[index]
		var exposure: float = minf(delta, maxf(0.0, hazard.life))
		hazard.life -= delta
		for guard: CombatActor in simulation.guards:
			if guard.pos.distance_to(hazard.pos) < hazard.radius:
				guard.hp -= hazard.damage * exposure
		_damage_walls(simulation, hazard, exposure)
		if hazard.pos.distance_to(WorldLayout.CENTER) < 65:
			simulation.core_health -= hazard.damage * exposure
		if hazard.life <= 0:
			hazards.remove_at(index)


func add_hazard(point: Vector2, radius: float = 40.0) -> void:
	var hazard: CombatHazard = CombatHazard.new()
	hazard.pos = point
	hazard.radius = radius
	hazards.append(hazard)


func _damage_walls(simulation: BattleSimulation, hazard: CombatHazard, delta: float) -> void:
	for cell: Vector2i in simulation.walls:
		var wall: WallSegment = simulation.walls[cell]
		if wall.hp <= 0 or WorldLayout.to_point(cell).distance_to(hazard.pos) > hazard.radius:
			continue
		wall.hp = maxf(0.0, wall.hp - hazard.damage * delta)
		if wall.hp <= 0:
			simulation.guard_grid.set_point_solid(cell, false)
			simulation.enemy_grid.set_point_weight_scale(cell, 1.0)
