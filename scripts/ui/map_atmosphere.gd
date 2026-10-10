class_name MapAtmosphere
extends Control
## 地图上方的四时段光照与天气表现，鼠标穿透；不消耗游戏 RNG 或推进规则。

const MAX_RAIN_DROPS: int = 100
const LIGHTNING_INTERVAL: float = 13.0
const LIGHTNING_DURATION: float = 0.35

var _weather: WeatherDefinition
var _light: Color = Color.TRANSPARENT
var _clock_time: float = 0.0
var _rain_origins: PackedVector2Array = []


func _ready() -> void:
	for index: int in MAX_RAIN_DROPS:
		_rain_origins.append(Vector2(fposmod(index * 0.618, 1.0), fposmod(index * 0.417, 1.0)))
	set_process(false)


func _process(delta: float) -> void:
	_clock_time += delta
	queue_redraw()


func _draw() -> void:
	if _weather == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _light)
	draw_rect(Rect2(Vector2.ZERO, size), _weather.veil)
	if _weather.fog_density > 0.0:
		_draw_fog()
	if _weather.rainfall > 0.0:
		_draw_rain()
	if _weather.kind == WeatherDefinition.Kind.THUNDERSTORM:
		_draw_lightning()


func update_view(state: VillageState) -> void:
	if _weather != state.weather:
		_clock_time = 1.0
	_weather = state.weather
	_light = state.catalog.library.weather_rules.light_colors[state.environment_period()]
	set_process(_weather != null and (_weather.rainfall > 0.0 or _weather.fog_density > 0.0))
	queue_redraw()


func _draw_rain() -> void:
	var count: int = ceili(MAX_RAIN_DROPS * _weather.rainfall)
	for index: int in count:
		var origin: Vector2 = _rain_origins[index]
		var point: Vector2 = Vector2(
			fposmod(origin.x * size.x - _clock_time * 72.0, size.x),
			fposmod(origin.y * size.y + _clock_time * 300.0, size.y)
		)
		draw_line(point, point + Vector2(-5, 15), Color(0.72, 0.81, 0.85, 0.3), 1.0, true)


func _draw_fog() -> void:
	for index: int in 5:
		var height: float = size.y * 0.25
		var top: float = size.y * index / 5.0 + sin(_clock_time * 0.15 + index) * 16.0
		draw_rect(
			Rect2(-20, top, size.x + 40, height),
			Color(0.67, 0.73, 0.74, _weather.fog_density * 0.075)
		)


func _draw_lightning() -> void:
	var elapsed: float = fposmod(_clock_time, LIGHTNING_INTERVAL)
	if elapsed >= LIGHTNING_DURATION:
		return
	var strength: float = sin(elapsed / LIGHTNING_DURATION * PI)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.82, 0.88, 0.95, strength * 0.16))
	var origin: Vector2 = Vector2(size.x * 0.78, 0)
	draw_polyline(
		PackedVector2Array(
			[
				origin,
				origin + Vector2(-17, 35),
				origin + Vector2(4, 31),
				origin + Vector2(-26, 78),
				origin + Vector2(-10, 68),
				origin + Vector2(-38, 116)
			]
		),
		Color(0.83, 0.90, 1.0, strength * 0.7),
		1.5,
		true
	)
