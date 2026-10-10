class_name VillageCardButton
extends Button

var card: CardDefinition
var cost: String = ""
var is_selected: bool = false
var locked: bool = false
var reusable: bool = false
var _background: StyleBoxFlat = StyleBoxFlat.new()

@onready var _keywords: RichTextLabel = %Keywords


func _ready() -> void:
	custom_minimum_size = Vector2(187, 191)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = (
		"%s\n收益：%s\n代价：%s\n消耗：%s" % [card.display_name, card.positive, card.negative, cost]
	)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_keywords.text = KeywordText.format_text(" · ".join(card.tags))
	_keywords.add_theme_color_override("default_color", UiElements.TEXT_SECONDARY)


func _draw() -> void:
	if card == null:
		return
	var accent: Color = UiElements.ACCENT

	_background.bg_color = Color("263b30") if is_hovered() else Color("1d2e27")
	_background.border_color = accent if is_selected else Color("394c3a")
	_background.set_border_width_all(2 if is_selected else 1)
	_background.set_corner_radius_all(9)
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(14, 15, 3, 13), UiElements.CARD_COLORS[card.color])
	var font: Font = get_theme_default_font()
	draw_string(
		font,
		Vector2(24, 26),
		card.kind_name() + (" / 常驻" if reusable else " / 单次"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		UiElements.TEXT_SECONDARY
	)
	if locked:
		draw_circle(Vector2(size.x - 17, 21), 3, UiElements.TEXT_SECONDARY)
	_draw_symbol(Vector2(31, 56), card.icon, UiElements.CARD_COLORS[card.color])
	draw_string(
		font,
		Vector2(14, 92),
		card.display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 26,
		19,
		UiElements.TEXT_PRIMARY
	)
	draw_line(Vector2(14, 130), Vector2(size.x - 14, 130), Color("3b4d3a"), 1)
	var cost_parts: PackedStringArray = cost.split(" · ")
	var first: String = " · ".join(cost_parts.slice(0, 2))
	var second: String = " · ".join(cost_parts.slice(2))
	draw_string(
		font,
		Vector2(14, 151),
		first,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 26,
		13,
		UiElements.TEXT_SECONDARY
	)
	draw_string(
		font,
		Vector2(14, 172),
		second if not second.is_empty() else ("点击查看效果" if not locked else "条件尚未满足"),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 26,
		13,
		UiElements.TEXT_SECONDARY
	)
	if is_selected:
		draw_circle(Vector2(size.x - 22, 57), 8, accent)
		draw_line(Vector2(size.x - 26, 57), Vector2(size.x - 23, 60), Color("203128"), 2)
		draw_line(Vector2(size.x - 23, 60), Vector2(size.x - 18, 54), Color("203128"), 2)


func _draw_symbol(point: Vector2, icon: GameTypes.Icon, color: Color) -> void:
	match icon:
		GameTypes.Icon.LEAF:
			draw_colored_polygon(
				PackedVector2Array(
					[
						point + Vector2(-9, 5),
						point + Vector2(-10, -6),
						point + Vector2(2, -13),
						point + Vector2(12, -11),
						point + Vector2(8, 3),
						point + Vector2(-1, 10)
					]
				),
				color
			)
			draw_line(point + Vector2(-7, 10), point + Vector2(7, -7), Color("203128"), 2)
		GameTypes.Icon.WATER:
			draw_colored_polygon(
				PackedVector2Array(
					[
						point + Vector2(0, -14),
						point + Vector2(-10, 3),
						point + Vector2(-6, 10),
						point + Vector2(6, 10),
						point + Vector2(10, 3)
					]
				),
				color
			)
			draw_line(point + Vector2(-4, 2), point + Vector2(-2, 6), Color("d9e9d9"), 2)
		GameTypes.Icon.POWER:
			draw_colored_polygon(
				PackedVector2Array(
					[
						point + Vector2(2, -14),
						point + Vector2(-10, 3),
						point + Vector2(-1, 3),
						point + Vector2(-3, 14),
						point + Vector2(10, -3),
						point + Vector2(1, -3)
					]
				),
				color
			)
		GameTypes.Icon.WALL:
			for x: int in [-10, 0, 10]:
				draw_rect(Rect2(point + Vector2(x - 2, -12), Vector2(5, 24)), color)
			draw_line(point + Vector2(-13, -5), point + Vector2(13, -5), color, 3)
			draw_line(point + Vector2(-13, 5), point + Vector2(13, 5), color, 3)
		GameTypes.Icon.BOW:
			draw_arc(point - Vector2(6, 0), 13, -PI / 2, PI / 2, 16, color, 3)
			draw_line(point + Vector2(-6, -13), point + Vector2(-6, 13), color, 1)
			draw_line(point + Vector2(-12, 0), point + Vector2(15, 0), color, 2)
		GameTypes.Icon.MOON:
			draw_circle(point, 12, color)
			draw_circle(point + Vector2(6, -4), 10, Color("1d2e27"))
		GameTypes.Icon.CROSS:
			draw_rect(Rect2(point + Vector2(-4, -13), Vector2(8, 26)), color)
			draw_rect(Rect2(point + Vector2(-13, -4), Vector2(26, 8)), color)
		GameTypes.Icon.SUN:
			draw_circle(point, 7, color)
			for i: int in 8:
				var direction: Vector2 = Vector2.from_angle(i * TAU / 8)
				draw_line(point + direction * 10, point + direction * 15, color, 2)
		GameTypes.Icon.PEOPLE:
			for x: int in [-8, 8]:
				draw_circle(point + Vector2(x, -7), 5, color)
				draw_rect(Rect2(point + Vector2(x - 5, 0), Vector2(10, 11)), color)
		GameTypes.Icon.TRAP:
			for x: int in [-9, 0, 9]:
				draw_colored_polygon(
					PackedVector2Array(
						[
							point + Vector2(x - 4, 8),
							point + Vector2(x, -10),
							point + Vector2(x + 4, 8)
						]
					),
					color
				)
		GameTypes.Icon.CAMP:
			draw_colored_polygon(
				PackedVector2Array(
					[point + Vector2(-12, 9), point + Vector2(0, -13), point + Vector2(12, 9)]
				),
				color
			)
			draw_colored_polygon(
				PackedVector2Array(
					[point + Vector2(-4, 9), point + Vector2(0, -2), point + Vector2(4, 9)]
				),
				Color("203128")
			)
		GameTypes.Icon.HOME:
			draw_colored_polygon(
				PackedVector2Array(
					[point + Vector2(-14, -2), point + Vector2(0, -14), point + Vector2(14, -2)]
				),
				color
			)
			draw_rect(Rect2(point + Vector2(-10, 0), Vector2(20, 12)), color)
			draw_rect(Rect2(point + Vector2(-3, 5), Vector2(6, 7)), Color("203128"))
		_:
			draw_rect(Rect2(point + Vector2(-12, -10), Vector2(24, 21)), color, false, 2)
			draw_line(point + Vector2(-12, -3), point + Vector2(12, -3), color, 2)
			draw_line(point + Vector2(0, -10), point + Vector2(0, 11), color, 2)
