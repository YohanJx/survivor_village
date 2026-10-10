class_name KeywordText
extends RefCounted
## 使用原生 RichTextLabel hint 标签生成逐词悬停说明，匹配规则只初始化一次。

const LIBRARY_PATH: String = "res://data/ui/keywords.tres"

static var _definitions: Dictionary[String, KeywordDefinition] = {}
static var _pattern: RegEx = RegEx.new()
static var _initialized: bool = false


static func format_text(text: String) -> String:
	if not _initialize_library():
		return _escape(text)
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _pattern.search_all(text):
		result += _escape(text.substr(cursor, found.get_start() - cursor))
		var name: String = found.get_string()
		var definition: KeywordDefinition = _definitions[name]
		var hint: String = _escape(definition.title + "：" + definition.description).replace(
			'"', "＂"
		)
		result += '[hint="%s"][u]%s[/u][/hint]' % [hint, _escape(name)]
		cursor = found.get_end()
	return result + _escape(text.substr(cursor))


static func definition(name: String) -> KeywordDefinition:
	if not _initialize_library():
		return null
	return _definitions.get(name)


static func _initialize_library() -> bool:
	if _initialized:
		return true
	var titles: Array[String] = []
	var library: KeywordLibrary = load(LIBRARY_PATH) as KeywordLibrary
	if library == null:
		push_error("词条库无法加载")
		return false
	var validation_error: String = library.validation_error()
	if not validation_error.is_empty():
		push_error(validation_error)
		return false
	for entry: KeywordDefinition in library.definitions:
		_definitions[entry.title] = entry
		titles.append(entry.title)
	titles.sort_custom(_longest_first)
	var error: Error = _pattern.compile("|".join(titles))
	if error != OK:
		push_error("词条正则初始化失败")
		return false
	_initialized = true
	return true


static func _longest_first(left: String, right: String) -> bool:
	return left.length() > right.length()


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
