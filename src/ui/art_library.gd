class_name ArtLibrary
extends RefCounted
## 美术资源库：规定图片放在哪、叫什么，找得到就用图，找不到返回 null，由调用方用程序画的版本顶上。
## 所以没有任何图片时游戏照常运行；以后把 PNG 放进 assets/art/ 对应位置，重启就生效，不用改代码。
## 规格（尺寸、命名、AI 出图提示词）见 docs/art-spec.md。

const DEFAULT_ROOT := "res://assets/art/"

## 图片根目录。平时就是 DEFAULT_ROOT；测试里会临时指向别的目录。
static var root: String = DEFAULT_ROOT
static var _cache: Dictionary = {}


## 读取 assets/art/ 下的一张图；不存在返回 null。结果（包括"没有"）会缓存。
## 开发时直接读 PNG 文件（不需要先在编辑器里导入）；导出后读已导入的资源。
static func load_png(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var tex: Texture2D = null
	var path := root + rel
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(path):
		tex = load(path)
	_cache[rel] = tex
	return tex


## 清掉缓存（换了图之后想不重启就刷新时用）
## 注意：不能叫 reload——和 Godot 内置的 Script.reload()（重载脚本并重置静态变量）重名，调用的会是内置那个。
static func clear_cache() -> void:
	_cache.clear()


## 改图片根目录并清缓存（测试用）。
## 注意：建议用这个函数而不是在类外面直接写 ArtLibrary.root = ...
static func set_root(path: String) -> void:
	root = path if path.ends_with("/") else path + "/"
	_cache.clear()


## 界面皮肤贴图，如 panel_ornate、button_primary_hover，放在 ui/ 下
static func ui_texture(name: String) -> Texture2D:
	return load_png("ui/%s.png" % name)


## 建筑精灵。查找顺序（旋转 rot=1 时，每一项先找带 _r 的旋转版）：
##   buildings/<id>_lv<等级>.png  →  buildings/<id>.png
## 找不到旋转版就退回普通版（引擎会按新占地的宽度缩放它）。
static func building_texture(id: StringName, level: int, rot: int = 0) -> Texture2D:
	var names: Array[String] = ["%s_lv%d" % [id, level], str(id)]
	for n in names:
		if rot % 2 == 1:
			var rotated := load_png("buildings/%s_r.png" % n)
			if rotated != null:
				return rotated
		var plain := load_png("buildings/%s.png" % n)
		if plain != null:
			return plain
	return null


## 整张山门地图的底图（含地面与河流）。有的话会替换着色器画的地形。
static func map_background() -> Texture2D:
	return load_png("map/ground.png")


## 窗口背景图。有的话会替换着色器画的水墨远山。
static func window_background() -> Texture2D:
	return load_png("ui/background.png")
