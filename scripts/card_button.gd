class_name VillageCardButton
extends Button

signal inspect_requested

var card: CardDefinition:
	set(value):
		card = value
		if is_node_ready():
			_keywords.text = (
				KeywordText.format_text(" · ".join(card.keyword_names())) if card != null else ""
			)
var is_selected: bool = false
var _background: StyleBoxFlat = StyleBoxFlat.new()

@onready var _keywords: RichTextLabel = %Keywords


func _ready() -> void:
	custom_minimum_size = Vector2(210, 294)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	(%CardFace as Control).minimum_size_changed.connect(_on_face_minimum_size_changed)
	_keywords.text = KeywordText.format_text(" · ".join(card.keyword_names()))
	_keywords.add_theme_color_override("default_color", UiElements.TEXT_SECONDARY)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if mouse.pressed and not disabled:
				inspect_requested.emit()


func update_face(state: VillageState) -> void:
	(%CardFace as VillageCardFace).update_view(state, card)
	(%CardFace as VillageCardFace).set_selected(is_selected)
	call_deferred("_update_minimum_height")


func _draw() -> void:
	if is_selected or is_hovered() or has_focus():
		_background.bg_color = Color.TRANSPARENT
		_background.border_color = UiElements.ACCENT
		_background.set_border_width_all(3 if is_selected else 1)
		_background.set_corner_radius_all(3)
		draw_style_box(_background, Rect2(Vector2.ZERO, size))


func _on_face_minimum_size_changed() -> void:
	call_deferred("_update_minimum_height")


func _update_minimum_height() -> void:
	custom_minimum_size.y = maxf(294.0, (%CardFace as Control).get_combined_minimum_size().y)
