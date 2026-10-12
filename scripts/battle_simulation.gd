class_name BattleSimulation
extends RefCounted

signal finished(report: BattleReport)

const FIXED_STEP_SECONDS: float = 1.0 / 30.0
const MAX_DURATION_SECONDS: float = 180.0
var state: VillageState
var stats: VillageStats
var guards: Array[CombatActor] = []
var enemies: Array[CombatActor] = []
var walls: Dictionary[Vector2i, WallSegment] = {}
var projectiles: Array[ProjectileState] = []
var particles: Array[CombatParticle] = []
var enemy_grid: AStarGrid2D = AStarGrid2D.new()
var guard_grid: AStarGrid2D = AStarGrid2D.new()
var active: bool = false
var elapsed: float = 0
var spawned: int = 0
var total_to_spawn: int = 0
var kills: int = 0
var core_health: float = 240
var boss_spawned: bool = false
var started_survivors: int = 0

var support: CombatSupport = CombatSupport.new()
var special: SpecialEnemies = SpecialEnemies.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_timer: float = 0
var _next_id: int = 0
var _terrain: Array[Vector2i] = []
var _buildings: Array[StructurePlacement] = []
var _boss_allowed: bool = false


func start(game_state: VillageState) -> void:
	state = game_state
	stats = state.night_stats.copy_snapshot()
	support.initialize(stats)
	special = SpecialEnemies.new()
	_rng.seed = state.run_seed + state.day * 901
	var threat_rules: NightThreatRules = state.catalog.library.progression_rules.night_threat
	var boss_chance: float = (
		threat_rules.boss_chance * (threat_rules.conceal_multiplier if stats.concealed else 1.0)
	)
	_boss_allowed = stats.boss_possible and _rng.randf() < boss_chance
	guards.clear()
	enemies.clear()
	walls.clear()
	projectiles.clear()
	particles.clear()
	elapsed = 0
	_spawn_timer = 0.8
	spawned = 0
	kills = 0
	_next_id = 0
	boss_spawned = false
	total_to_spawn = state.wave_count()
	started_survivors = state.population
	core_health = state.core_health
	_terrain = WorldLayout.terrain(state.terrain_grid)
	_buildings = WorldLayout.active_structures(state)
	_setup_navigation()
	for i: int in state.population:
		var point: Vector2 = _nearest_open(WorldLayout.guard_post(i, state.population), guard_grid)
		var guard: CombatActor = CombatActor.new()
		guard.id = i
		guard.pos = point
		guard.home_pos = point
		guard.hp = stats.health
		guard.max_hp = stats.health
		guard.attack_range = stats.attack_range
		if stats.modern_combat and i < stats.roster.size():
			support.configure(
				guard,
				stats.roster[i],
				stats,
				state.catalog.library.progression_rules,
				state.buildings[GameTypes.Building.BOWS] > 0
			)
		guard.cooldown = _rng.randf_range(0, 0.8)
		guards.append(guard)
	active = true


func step(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	_spawn_timer -= delta
	if spawned < total_to_spawn and _spawn_timer <= 0:
		_spawn_enemy()
		_spawn_timer = lerpf(1.5, 0.55, stats.threat_level)
	if stats.modern_combat:
		support.update(self, delta)
		special.update(self, delta)
	_update_guards(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	for i: int in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	for i: int in range(enemies.size() - 1, -1, -1):
		if enemies[i].hp <= 0:
			particles.append(CombatParticle.new(enemies[i].pos, 0.8, Color("8db776")))
			if enemies[i].kind == GameTypes.Enemy.BURNER:
				special.add_hazard(
					enemies[i].pos,
					state.catalog.library.progression_rules.enemies[enemies[i].kind].fire_radius
				)
			enemies.remove_at(i)
			kills += 1
	for i: int in range(guards.size() - 1, -1, -1):
		if guards[i].hp <= 0:
			particles.append(CombatParticle.new(guards[i].pos, 1.6, Color("ed947e"), "倒下"))
			guards.remove_at(i)
	if (
		core_health <= 0
		or guards.is_empty()
		or (spawned == total_to_spawn and enemies.is_empty() and special.hazards.is_empty())
	):
		_complete()
	# A hard limit protects the loop from an unreachable target or future AI regression.
	elif elapsed > MAX_DURATION_SECONDS:
		core_health = 0
		_complete()


## 查询射程和遮挡，无副作用；驻守选敌与执行使用同一准入。
func can_attack(guard: CombatActor, enemy: CombatActor) -> bool:
	return (
		guard.hp > 0
		and enemy.hp > 0
		and guard.pos.distance_to(enemy.pos) <= guard.attack_range
		and _clear_shot(guard.pos, enemy.pos)
	)


func _setup_navigation() -> void:
	for grid: AStarGrid2D in [enemy_grid, guard_grid]:
		grid.region = Rect2i(Vector2i.ZERO, WorldLayout.GRID)
		grid.cell_size = Vector2.ONE * WorldLayout.CELL
		grid.offset = Vector2.ONE * WorldLayout.CELL * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for cell: Vector2i in _terrain:
			grid.set_point_solid(cell, true)
		for building: StructurePlacement in _buildings:
			var rect: Rect2i = building.rect
			for x: int in range(rect.position.x, rect.end.x):
				for y: int in range(rect.position.y, rect.end.y):
					grid.set_point_solid(Vector2i(x, y), true)
	if state.buildings[GameTypes.Building.WALL] > 0:
		for cell: Vector2i in WorldLayout.wall_cells():
			var key: Vector2i = cell
			var hp: float = maxf(0, stats.wall_health - state.wall_damage.get(key, 0.0))
			walls[key] = WallSegment.new(cell, hp, stats.wall_health)
			guard_grid.set_point_solid(cell, hp > 0)
			enemy_grid.set_point_weight_scale(cell, 4.0 if hp > 0 else 1.0)
	# 路径的每个节点均在驻守区内，不能经门口绕出村庄。
	for x: int in WorldLayout.GRID.x:
		for y: int in WorldLayout.GRID.y:
			var cell: Vector2i = Vector2i(x, y)
			if not WorldLayout.DEFENSE_CELLS.has_point(cell):
				guard_grid.set_point_solid(cell, true)


func _spawn_enemy() -> void:
	var side: int = _rng.randi_range(0, 3)
	var point: Vector2
	match side:
		0:
			point = Vector2(12, _rng.randf_range(24, 552))
		1:
			point = Vector2(948, _rng.randf_range(24, 552))
		2:
			point = Vector2(_rng.randf_range(24, 936), 12)
		_:
			point = Vector2(_rng.randf_range(24, 936), 564)
	point = _nearest_open(point, enemy_grid)
	var kind: GameTypes.Enemy = GameTypes.Enemy.WALKER
	if _boss_allowed and not boss_spawned and spawned >= int(total_to_spawn * 0.4):
		kind = GameTypes.Enemy.BOSS
		boss_spawned = true
	elif stats.threat_level >= 0.55 and _rng.randf() < 0.14:
		kind = GameTypes.Enemy.BRUTE
	elif stats.threat_level >= 0.30 and _rng.randf() < 0.22:
		kind = GameTypes.Enemy.RUNNER
	if stats.modern_combat and kind != GameTypes.Enemy.BOSS:
		var types: PackedInt32Array = special.types_for(
			ceili(stats.threat_level * 10), state.progress.region
		)
		if not types.is_empty() and _rng.randf() < 0.18:
			kind = types[_rng.randi_range(0, types.size() - 1)] as GameTypes.Enemy
	var hp: float = 28 + stats.threat_level * 20.0
	var speed: float = 24.0 + stats.threat_level * 9.0
	var damage: float = 4.0 + stats.threat_level * 6.0
	match kind:
		GameTypes.Enemy.RUNNER:
			hp *= 0.7
			speed *= 1.85
		GameTypes.Enemy.BRUTE:
			hp *= 3
			speed *= 0.72
			damage *= 1.8
		GameTypes.Enemy.BOSS:
			hp = 270 + stats.threat_level * 126
			speed *= 0.68
			damage *= 3.5
	if stats.modern_combat:
		var definition: EnemyDefinition = state.catalog.library.progression_rules.enemies[kind]
		if total_to_spawn - spawned < definition.threat_cost:
			kind = GameTypes.Enemy.WALKER
			definition = state.catalog.library.progression_rules.enemies[kind]
		total_to_spawn -= definition.threat_cost - 1
		hp = (28 + stats.threat_level * 20.0) * definition.health_multiplier
		speed = (24.0 + stats.threat_level * 9.0) * definition.speed_multiplier
		damage = (4.0 + stats.threat_level * 6.0) * definition.damage_multiplier
	var enemy: CombatActor = CombatActor.new()
	enemy.id = _next_id
	enemy.pos = point
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.speed = speed
	enemy.damage = damage
	enemy.kind = kind
	enemies.append(enemy)
	_next_id += 1
	spawned += 1


func _update_guards(delta: float) -> void:
	for guard: CombatActor in guards:
		if guard.hp <= 0:
			continue
		guard.cooldown -= delta
		guard.flash = maxf(0, guard.flash - delta)
		# 自动守村固定岗位；目标超出射程或被遮挡时等待，不追击或退让。
		var target: CombatActor = support.target_for(guard, self)
		if target == null:
			continue
		var distance: float = guard.pos.distance_to(target.pos)
		guard.facing = (target.pos - guard.pos).normalized()
		if (
			distance <= guard.attack_range
			and _clear_shot(guard.pos, target.pos)
			and guard.cooldown <= 0
		):
			support.shoot(guard, target, distance, self)


func _update_enemies(delta: float) -> void:
	for enemy: CombatActor in enemies:
		if enemy.hp <= 0:
			continue
		enemy.cooldown -= delta
		enemy.repath -= delta
		enemy.flash = maxf(0, enemy.flash - delta)
		var target: CombatActor = null
		var nearest: float = 130.0
		for guard: CombatActor in guards:
			if guard.hp <= 0:
				continue
			var distance: float = enemy.pos.distance_to(guard.pos)
			if distance < nearest:
				nearest = distance
				target = guard
		var target_pos: Vector2 = (
			target.pos if target != null else WorldLayout.CENTER + Vector2(0, 36)
		)
		var attack_range: float = 25.0 if target != null else 49.0
		if stats.modern_combat and enemy.kind == GameTypes.Enemy.SPITTER and target != null:
			attack_range = state.catalog.library.progression_rules.enemies[enemy.kind].attack_range
		enemy.facing = (target_pos - enemy.pos).normalized()
		var move_speed: float = enemy.speed
		if stats.trap_damage > 0 and _in_trap_ring(enemy.pos):
			enemy.hp -= stats.trap_damage * delta
			move_speed *= 0.52
		if enemy.pos.distance_to(target_pos) <= attack_range and _clear_shot(enemy.pos, target_pos, true):
			if enemy.cooldown <= 0:
				if target == null:
					core_health -= enemy.damage
				else:
					target.hp -= enemy.damage
					target.flash = 0.18
					if enemy.kind == GameTypes.Enemy.SPITTER:
						special.add_hazard(target.pos)
				enemy.cooldown = 1.1 if enemy.kind != GameTypes.Enemy.BOSS else 1.4
		else:
			if enemy.repath <= 0:
				_request_path(enemy, target_pos, enemy_grid)
				enemy.repath = 0.9
			_move_along_path(enemy, move_speed * delta, true)


func _update_projectiles(delta: float) -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = projectiles[i]
		shot.life -= delta
		var target: CombatActor = shot.target
		if target == null or target.hp <= 0 or shot.life <= 0:
			projectiles.remove_at(i)
			continue
		shot.pos = shot.pos.move_toward(target.pos, 380 * delta)
		if shot.pos.distance_to(target.pos) < 10:
			var damage: float = shot.damage
			if stats.modern_combat and not (stats.piercing and shot.bow):
				damage = maxf(
					1.0, damage - state.catalog.library.progression_rules.enemies[target.kind].armor
				)
			target.hp -= damage
			target.flash = 0.12
			particles.append(
				CombatParticle.new(
					target.pos + Vector2(0, -18), 0.55, Color("edc988"), str(int(shot.damage))
				)
			)
			projectiles.remove_at(i)


func _request_path(actor: CombatActor, destination: Vector2, grid: AStarGrid2D) -> void:
	if grid == guard_grid:
		var first: Vector2 = WorldLayout.to_point(WorldLayout.DEFENSE_CELLS.position)
		var last: Vector2 = WorldLayout.to_point(WorldLayout.DEFENSE_CELLS.end - Vector2i.ONE)
		destination = destination.clamp(first, last)
	# Finish the current segment before replanning. Re-centering on the current cell
	# every frame makes slow actors oscillate forever at diagonal cell boundaries.
	var anchor: Vector2 = (
		actor.path[0] if not actor.path.is_empty() else _nearest_open(actor.pos, grid)
	)
	var start: Vector2i = WorldLayout.to_cell(anchor)
	var end: Vector2i = WorldLayout.to_cell(_nearest_open(destination, grid))
	var path: PackedVector2Array = grid.get_point_path(start, end, true)
	# Keep the first cell center if needed: skipping it can cut building corners.
	if not path.is_empty() and actor.pos.distance_to(path[0]) < 3:
		path.remove_at(0)
	actor.path = path


func _move_along_path(actor: CombatActor, distance: float, zombie: bool) -> void:
	if actor.path.is_empty():
		return
	var goal: Vector2 = actor.path[0]
	if zombie:
		var key: Vector2i = WorldLayout.to_cell(goal)
		if walls.has(key) and walls[key].hp > 0 and actor.pos.distance_to(goal) < 30:
			if actor.cooldown <= 0:
				walls[key].hp = maxf(0, walls[key].hp - actor.damage * 2.0)
				actor.cooldown = 1.0
				particles.append(CombatParticle.new(goal, 0.3, Color("dca06e")))
				if walls[key].hp <= 0:
					# 敌人可穿过缺口，村民驻守区不会随围墙破损扩张。
					guard_grid.set_point_solid(
						walls[key].cell, not WorldLayout.DEFENSE_CELLS.has_point(walls[key].cell)
					)
					enemy_grid.set_point_weight_scale(walls[key].cell, 1.0)
			return
	actor.pos = actor.pos.move_toward(goal, distance)
	if actor.pos.distance_to(goal) < 1:
		actor.path.remove_at(0)


func _nearest_open(point: Vector2, grid: AStarGrid2D) -> Vector2:
	var cell: Vector2i = WorldLayout.to_cell(point)
	if not grid.is_point_solid(cell):
		return WorldLayout.to_point(cell)
	for radius: int in range(1, 10):
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: float = INF
		for x: int in range(cell.x - radius, cell.x + radius + 1):
			for y: int in range(cell.y - radius, cell.y + radius + 1):
				var candidate: Vector2i = Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					var d: float = WorldLayout.to_point(candidate).distance_squared_to(point)
					if d < best_distance:
						best_distance = d
						best = candidate
		if best.x >= 0:
			return WorldLayout.to_point(best)
	return WorldLayout.CENTER + Vector2(0, 60)


func _clear_shot(from: Vector2, to: Vector2, block_walls: bool = false) -> bool:
	var steps: int = maxi(1, int(from.distance_to(to) / 12))
	for i: int in range(1, steps):
		var cell: Vector2i = WorldLayout.to_cell(from.lerp(to, float(i) / steps))
		if block_walls and walls.has(cell) and walls[cell].hp > 0:
			return false
		if stats.modern_combat and _terrain.has(cell):
			return false
		for building: StructurePlacement in _buildings:
			# Core can be attacked at its edge; other structures occlude projectiles.
			if building.key != GameTypes.Building.CORE and building.rect.has_point(cell):
				return false
	return true


func _in_trap_ring(point: Vector2) -> bool:
	var outer: Rect2 = Rect2(312, 120, 360, 360)
	var inner: Rect2 = Rect2(360, 168, 264, 264)
	return outer.has_point(point) and not inner.has_point(point)


func _complete() -> void:
	if not active:
		return
	active = false
	var report: BattleReport = BattleReport.new()
	for cell: Vector2i in walls:
		report.wall_damage[cell] = walls[cell].max_hp - walls[cell].hp
	if stats.modern_combat:
		report.has_identities = true
		report.consumed = support.consumed.duplicate()
		for guard: CombatActor in guards:
			report.survivor_ids.append(guard.person_id)
	report.core_health = maxf(0, core_health)
	report.survivors = guards.size()
	report.kills = kills
	report.started_survivors = started_survivors
	report.duration = elapsed
	report.boss_defeated = boss_spawned and enemies.is_empty()
	finished.emit(report)
