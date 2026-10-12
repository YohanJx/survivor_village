class_name DayReportPanel
extends VBoxContainer
## 日终报告只展示已结算的独立记录，继续按钮请求状态确认。

signal continue_requested

@onready var _heading: Label = $Heading
@onready var _summary: Label = $Summary
@onready var _resources: Label = $Scroll/Resources
@onready var _notes: Label = $Notes
@onready var _continue: Button = $ContinueButton


func _ready() -> void:
	_continue.pressed.connect(continue_requested.emit)


func update_view(report: DayReport) -> void:
	_heading.text = "我们活下来了……第 %d 夜" % report.day
	_summary.text = (
		"击退 %d 名感染者  ·  幸存者 %d → %d  ·  村庄耐久 %d → %d  ·  已探索 %d → %d 格"
		% [report.kills, report.population_before, report.population_after,
			roundi(report.core_before), roundi(report.core_after),
			report.explored_before, report.explored_after]
	)
	var changes: PackedStringArray = []
	for stock: int in GameTypes.Stock.COUNT:
		var before: int = report.resources_before[stock]
		var after: int = report.resources_after[stock]
		if before != after:
			changes.append("%s    %d → %d    (%+d)" % [GameTypes.STOCK_NAMES[stock], before, after, after - before])
	_resources.text = "\n".join(changes) if not changes.is_empty() else "今日没有库存变化。"
	_notes.text = "\n".join(report.notes) if not report.notes.is_empty() else "今夜没有额外遭遇。"
