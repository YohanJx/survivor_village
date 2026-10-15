extends SceneTree
## 固定种子和相同经济设施组合的战斗对比；不写玩家存档。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scenario: int in 2:
		var total: int = 0
		var minimum: int = 5
		var failed: int = 0
		for region: GameTypes.Region in [GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS]:
			for seed_value: int in [12345, 65012, 99881, 24011, 81037, 55412, 91823, 10293]:
				var state: VillageState = VillageState.new()
				state.persistence_enabled = false
				state.new_run(seed_value, region)
				SurvivalTestSetup.developed(state)
				state.progress.explored_cells.resize(7 if scenario == 0 else 13)
				state.progress.terrain_surveys = state.progress.explored_cells.size() - 1
				state.progress.discoveries = TerrainGrid.discoveries_for(state.terrain_grid, state.progress.explored_cells)
				state.day = 4
				state.buildings[GameTypes.Building.WORKSHOP] = 1
				state.buildings[GameTypes.Building.FARM] = 1
				state.buildings[GameTypes.Building.WELL] = 1
				state.resources[GameTypes.Stock.NOISE] = 12
				if scenario == 1:
					state.buildings[GameTypes.Building.WALL] = 1
					state.buildings[GameTypes.Building.BOWS] = 1
				state.begin_night()
				var battle: BattleSimulation = BattleSimulation.new()
				battle.start(state)
				while battle.active:
					battle.step(BattleSimulation.FIXED_STEP_SECONDS)
				total += battle.guards.size()
				minimum = mini(minimum, battle.guards.size())
				if battle.core_health <= 0 or battle.guards.is_empty():
					failed += 1
		print("BALANCE scenario=%d runs=24 survivors=%d/120 minimum=%d defeats=%d" % [scenario, total, minimum, failed])
	quit()
