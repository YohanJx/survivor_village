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
var _camp_areas: Array[Rect2] = []
var _last_phase: GameTypes.Phase = GameTypes.Phase.DAY
var _wall_cells: Array[Vector2i] = []
var _wall_health: float = 90
var _last_seed: int = -1
var _last_region: GameTypes.Region = GameTypes.Region.LEGACY
var _drag_button: MouseButton = MOUSE_BUTTON_NONE

@onready var _atmosphere: MapAtmosphere = %MapAtmosphere


func _ready() -> void:
	custom_minimum_size = Vector2(600, 260)
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
	draw_set_transform_matrix(view_camera.get_view_transform(size))
	var night: bool = state.phase == GameTypes.Phase.NIGHT
	draw_rect(
		Rect2(Vector2.ZERO, WorldLayout.WORLD),
		(
			rules.ground_colors[period]
			* state.catalog.library.progression_rules.map_for(state.progress.region).ground_tint
		)
	)
	if exploration_mode and not night:
		TerrainMapRenderer.draw_survey(self, state, view_camera)
		_draw_compass()
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	TerrainMapRenderer.draw_ground(self, state, night, _camp_areas, view_camera)
	_draw_terrain_obstacles(night)
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
			_draw_fence(WorldLayout.to_point(cell), cell.y in [6, 18], hp_ratio)
	for structure: StructurePlacement in _structures:
		_draw_structure(structure, night)
	# Village fire, always present.
	var fire_pos: Vector2 = Vector2(492, 348)
	if night:
		for radius: float in [90.0, 66.0, 40.0]:
			draw_circle(fire_pos, radius, Color(0.95, 0.58, 0.24, 0.035))
	draw_circle(fire_pos + Vector2(0, 7), 11, Color(0.05, 0.07, 0.05, 0.4))
	draw_line(fire_pos + Vector2(-8, 4), fire_pos + Vector2(8, -1), Color("a27850"), 5)
	draw_line(fire_pos + Vector2(-8, -1), fire_pos + Vector2(8, 4), Color("a27850"), 5)
	draw_colored_polygon(
		PackedVector2Array(
			[
				fire_pos + Vector2(-7, 1),
				fire_pos + Vector2(-3, -9),
				fire_pos + Vector2(1, -15 - sin(_clock_time * 8) * 3),
				fire_pos + Vector2(7, 1)
			]
		),
		Color("e4a65d")
	)
	draw_circle(fire_pos + Vector2(0, -2), 3, Color("f5df91"))
	if night:
		for enemy: CombatActor in battle.enemies:
			_draw_actor(enemy, true)
		for guard: CombatActor in battle.guards:
			_draw_actor(guard, false)
		for shot: ProjectileState in battle.projectiles:
			if shot.bow:
				draw_line(shot.pos - Vector2(5, -2), shot.pos + Vector2(5, -2), Color("f0d499"), 2)
			else:
				draw_circle(shot.pos, 3, Color("d8dfcb"))
		for particle: CombatParticle in battle.particles:
			if particle.text.is_empty():
				draw_arc(
					particle.pos, (1 - particle.life) * 18 + 3, 0, TAU, 16, particle.color, 1.5
				)
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
	else:
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
			_draw_actor(guard, false)
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
	_camp_areas = WorldLayout.camp_areas(_structures)
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


func _draw_tree(point: Vector2, variation: int, night: bool) -> void:
	draw_circle(point + Vector2(4, 6), 15, Color(0.03, 0.07, 0.04, 0.35))
	draw_line(point + Vector2(0, 9), point - Vector2(0, 4), Color("716344"), 4)
	var base: Color = Color("294536") if night else Color("3e6543")
	draw_circle(point + Vector2(-6, -7), 10 + variation, base.darkened(0.12))
	draw_circle(point + Vector2(7, -8), 11, base)
	draw_circle(point + Vector2(0, -17), 11, base.lightened(0.08))
	draw_line(point + Vector2(-3, -22), point + Vector2(3, -22), base.lightened(0.16), 2)


func _draw_structure(structure: StructurePlacement, night: bool) -> void:
	var cell_rect: Rect2i = structure.rect
	var rect: Rect2 = Rect2(Vector2(cell_rect.position) * 24, Vector2(cell_rect.size) * 24)
	var point: Vector2 = rect.get_center()
	draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color(0.02, 0.05, 0.03, 0.3))
	match structure.key:
		GameTypes.Building.FARM:
			draw_rect(rect, Color("645b3c"))
			for row: int in 3:
				draw_line(
					rect.position + Vector2(6, 8 + row * 14),
					rect.position + Vector2(rect.size.x - 6, 8 + row * 14),
					Color("3a442c"),
					6
				)
				for col: int in 5:
					draw_circle(
						rect.position + Vector2(10 + col * 12, 8 + row * 14), 3.5, Color("8ca95e")
					)
			if state.buildings[GameTypes.Building.GREENHOUSE] > 0:
				draw_rect(rect, Color(0.62, 0.87, 0.83, 0.12))
				draw_rect(rect, Color("90b9ad"), false, 2)
		GameTypes.Building.WELL:
			draw_circle(point, 12, Color("a4a88f"))
			draw_circle(point, 8, Color("2f595c"))
			draw_line(point + Vector2(-10, -7), point + Vector2(10, -7), Color("be9b62"), 3)
			if state.buildings[GameTypes.Building.FILTER] > 0:
				draw_circle(point + Vector2(14, 4), 5, Color("7bc0be"))
		GameTypes.Building.GENERATOR:
			draw_rect(rect, Color("778981"))
			draw_rect(rect.grow(-5), Color("36443e"))
			draw_line(point + Vector2(-12, -3), point + Vector2(9, -3), Color("d5b56b"), 4)
			draw_circle(point + Vector2(17, -3), 2, Color("b2d899"))
			var rise: float = fmod(_clock_time * 12, 28)
			draw_circle(
				point + Vector2(15, -10 - rise),
				3 + rise * 0.15,
				Color(0.6, 0.64, 0.55, 0.15 * (1 - rise / 28))
			)
		GameTypes.Building.LIGHTS:
			draw_line(point, point + Vector2(0, -22), Color("9daea0"), 4)
			draw_rect(Rect2(point + Vector2(-8, -26), Vector2(16, 9)), Color("dcc88a"))
			if night and battle.stats.lights_active:
				draw_colored_polygon(
					PackedVector2Array(
						[point, point + Vector2(130, -78), point + Vector2(130, 78)]
					),
					Color(0.94, 0.86, 0.47, 0.1)
				)
		_:
			var roof: Color = Color("a27d51")
			if structure.key == GameTypes.Building.CORE:
				roof = Color("c19d60")
			elif structure.key == GameTypes.Building.CLINIC:
				roof = Color("759b89")
			elif structure.key == GameTypes.Building.WORKSHOP:
				roof = Color("8c8170")
			draw_rect(rect, Color("877954"))
			draw_rect(Rect2(rect.position + Vector2(0, -6), rect.size - Vector2(0, 9)), roof)
			draw_rect(
				Rect2(rect.position + Vector2(0, -6), Vector2(rect.size.x, 3)), roof.lightened(0.25)
			)
			draw_line(
				rect.position + Vector2(0, rect.size.y * 0.4),
				rect.position + Vector2(rect.size.x, rect.size.y * 0.4),
				roof.darkened(0.12),
				2
			)
			draw_rect(
				Rect2(point + Vector2(-6, rect.size.y * 0.3), Vector2(12, 11)), Color("354239")
			)
			for side: int in [-1, 1]:
				draw_rect(
					Rect2(
						point + Vector2(side * rect.size.x * 0.3 - 3, rect.size.y * 0.28),
						Vector2(7, 6)
					),
					Color("eccd85") if night else Color("a9bfaf")
				)
			if structure.key == GameTypes.Building.CLINIC:
				draw_line(point + Vector2(-7, 0), point + Vector2(7, 0), Color("dee4cd"), 4)
				draw_line(point + Vector2(0, -7), point + Vector2(0, 7), Color("dee4cd"), 4)
	var font: Font = get_theme_default_font()
	draw_string(
		font,
		Vector2(point.x - 45, rect.end.y + 21),
		structure.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		90,
		12,
		Color("bec5a7")
	)
	if structure.key == GameTypes.Building.CORE:
		var hp: float = battle.core_health if night else state.core_health
		draw_rect(Rect2(rect.position + Vector2(0, -16), Vector2(rect.size.x, 4)), Color("17291f"))
		draw_rect(
			Rect2(
				rect.position + Vector2(0, -16),
				Vector2(rect.size.x * maxf(0, hp) / state.core_max_health, 4)
			),
			Color("b3c18a")
		)


func _draw_fence(point: Vector2, horizontal: bool, hp_ratio: float) -> void:
	if hp_ratio <= 0:
		draw_line(point - Vector2(5, 1), point + Vector2(4, 6), Color("655741"), 3)
		return
	var color: Color = Color("a39264").lerp(Color("765542"), 1 - hp_ratio)
	var direction: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	draw_line(point - direction * 12, point + direction * 12, Color("4c4935"), 9)
	draw_line(
		point - direction * 12 - Vector2(0, 3), point + direction * 12 - Vector2(0, 3), color, 4
	)
	for step: int in [-8, 0, 8]:
		var post: Vector2 = point + direction * float(step)
		draw_line(post + Vector2(0, 3), post - Vector2(0, 9), color.lightened(0.1), 3)


func _draw_trap(point: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([point + Vector2(-4, 4), point + Vector2(0, -5), point + Vector2(4, 4)]),
		Color("ad9a73")
	)


func _draw_actor(actor: CombatActor, zombie: bool) -> void:
	var point: Vector2 = actor.pos
	var bob: float = sin(_clock_time * 7 + actor.id) * 1.3
	var body: Color = Color("a6c3ba")
	var skin: Color = Color("e2c399")
	var radius: float = 5.0
	if zombie:
		body = Color("798c61")
		skin = Color("adbb7b")
		match actor.kind:
			GameTypes.Enemy.RUNNER:
				body = Color("b09964")
			GameTypes.Enemy.BRUTE:
				radius = 8
				body = Color("8c8265")
			GameTypes.Enemy.BOSS:
				radius = 13
				body = Color("af6358")
				skin = Color("c09578")
			GameTypes.Enemy.ARMORED:
				body = Color("8496ac")
			GameTypes.Enemy.SPITTER:
				body = Color("b4cc67")
			GameTypes.Enemy.SCREAMER:
				body = Color("c78abb")
			GameTypes.Enemy.LURKER:
				body = Color("576c76")
			GameTypes.Enemy.BURNER:
				body = Color("ed9965")
	elif int(actor.id) % 3 == 0:
		body = Color("bbac7b")
	if not zombie and state.progress.region != GameTypes.Region.LEGACY:
		body = UiElements.UNIT_COLORS[actor.unit]
	if actor.flash > 0:
		body = Color("eae6c9")
	draw_circle(point + Vector2(2, 3), radius + 2, Color(0.02, 0.04, 0.03, 0.4))
	draw_line(
		point + Vector2(-radius * 0.45, 1),
		point + Vector2(-radius * 0.5, 4 + bob),
		Color("37453c"),
		radius * 0.55
	)
	draw_line(
		point + Vector2(radius * 0.45, 1),
		point + Vector2(radius * 0.5, 4 - bob),
		Color("37453c"),
		radius * 0.55
	)
	draw_rect(
		Rect2(point + Vector2(-radius, -radius * 1.5 + bob), Vector2(radius * 2, radius * 1.7)),
		body
	)
	draw_circle(point + Vector2(0, -radius * 2 + bob), radius * 0.7, skin)
	if not zombie:
		draw_line(point + Vector2(3, -4 + bob), point + actor.facing * 10 + Vector2(0, -4), body, 3)
		if (
			actor.unit == GameTypes.Unit.ARCHER
			or (
				state.progress.region == GameTypes.Region.LEGACY
				and state.buildings[GameTypes.Building.BOWS] > 0
			)
		):
			draw_arc(
				point + actor.facing * 10 + Vector2(0, -4), 5, -1.4, 1.4, 6, Color("d5b175"), 1.5
			)
	elif actor.kind == GameTypes.Enemy.BOSS:
		draw_line(point + Vector2(-10, -18), point + Vector2(10, -18), Color("c89667"), 3)
	if actor.hp < actor.max_hp or (zombie and actor.kind == GameTypes.Enemy.BOSS):
		var width: float = radius * 3
		var hp_pos: Vector2 = point + Vector2(-width / 2, -radius * 3.4)
		draw_rect(Rect2(hp_pos, Vector2(width, 3)), Color("182c24"))
		draw_rect(
			Rect2(hp_pos, Vector2(width * maxf(0, actor.hp / actor.max_hp), 3)),
			Color("d99078") if zombie else Color("9ac4ac")
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
			_draw_tree(WorldLayout.to_point(cell), int(cell.x + cell.y) % 3, night)
		else:
			TerrainMapRenderer.draw_obstacle(self, cell, kind)
