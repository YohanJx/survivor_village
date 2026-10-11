class_name VillageMap
extends Control

signal exploration_requested(cell: Vector2i)

var exploration_mode: bool = false
var view_camera: MapViewCamera = MapViewCamera.new()
var state: VillageState
var battle: BattleSimulation
var _press_position: Vector2 = Vector2.ZERO
var _drag_distance: float = 0.0
var _clock_time: float = 0
var _trees: Array[Vector2i] = []
var _idle_guards: Array[CombatActor] = []
var _structures: Array[StructurePlacement] = []
var _art: ApocalypseMapArt = ApocalypseMapArt.new()
var _last_phase: GameTypes.Phase = GameTypes.Phase.DAY
var _wall_cells: Array[Vector2i] = []
var _wall_health: float = 90
var _last_seed: int = -1
var _last_region: GameTypes.Region = GameTypes.Region.LEGACY
var _drag_button: MouseButton = MOUSE_BUTTON_NONE

@onready var _atmosphere: MapAtmosphere = %MapAtmosphere


func _ready() -> void:
	custom_minimum_size = Vector2(600, 160)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "左键或中键拖动查看 · 滚轮缩放 · 双击回到村庄"
	get_window().focus_exited.connect(_stop_drag)


func _process(delta: float) -> void:
	_clock_time += delta
	if state != null:
		if _last_seed != state.run_seed or _last_region != state.progress.region:
			_prepare_map()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _drag_button != MOUSE_BUTTON_NONE:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_distance += motion.relative.length()
		view_camera.pan_by(motion.relative, size)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		view_camera.zoom_by(magnify.factor, magnify.position, size)
		accept_event()
	elif event is InputEventPanGesture:
		var pan: InputEventPanGesture = event as InputEventPanGesture
		view_camera.pan_by(-pan.delta * 16.0, size)
		accept_event()
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var rules: WeatherRules = state.catalog.library.weather_rules
	var period: int = state.environment_period()
	draw_rect(Rect2(Vector2.ZERO, size), rules.background_colors[period])
	_art.draw_backdrop(self)
	draw_set_transform_matrix(view_camera.get_view_transform(size))
	var night: bool = state.phase == GameTypes.Phase.NIGHT
	if exploration_mode and not night:
		TerrainMapRenderer.draw_survey(self, state, view_camera, _art)
		_draw_compass()
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	TerrainMapRenderer.draw_ground(self, state, night, _art, _structures)
	_draw_terrain_obstacles(night)
	_draw_camp_objects(night)
	if night:
		_draw_battle()
	else:
		_draw_idle_people()
	if night:
		# Soft edge vignette; approaching enemies remain visible.
		for i: int in range(6):
			var inset: float = i * 11
			draw_rect(
				Rect2(Vector2.ONE * inset, WorldLayout.WORLD - Vector2.ONE * inset * 2),
				Color(0.02, 0.07, 0.08, 0.055),
				false,
				22
			)
	else:
		draw_string(
			get_theme_default_font(),
			Vector2(24, 550),
			state.catalog.library.progression_rules.map_for(state.progress.region).display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color("96a98b")
		)
	_draw_compass()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _on_state_changed() -> void:
	_atmosphere.update_view(state)
	_structures = WorldLayout.active_structures(state)
	if state.phase == GameTypes.Phase.NIGHT and _last_phase != state.phase:
		focus_village()
	_last_phase = state.phase
	_wall_cells = WorldLayout.wall_cells()
	_wall_health = EffectResolver.derive(state).wall_health
	_idle_guards.clear()
	for index: int in state.population:
		var actor: CombatActor = CombatActor.new()
		actor.id = index
		if (
			state.progress.region != GameTypes.Region.LEGACY
			and index < state.progress.survivors.size()
		):
			actor.unit = CombatSupport.kind_for(
				state.progress.survivors[index], state.buildings[GameTypes.Building.BOWS] > 0
			)
		_idle_guards.append(actor)


func bind(game_state: VillageState, simulation: BattleSimulation) -> void:
	if state != null and state.changed.is_connected(_on_state_changed):
		state.changed.disconnect(_on_state_changed)
	state = game_state
	battle = simulation
	state.changed.connect(_on_state_changed)


func focus_village() -> void:
	view_camera.focus_village()
	_stop_drag()
	queue_redraw()


func fit_world() -> void:
	view_camera.fit_world()
	_stop_drag()
	queue_redraw()


func zoom_in() -> void:
	view_camera.zoom_by(MapViewCamera.ZOOM_STEP, size * 0.5, size)
	queue_redraw()


func zoom_out() -> void:
	view_camera.zoom_by(1.0 / MapViewCamera.ZOOM_STEP, size * 0.5, size)
	queue_redraw()


func set_exploration_mode(enabled: bool) -> void:
	if exploration_mode == enabled:
		return
	exploration_mode = enabled
	if enabled:
		fit_world()
	else:
		focus_village()
	tooltip_text = "点击亮边未知格选择目标 · 右侧确认勘探 · 拖动查看 · 滚轮缩放" if enabled else "拖动查看 · 滚轮缩放 · 双击回到村庄"
	queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if event.double_click and event.pressed:
				focus_village()
			elif event.pressed:
				_press_position = event.position
				_drag_distance = 0.0
				_drag_button = event.button_index
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			elif _drag_button == event.button_index:
				if (
					event.button_index == MOUSE_BUTTON_LEFT
					and _drag_distance < 6.0
					and exploration_mode
				):
					var point: Vector2 = view_camera.view_to_world(_press_position, size)
					var cell: Vector2i = Vector2i(
						floori(point.x / TerrainGrid.CELL), floori(point.y / TerrainGrid.CELL)
					)
					if (
						state.phase == GameTypes.Phase.DAY
						and TerrainGrid.is_frontier(cell, state.progress.explored_cells)
					):
						exploration_requested.emit(cell)
				_stop_drag()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				var factor: float = MapViewCamera.ZOOM_STEP
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					factor = 1.0 / factor
				view_camera.zoom_by(factor, event.position, size)
		_:
			return
	accept_event()


func _stop_drag() -> void:
	_drag_button = MOUSE_BUTTON_NONE
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func _prepare_map() -> void:
	_last_seed = state.run_seed
	_last_region = state.progress.region
	if exploration_mode:
		fit_world()
	else:
		focus_village()
	_trees = WorldLayout.terrain(state.terrain_grid)


func _draw_camp_objects(night: bool) -> void:
	if battle.active:
		for hazard: CombatHazard in battle.special.hazards:
			draw_circle(hazard.pos, hazard.radius, Color(0.7, 0.55, 0.18, 0.3))
	if state.buildings[GameTypes.Building.TRAPS] > 0:
		for x: int in range(13, 28):
			for y: int in [5, 19]:
				_draw_trap(WorldLayout.to_point(Vector2i(x, y)))
		for y: int in range(6, 19):
			for x: int in [13, 27]:
				_draw_trap(WorldLayout.to_point(Vector2i(x, y)))
	if state.buildings[GameTypes.Building.WALL] > 0:
		for cell: Vector2i in _wall_cells:
			var hp_ratio: float = 1.0
			var key: Vector2i = cell
			if night and battle.walls.has(key):
				hp_ratio = battle.walls[key].hp / battle.walls[key].max_hp
			elif state.wall_damage.has(key):
				var max_hp: float = _wall_health
				hp_ratio = 1.0 - float(state.wall_damage[key]) / max_hp
			_art.draw_fence(self, WorldLayout.to_point(cell), cell.y in [6, 18], hp_ratio, night)
	for structure: StructurePlacement in _structures:
		_art.draw_structure(self, state, battle, structure, night)
	_art.draw_fire(self, Vector2(492, 348), night)


func _draw_battle() -> void:
	for enemy: CombatActor in battle.enemies:
		_art.draw_actor(self, enemy, true, true, _clock_time)
	for guard: CombatActor in battle.guards:
		_art.draw_actor(self, guard, false, true, _clock_time)
	for shot: ProjectileState in battle.projectiles:
		if shot.bow:
			draw_line(shot.pos - Vector2(5, -2), shot.pos + Vector2(5, -2), Color("f0d499"), 2)
		else:
			draw_circle(shot.pos, 3, Color("d8dfcb"))
	for particle: CombatParticle in battle.particles:
		if particle.text.is_empty():
			draw_arc(particle.pos, (1 - particle.life) * 18 + 3, 0, TAU, 16, particle.color, 1.5)
		else:
			draw_string(
				get_theme_default_font(),
				particle.pos - Vector2(0, (1 - particle.life) * 16),
				particle.text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				13,
				particle.color
			)


func _draw_idle_people() -> void:
	for guard: CombatActor in _idle_guards:
		var angle: float = (
			float(guard.id) * TAU / maxf(1, state.population)
			+ sin(_clock_time * 0.18 + guard.id) * 0.4
		)
		guard.pos = (
			WorldLayout.CENTER
			+ Vector2.from_angle(angle) * (76 + sin(_clock_time * 0.5 + guard.id) * 14)
		)
		if Rect2(454, 254, 92, 62).has_point(guard.pos):
			guard.pos.y += 50
		_art.draw_actor(self, guard, false, false, _clock_time)


func _draw_trap(point: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([point + Vector2(-4, 4), point + Vector2(0, -5), point + Vector2(4, 4)]),
		Color("ad9a73")
	)


func _draw_compass() -> void:
	var point: Vector2 = Vector2(918, 43)
	draw_circle(point, 18, Color(0.05, 0.13, 0.1, 0.35))
	draw_colored_polygon(
		PackedVector2Array(
			[point + Vector2(0, -12), point + Vector2(-4, 3), point + Vector2(4, 3)]
		),
		Color("b4bea0")
	)
	draw_string(
		get_theme_default_font(),
		point + Vector2(-4, -22),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("b4bea0")
	)


func _draw_terrain_obstacles(night: bool) -> void:
	for cell: Vector2i in _trees:
		var coarse: Vector2i = Vector2i(int(cell.x / 4.0), int(cell.y / 4.0))
		if not state.progress.explored_cells.has(TerrainGrid.index(coarse)):
			continue
		var kind: TerrainGrid.Biome = state.terrain_grid.biome(coarse)
		if kind == TerrainGrid.Biome.FOREST:
			_art.draw_tree(self, WorldLayout.to_point(cell), int(cell.x + cell.y) % 3, night)
		else:
			if kind != TerrainGrid.Biome.RIVER:
				_art.draw_obstacle(self, WorldLayout.to_point(cell), night)
