class_name WeatherDefinition
extends Resource
## 只读天气配置；业务修正由 EffectResolver 统一应用，视觉参数不参与模拟。

enum Kind {
	CLEAR = 0,
	CLOUDY = 1,
	RAIN = 2,
	THUNDERSTORM = 3,
	FOG = 4,
	COUNT = 5,
}

@export var kind: Kind = Kind.CLEAR
@export var display_name: String = "晴朗"
@export_multiline var description: String = "晴空，生产与防守不受影响。"
@export_range(1, 100) var weight: int = 40
@export_range(0, 20) var water_income: int = 0
@export_range(-20, 20) var stamina_recovery: int = 0
@export var modifiers: Array[StatModifier] = []
@export var veil: Color = Color(0, 0, 0, 0)
@export_range(0.0, 1.0) var rainfall: float = 0.0
@export_range(0.0, 1.0) var fog_density: float = 0.0


func validation_error() -> String:
	if kind < Kind.CLEAR or kind >= Kind.COUNT:
		return "天气枚举非法"
	if display_name.is_empty() or description.is_empty() or weight < 1 or weight > 100:
		return "天气名称、说明或权重非法"
	if water_income < 0 or water_income > 20 or absi(stamina_recovery) > 20:
		return "天气收入或恢复超出范围"
	if not valid_color(veil):
		return "天气遮罩颜色非法"
	for value: float in [rainfall, fog_density]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return "天气表现强度非法"
	for modifier: StatModifier in modifiers:
		var error: String = ResourceValidation.modifier_error(modifier)
		if not error.is_empty():
			return error
		if modifier.duration != 0:
			return "天气修正不得带临时倒计时"
	return ""


static func valid_color(color: Color) -> bool:
	for value: float in [color.r, color.g, color.b, color.a]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return false
	return true
