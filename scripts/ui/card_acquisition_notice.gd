class_name CardAcquisitionNotice
extends PanelContainer
## 非模态获取提示；连续获取合并展示，换局和读档取消旧动画。

signal inspect_requested(uid: int)

const DISPLAY_SECONDS: float = 12.0
const MAX_LIST_HEIGHT: float = 156.0
const LINE_HEIGHT: float = 28.0

var _uids: PackedInt32Array = []
var _fade: Tween

@onready var _names: RichTextLabel = %AcquiredNames
@onready var _timer: Timer = $Timer


func _ready() -> void:
	_names.meta_clicked.connect(_on_card_link_clicked)
	(%DismissNotice as Button).pressed.connect(clear)
	_timer.timeout.connect(_on_timeout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func clear() -> void:
	_timer.stop()
	if _fade != null:
		_fade.kill()
	_uids.clear()
	hide()


func show_cards(state: VillageState, uids: PackedInt32Array) -> void:
	for uid: int in uids:
		if state.find_card(uid) != null and not _uids.has(uid):
			_uids.append(uid)
	var lines: PackedStringArray = []
	for uid: int in _uids:
		var card: CardDefinition = state.find_card(uid)
		if card != null:
			lines.append(
				(
					"[url=%d]%s[/url]  [color=#999f92]%s[/color]"
					% [uid, card.display_name.replace("[", "[lb]"), card.kind_name()]
				)
			)
	if lines.is_empty():
		clear()
		return
	_names.text = "\n".join(lines)
	_names.custom_minimum_size.y = minf(MAX_LIST_HEIGHT, lines.size() * LINE_HEIGHT)
	(%AcquiredTitle as Label).text = "获得新卡 · %d 张" % lines.size()
	if _fade != null:
		_fade.kill()
	modulate.a = 0.0
	show()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.2)
	_timer.start(DISPLAY_SECONDS)


# RichTextLabel 的元数据为引擎 Variant 边界，仅接受由本组件生成的 UID。
func _on_card_link_clicked(meta: Variant) -> void:
	if not meta is String or not String(meta).is_valid_int():
		return
	var uid: int = String(meta).to_int()
	if _uids.has(uid):
		inspect_requested.emit(uid)
		clear()


func _on_timeout() -> void:
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.4)
	_fade.tween_callback(clear)


func _on_mouse_entered() -> void:
	_timer.stop()
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0


func _on_mouse_exited() -> void:
	if visible:
		_timer.start(DISPLAY_SECONDS)
