class_name KeywordLibrary
extends Resource

@export var definitions: Array[KeywordDefinition] = []


func validation_error() -> String:
	if definitions.is_empty():
		return "词条库为空"
	var names: Dictionary[String, bool] = {}
	var validator: RegEx = RegEx.new()
	validator.compile("^[\\p{Han}A-Za-z0-9]+$")
	for definition: KeywordDefinition in definitions:
		if definition == null or definition.description.is_empty():
			return "词条缺少解释"
		if validator.search(definition.title) == null:
			return "词条名称必须由中文、字母或数字组成"
		if names.has(definition.title):
			return "词条名称重复"
		names[definition.title] = true
	return ""
