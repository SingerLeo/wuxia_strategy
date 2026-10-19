class_name SaveSystem
extends RefCounted
## 存档读写（H 类）：多个手动槽位 + 一个自动存档位，JSON 带版本号与时间戳。
## 版本不符拒绝读取。默认目录是用户目录；测试可传别的目录以免污染真实存档。

const SAVE_VERSION := 1
const SLOT_COUNT := 3            ## 手动槽位数
const AUTOSAVE := -1             ## 伪槽位：自动存档（只写于每旬结束，界面只能读）
const DEFAULT_DIR := "user://"

var dir: String


func _init(p_dir: String = DEFAULT_DIR) -> void:
	dir = p_dir
	if not dir.ends_with("/"):
		dir += "/"


func slot_path(index: int) -> String:
	if index == AUTOSAVE:
		return dir + "save_autosave.json"
	return dir + "save_slot_%d.json" % (index + 1)


func has_save(index: int) -> bool:
	return FileAccess.file_exists(slot_path(index))


## 写入存档（自动带上版本号与保存时间）。成功返回 true。
func save(index: int, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var with_meta := state.duplicate()
	with_meta["version"] = SAVE_VERSION
	with_meta["saved_at"] = Time.get_datetime_string_from_system().replace("T", " ")
	var f := FileAccess.open(slot_path(index), FileAccess.WRITE)
	if f == null:
		push_warning("存档写入失败：%s" % slot_path(index))
		return false
	f.store_string(JSON.stringify(with_meta, "  "))
	f.close()
	return true


## 读取存档；文件不存在、JSON 损坏或版本不符都返回 {}。
func load_state(index: int) -> Dictionary:
	if not has_save(index):
		return {}
	var f := FileAccess.open(slot_path(index), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("存档损坏：%s（%s）" % [slot_path(index), json.get_error_message()])
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("存档损坏：%s" % slot_path(index))
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("存档版本不符（需要 %d）：%s" % [SAVE_VERSION, slot_path(index)])
		return {}
	return parsed


## 槽位摘要（用于存档界面展示）；空槽/坏档返回 {}
func info(index: int) -> Dictionary:
	var state := load_state(index)
	if state.is_empty():
		return {}
	var sect: Dictionary = state["sect"]
	return {
		"sect_name": sect["name"],
		"xun": int(sect["xun"]),
		"disciples": (sect["disciples"] as Array).size(),
		"silver": int(sect["silver"]),
		"saved_at": state.get("saved_at", ""),
	}


func clear(index: int) -> void:
	if has_save(index):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(index)))


func clear_all() -> void:
	for i in SLOT_COUNT:
		clear(i)
	clear(AUTOSAVE)
