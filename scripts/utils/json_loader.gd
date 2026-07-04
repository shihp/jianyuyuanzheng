class_name JSONLoader
## JSONLoader - JSON 文件加载工具
## 全局静态工具类，无需实例化
## 对应 Java 的 Jackson ObjectMapper / JS 的 JSON.parse + fetch
extends RefCounted

# ========== 公开静态接口 ==========

## 加载 JSON 文件并返回 Dictionary
static func load_dict(path: String) -> Dictionary:
	var text: String = _read_file(path)
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("[JSONLoader] 解析失败 %s: %s (行 %d)" % [path, json.get_error_message(), json.get_error_line()])
		return {}
	if not json.data is Dictionary:
		push_error("[JSONLoader] 期望 Dictionary，得到 %s" % typeof(json.data))
		return {}
	return json.data


## 加载 JSON 文件并返回 Array
static func load_array(path: String) -> Array:
	var text: String = _read_file(path)
	if text.is_empty():
		return []
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("[JSONLoader] 解析失败 %s: %s (行 %d)" % [path, json.get_error_message(), json.get_error_line()])
		return []
	if not json.data is Array:
		push_error("[JSONLoader] 期望 Array，得到 %s" % typeof(json.data))
		return []
	return json.data


## 保存 Dictionary 到 JSON 文件
static func save_dict(path: String, data: Dictionary, pretty: bool = true) -> bool:
	var json_string: String = JSON.stringify(data, "\t" if pretty else "")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[JSONLoader] 无法写入文件 %s: %s" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(json_string)
	file.close()
	return true

# ========== 内部方法 ==========

static func _read_file(path: String) -> String:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("[JSONLoader] 文件不存在: %s" % path)
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[JSONLoader] 无法读取文件 %s: %s" % [path, FileAccess.get_open_error()])
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
