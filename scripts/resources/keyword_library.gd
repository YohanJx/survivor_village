class_name KeywordLibrary
extends Resource

@export var definitions: Array[KeywordDefinition] = []


func validation_error() -> String:
	if definitions.is_empty():
		return "词条库为空"
	var names: Dictionary[String, bool] = {}
	var ids: Dictionary[String, bool] = {}
	var id_validator: RegEx = RegEx.new()
	id_validator.compile("^[a-z][a-z0-9_]*$")
	var validator: RegEx = RegEx.new()
	validator.compile("^[\\p{Han}A-Za-z0-9]+$")
	for definition: KeywordDefinition in definitions:
		if definition == null:
			return "词条为空"
		var error: String = definition.validation_error()
		if not error.is_empty():
			return error
		if id_validator.search(definition.id) == null or ids.has(definition.id):
			return "词条标识非法或重复"
		ids[definition.id] = true
		if validator.search(definition.title) == null:
			return "词条名称必须由中文、字母或数字组成"
		if names.has(definition.title):
			return "词条名称重复"
		names[definition.title] = true
	return ""
