class_name ApocalypseMapArt
extends RefCounted
## 末日地图纯展示：预载图集、按原生设施与战斗身份取图，不修改状态或碰撞布局。

enum Prop {
	SHELTER,
	HOUSE,
	WORKSHOP,
	CLINIC,
	WELL,
	GENERATOR,
	FARM,
	GREENHOUSE,
	STORE,
	LIGHT,
	FENCE_HORIZONTAL,
	FENCE_VERTICAL,
	DEAD_TREE,
	DYING_TREE,
	RUBBLE,
	FIRE
}

const CAMP_ATLAS: Texture2D = preload("res://assets/map/camp_atlas.png")
const PEOPLE_ATLAS: Texture2D = preload("res://assets/map/people_atlas.png")
const GROUND_ATLAS: Texture2D = preload("res://assets/map/ground_atlas.png")
const BACKDROP: Texture2D = preload("res://assets/cards/survey.png")
const BUILDING_PROPS: Dictionary[GameTypes.Building, Prop] = {
	GameTypes.Building.CORE: Prop.SHELTER,
	GameTypes.Building.HUT: Prop.HOUSE,
	GameTypes.Building.FARM: Prop.FARM,
	GameTypes.Building.WELL: Prop.WELL,
	GameTypes.Building.GENERATOR: Prop.GENERATOR,
	GameTypes.Building.LIGHTS: Prop.LIGHT,
	GameTypes.Building.WORKSHOP: Prop.WORKSHOP,
	GameTypes.Building.CLINIC: Prop.CLINIC,
	GameTypes.Building.GREENHOUSE: Prop.GREENHOUSE
}

var _props: Array[AtlasTexture] = []
var _people: Array[AtlasTexture] = []
var _ground: Array[AtlasTexture] = []
var _soil: AtlasTexture = AtlasTexture.new()


func _init() -> void:
	_props = _slice(CAMP_ATLAS, Vector2i(4, 4))
	_people = _slice(PEOPLE_ATLAS, Vector2i(4, 2))
	_ground = _slice(GROUND_ATLAS, Vector2i(3, 2))
	_soil.atlas = GROUND_ATLAS
	var tile_size: Vector2 = GROUND_ATLAS.get_size() / Vector2(3, 2)
	_soil.region = Rect2(tile_size * 0.2, tile_size * 0.6)
	_soil.filter_clip = true


func draw_backdrop(canvas: Control) -> void:
	var scale_value: float = maxf(
		canvas.size.x / BACKDROP.get_width(), canvas.size.y / BACKDROP.get_height()
	)
	var source_size: Vector2 = canvas.size / scale_value
	canvas.draw_texture_rect_region(
		BACKDROP,
		Rect2(Vector2.ZERO, canvas.size),
		Rect2((BACKDROP.get_size() - source_size) * 0.5, source_size),
		Color(0.20, 0.18, 0.15, 0.55)
	)


func draw_ground(canvas: Control, area: Rect2, kind: TerrainGrid.Biome, tint: Color) -> void:
	canvas.draw_texture_rect(_ground[kind], area, false, tint)


func draw_soil(canvas: Control, area: Rect2, tint: Color) -> void:
	canvas.draw_texture_rect(_soil, area, false, tint)


func draw_ground_patch(canvas: Control, area: Rect2, kind: TerrainGrid.Biome, tint: Color) -> void:
	for step: int in 6:
		var inset: float = float(step) * 2.0
		var texture_size: Vector2 = _ground[kind].get_size()
		var source_inset: Vector2 = Vector2.ONE * inset / area.size * texture_size
		var pigment: Color = Color(tint, 0.14)
		canvas.draw_texture_rect_region(
			_ground[kind],
			area.grow(-inset),
			Rect2(source_inset, texture_size - source_inset * 2.0),
			pigment
		)


func draw_structure(
	canvas: Control,
	state: VillageState,
	battle: BattleSimulation,
	structure: StructurePlacement,
	night: bool
) -> void:
	var rect: Rect2 = Rect2(
		Vector2(structure.rect.position) * WorldLayout.CELL,
		Vector2(structure.rect.size) * WorldLayout.CELL
	)
	var prop: Prop = BUILDING_PROPS.get(structure.key, Prop.STORE)
	if (
		structure.key == GameTypes.Building.FARM
		and state.buildings[GameTypes.Building.GREENHOUSE] > 0
	):
		prop = Prop.GREENHOUSE
	var texture: Texture2D = (
		structure.definition.map_texture if structure.definition.map_texture != null else _props[prop]
	)
	var extent: Vector2 = Vector2(maxf(48, rect.size.x + 14), maxf(48, rect.size.y + 24))
	var offset: Vector2 = Vector2(0, 8)
	if structure.definition.map_texture != null:
		var bounds: Vector2 = rect.size * Vector2(0.95, 1.5)
		var source_size: Vector2 = texture.get_size()
		extent = source_size * minf(bounds.x / source_size.x, bounds.y / source_size.y)
		offset = Vector2(0, (extent.y - rect.size.y) * 0.5)
	canvas.draw_texture_rect(
		texture,
		Rect2(rect.get_center() - extent * 0.5 - offset, extent),
		false,
		_tint(night)
	)
	if structure.key == GameTypes.Building.CORE:
		_draw_core_health(canvas, state, battle, rect, night)
	if night and structure.key == GameTypes.Building.LIGHTS and battle.stats.lights_active:
		canvas.draw_circle(rect.get_center(), 75, Color(0.80, 0.68, 0.43, 0.08))


func draw_tree(canvas: Control, point: Vector2, variation: int, night: bool) -> void:
	var prop: Prop = Prop.DEAD_TREE if variation % 2 == 0 else Prop.DYING_TREE
	canvas.draw_texture_rect(
		_props[prop], Rect2(point - Vector2(20, 33), Vector2(40, 46)), false, _tint(night)
	)


func draw_obstacle(canvas: Control, point: Vector2, night: bool) -> void:
	canvas.draw_texture_rect(
		_props[Prop.RUBBLE], Rect2(point - Vector2(14, 14), Vector2(28, 28)), false, _tint(night)
	)


func draw_fence(
	canvas: Control, point: Vector2, horizontal: bool, hp_ratio: float, night: bool
) -> void:
	var prop: Prop = Prop.FENCE_HORIZONTAL if horizontal else Prop.FENCE_VERTICAL
	if hp_ratio <= 0:
		canvas.draw_texture_rect(
			_props[Prop.RUBBLE], Rect2(point - Vector2(12, 9), Vector2(24, 18)), false, _tint(night)
		)
		return
	canvas.draw_texture_rect(
		_props[prop],
		Rect2(point - Vector2(14, 17), Vector2(28, 28)),
		false,
		_tint(night).lerp(Color(0.55, 0.43, 0.33), 1.0 - hp_ratio)
	)


func draw_fire(canvas: Control, point: Vector2, night: bool) -> void:
	if night:
		canvas.draw_circle(point, 60, Color(0.82, 0.53, 0.25, 0.06))
	canvas.draw_texture_rect(
		_props[Prop.FIRE], Rect2(point - Vector2(15, 15), Vector2(30, 30)), false
	)


func draw_actor(
	canvas: Control, actor: CombatActor, zombie: bool, night: bool, clock_time: float
) -> void:
	var index: int = 0
	var extent: Vector2 = Vector2(19, 26)
	if zombie:
		index = 4
		match actor.kind:
			GameTypes.Enemy.RUNNER:
				index = 5
			GameTypes.Enemy.BRUTE:
				index = 6
				extent *= 1.4
			GameTypes.Enemy.BOSS:
				index = 7
				extent *= 1.9
	else:
		match actor.unit:
			GameTypes.Unit.ARCHER:
				index = 2
			GameTypes.Unit.ENGINEER:
				index = 3
			GameTypes.Unit.SPEAR:
				index = 1
	var point: Vector2 = actor.pos + Vector2(0, sin(clock_time * 6 + actor.id) * 0.8)
	var tint: Color = Color(1.3, 1.2, 1.05) if actor.flash > 0 else _tint(night)
	canvas.draw_texture_rect(
		_people[index], Rect2(point - extent * Vector2(0.5, 0.8), extent), false, tint
	)
	if actor.hp < actor.max_hp or (zombie and actor.kind == GameTypes.Enemy.BOSS):
		var origin: Vector2 = point - Vector2(extent.x * 0.5, extent.y + 3)
		canvas.draw_rect(Rect2(origin, Vector2(extent.x, 3)), Color("211e19"))
		canvas.draw_rect(
			Rect2(origin, Vector2(extent.x * maxf(0, actor.hp / actor.max_hp), 3)),
			UiElements.NEGATIVE if zombie else UiElements.POSITIVE
		)


func _draw_core_health(
	canvas: Control, state: VillageState, battle: BattleSimulation, rect: Rect2, night: bool
) -> void:
	var hp: float = battle.core_health if night else state.core_health
	var origin: Vector2 = rect.position - Vector2(0, 23)
	canvas.draw_rect(Rect2(origin, Vector2(rect.size.x, 3)), Color("211e19"))
	canvas.draw_rect(
		Rect2(origin, Vector2(rect.size.x * maxf(0, hp) / state.core_max_health, 3)),
		UiElements.POSITIVE
	)


func _slice(texture: Texture2D, grid: Vector2i) -> Array[AtlasTexture]:
	var result: Array[AtlasTexture] = []
	var cell: Vector2 = texture.get_size() / Vector2(grid)
	for index: int in grid.x * grid.y:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(index % grid.x, int(index / float(grid.x))) * cell, cell)
		frame.filter_clip = true
		result.append(frame)
	return result


func _tint(night: bool) -> Color:
	return Color(0.62, 0.64, 0.65) if night else Color.WHITE
