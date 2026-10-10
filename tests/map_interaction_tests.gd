class_name MapInteractionTests
extends RefCounted
## 使用真实 Viewport 输入路由检查地图操作与 UI 遮挡。

var _tree: SceneTree
var _map: VillageMap
var _check: Callable


func run(tree: SceneTree, dashboard: VillageDashboard, check: Callable, capture: Callable) -> void:
	_tree = tree
	_map = dashboard.get_node("%VillageMap") as VillageMap
	_check = check
	var point: Vector2 = _map.size * Vector2(0.55, 0.55)
	var before: Vector2 = _map.view_camera.view_to_world(point, _map.size)
	var scale_before: float = _map.view_camera.get_view_transform(_map.size).get_scale().x
	await _button(MOUSE_BUTTON_WHEEL_UP, point, true)
	_check.call(_scale() > scale_before, "Wheel zooms through real GUI input")
	_check.call(
		_map.view_camera.view_to_world(point, _map.size).is_equal_approx(before),
		"Zoom preserves the world point under the cursor"
	)
	var transform: Transform2D = _map.view_camera.get_view_transform(_map.size)
	await _button(MOUSE_BUTTON_LEFT, point, true)
	await _motion(point + Vector2(80, 35), Vector2(80, 35), MOUSE_BUTTON_MASK_LEFT)
	var moved: Transform2D = _map.view_camera.get_view_transform(_map.size)
	_check.call(
		moved.origin.is_equal_approx(transform.origin + Vector2(80, 35)),
		"Left drag moves map by the pointer distance"
	)
	await capture.call("ui_map_dragged")
	await _button(MOUSE_BUTTON_LEFT, Vector2(-20, -20), false)
	await _motion(point, Vector2(-80, -35), 0)
	_check.call(
		_map.view_camera.get_view_transform(_map.size).is_equal_approx(moved),
		"Release outside map stops dragging"
	)
	(dashboard.get_node("%MapFitButton") as Button).pressed.emit()
	var fitted: Transform2D = _map.view_camera.get_view_transform(_map.size)
	var world_rect: Rect2 = fitted * Rect2(Vector2.ZERO, WorldLayout.WORLD)
	_check.call(
		(
			world_rect.position.x >= -1.0
			and world_rect.position.y >= -1.0
			and world_rect.end.x <= _map.size.x + 1.0
			and world_rect.end.y <= _map.size.y + 1.0
		),
		"Fit button shows the entire battlefield"
	)
	await capture.call("ui_map_overview")
	(dashboard.get_node("%MapFocusButton") as Button).pressed.emit()
	_check.call(_scale() > fitted.get_scale().x * 2.0, "Village button restores close view")
	_check.call(
		(_map.view_camera.get_view_transform(_map.size) * WorldLayout.CENTER).is_equal_approx(
			_map.size * 0.5
		),
		"Village returns to view center"
	)
	(dashboard.get_node("%MapZoomIn") as Button).pressed.emit()
	var enlarged: float = _scale()
	(dashboard.get_node("%MapZoomOut") as Button).pressed.emit()
	_check.call(_scale() < enlarged, "Toolbar zoom buttons work")
	transform = _map.view_camera.get_view_transform(_map.size)
	await _button(MOUSE_BUTTON_MIDDLE, point, true)
	await _motion(point + Vector2(20, 10), Vector2(20, 10), MOUSE_BUTTON_MASK_MIDDLE)
	await _button(MOUSE_BUTTON_MIDDLE, point + Vector2(20, 10), false)
	_check.call(
		_map.view_camera.get_view_transform(_map.size).origin.is_equal_approx(
			transform.origin + Vector2(20, 10)
		),
		"Middle drag also moves map"
	)
	var magnify: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	magnify.factor = 1.1
	magnify.position = _map.get_global_transform_with_canvas() * point
	enlarged = _scale()
	_tree.root.push_input(magnify, true)
	await _tree.process_frame
	_check.call(_scale() > enlarged, "Magnify gesture zooms through GUI input")
	dashboard.overlay.show_help()
	await _tree.process_frame
	transform = _map.view_camera.get_view_transform(_map.size)
	await _button(MOUSE_BUTTON_WHEEL_UP, point, true)
	_check.call(
		_map.view_camera.get_view_transform(_map.size).is_equal_approx(transform),
		"Modal blocks mouse zoom on map underneath"
	)
	dashboard.overlay.close_modal()
	await _tree.process_frame
	_test_limits()
	_map.focus_village()
	_map.view_camera.pan_by(Vector2(80, 35), _map.size)
	await _button(MOUSE_BUTTON_LEFT, point, true, true)
	await _button(MOUSE_BUTTON_LEFT, point, false)
	_check.call(
		(_map.view_camera.get_view_transform(_map.size) * WorldLayout.CENTER).is_equal_approx(
			_map.size * 0.5
		),
		"Double click centers the village"
	)
	await capture.call("ui_map_village")


func _button(
	button: MouseButton, point: Vector2, pressed: bool, double_click: bool = false
) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.double_click = double_click
	event.position = _map.get_global_transform_with_canvas() * point
	event.global_position = event.position
	_tree.root.push_input(event, true)
	await _tree.process_frame


func _motion(point: Vector2, relative: Vector2, mask: int) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	var transform: Transform2D = _map.get_global_transform_with_canvas()
	event.position = transform * point
	event.global_position = event.position
	event.relative = transform.basis_xform(relative)
	event.button_mask = mask
	_tree.root.push_input(event, true)
	await _tree.process_frame


func _scale() -> float:
	return _map.view_camera.get_view_transform(_map.size).get_scale().x


func _test_limits() -> void:
	var camera: MapViewCamera = _map.view_camera
	camera.zoom_by(100000.0, _map.size * 0.5, _map.size)
	var max_scale: float = _scale()
	camera.zoom_by(100000.0, _map.size * 0.5, _map.size)
	_check.call(is_equal_approx(_scale(), max_scale), "Zoom has a finite upper bound")
	camera.zoom_by(0.000001, _map.size * 0.5, _map.size)
	var min_scale: float = _scale()
	camera.zoom_by(0.000001, _map.size * 0.5, _map.size)
	_check.call(is_equal_approx(_scale(), min_scale), "Zoom stops at full map size")
	camera.pan_by(Vector2(100000, -100000), _map.size)
	var center: Vector2 = camera.view_to_world(_map.size * 0.5, _map.size)
	_check.call(
		(
			center.x >= 0.0
			and center.y >= 0.0
			and center.x <= WorldLayout.WORLD.x
			and center.y <= WorldLayout.WORLD.y
		),
		"Extreme dragging keeps map center inside world bounds"
	)
	var previous: Transform2D = camera.get_view_transform(_map.size)
	camera.zoom_by(NAN, _map.size * 0.5, _map.size)
	_check.call(
		camera.get_view_transform(_map.size).is_equal_approx(previous),
		"Invalid zoom leaves camera unchanged"
	)
