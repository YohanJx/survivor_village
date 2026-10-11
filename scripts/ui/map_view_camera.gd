class_name MapViewCamera
extends RefCounted
## 地图展示镜头；世界坐标不变，平移和缩放只影响绘制。

const VILLAGE_ZOOM: float = 3.4
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.2

var _center: Vector2 = WorldLayout.CENTER
var _zoom: float = VILLAGE_ZOOM


func get_view_transform(view_size: Vector2) -> Transform2D:
	var scale_value: float = _fit_scale(view_size) * _zoom
	return Transform2D(0.0, Vector2.ONE * scale_value, 0.0, view_size * 0.5 - _center * scale_value)


func view_to_world(point: Vector2, view_size: Vector2) -> Vector2:
	return get_view_transform(view_size).affine_inverse() * point


func focus_village() -> void:
	_center = WorldLayout.CENTER
	_zoom = VILLAGE_ZOOM


func fit_world() -> void:
	_center = WorldLayout.WORLD * 0.5
	_zoom = MIN_ZOOM


func pan_by(view_delta: Vector2, view_size: Vector2) -> void:
	_center -= view_delta / (_fit_scale(view_size) * _zoom)
	_clamp_center()


## 鼠标所在世界点保持原位；到达地图边缘时优先保证镜头仍可看到地图。
func zoom_by(factor: float, anchor: Vector2, view_size: Vector2) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	var world_anchor: Vector2 = view_to_world(anchor, view_size)
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_center = world_anchor - (anchor - view_size * 0.5) / (_fit_scale(view_size) * _zoom)
	_clamp_center()


func _fit_scale(view_size: Vector2) -> float:
	return maxf(0.001, minf(view_size.x / WorldLayout.WORLD.x, view_size.y / WorldLayout.WORLD.y))


func _clamp_center() -> void:
	_center = _center.clamp(Vector2.ZERO, WorldLayout.WORLD)
