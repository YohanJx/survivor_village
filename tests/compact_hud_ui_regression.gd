class_name CompactHudUiRegression
extends RefCounted
## 真实视口验证紧凑 HUD、详情入口与 Esc 的逐层关闭顺序。


static func run(tree: SceneTree, viewport: Viewport, game: VillageGame, check: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var dock: ActionDock = dashboard.get_node("%ActionSplit") as ActionDock
	var resources: Control = dashboard.get_node("Margin/Layout/Resources") as Control
	check.call(resources.size.y <= 40.0, "Resources use a compact single-line strip")
	var menu: HudMenu = dashboard.get_node("%HeaderMenu") as HudMenu
	check.call(not menu.visible, "Secondary header actions are collapsed by default")
	var saved: PackedInt32Array = game.state.resources.duplicate()
	var slot: int = game.state.slot
	var used: int = game.state.actions_used
	var uid: int = game.state.hand[0].uid
	dashboard.card_selected.emit(uid)
	await tree.process_frame
	dashboard.overlay.show_card(uid)
	await _key(tree, viewport, KEY_ESCAPE)
	check.call(not dashboard.overlay.visible and dashboard.has_visible_confirmation(), "Esc closes inspection before the card popup")
	await _key(tree, viewport, KEY_ESCAPE, true)
	check.call(dashboard.has_visible_confirmation(), "Repeated Esc does not close another layer")
	await _key(tree, viewport, KEY_ESCAPE)
	check.call(not dashboard.has_visible_confirmation(), "Esc collapses the card popup with selection retained")
	await _key(tree, viewport, KEY_ENTER)
	check.call(game.state.slot == slot and game.state.actions_used == used, "Enter cannot execute the hidden popup")
	var details: Button = dashboard.get_node("%MapDetailsButton") as Button
	details.button_pressed = true
	dock.set_expanded(true)
	await _key(tree, viewport, KEY_ESCAPE)
	check.call(not details.button_pressed and dock.is_expanded(), "Esc closes map details before the card popup")
	(dashboard.get_node("%MenuButton") as Button).pressed.emit()
	await _key(tree, viewport, KEY_ESCAPE)
	check.call(not menu.visible and dock.is_expanded(), "Esc closes the header menu before cards")
	check.call(game.state.resources == saved, "HUD disclosure and Esc consume no resources")
	dashboard.card_selected.emit(-1)


static func _key(tree: SceneTree, viewport: Viewport, code: Key, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	viewport.push_input(event, true)
	await tree.process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	viewport.push_input(event, true)
	await tree.process_frame
