class_name SaveSystem
extends RefCounted
## 存档读写（H 类）：单个 JSON 文件，带版本号；版本不符拒绝读取。
## 默认路径是用户目录；测试可传别的路径以免污染真实存档。

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func has_save() -> bool:
	return FileAccess.file_exists(path)


## 写入存档（自动带上版本号）。成功返回 true。
func save(state: Dictionary) -> bool:
	var with_version := state.duplicate()
	with_version["version"] = SAVE_VERSION
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("存档写入失败：%s" % path)
		return false
	f.store_string(JSON.stringify(with_version, "  "))
	f.close()
	return true


## 读取存档；文件不存在、JSON 损坏或版本不符都返回 {}。
func load_state() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("存档损坏：%s（%s）" % [path, json.get_error_message()])
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("存档损坏：%s" % path)
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("存档版本不符（需要 %d）：%s" % [SAVE_VERSION, path])
		return {}
	return parsed


## 删除存档（测试与"开新局清档"用）
func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
