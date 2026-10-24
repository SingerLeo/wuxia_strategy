class_name SectMap
extends RefCounted
## 山门地图：格子地形、建筑占地、能否摆放、邻接加成。纯函数，只读 Sect.layout，不改状态。
##
## Sect.layout: 建筑 id -> {"x": int, "y": int, "rot": int}
##   (x, y) 是占地左上角的格子坐标；rot 为 0 或 1，1 表示宽高对调（旋转 90°）。
## 没有出现在 layout 里的建筑视为"未摆放"。

const NONE := Vector2i(-1, -1)


static func width() -> int:
	return String(Catalog.MAP[0]).length()


static func height() -> int:
	return Catalog.MAP.size()


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width() and cell.y < height()


## 地形字符：'.' 空地 '#' 山峰 '~' 河流；越界返回 ""
static func terrain(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return String(Catalog.MAP[cell.y])[cell.x]


static func is_buildable(cell: Vector2i) -> bool:
	return terrain(cell) == "."


## 建筑占地的 [宽, 高]（已按旋转对调）
static func size_of(id: StringName, rot: int = 0) -> Vector2i:
	var s: Array = Catalog.BUILDINGS[id]["size"]
	return Vector2i(s[1], s[0]) if rot % 2 == 1 else Vector2i(s[0], s[1])


## 建筑摆在 origin（左上角）时占的全部格子
static func cells(id: StringName, origin: Vector2i, rot: int = 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sz := size_of(id, rot)
	for dy in sz.y:
		for dx in sz.x:
			out.append(origin + Vector2i(dx, dy))
	return out


## 已摆放建筑占的格子；未摆放返回空
static func placed_cells(s: Sect, id: StringName) -> Array[Vector2i]:
	if not s.layout.has(id):
		return []
	var p: Dictionary = s.layout[id]
	return cells(id, Vector2i(p["x"], p["y"]), p["rot"])


## 某格子上是哪座建筑；没有返回 &""
static func building_at(s: Sect, cell: Vector2i) -> StringName:
	for id in s.layout:
		if placed_cells(s, id).has(cell):
			return id
	return &""


## 能不能把 id 摆在 origin（旋转 rot）。可以返回 ""，不行返回原因。
## 自己原来的位置不算占用，所以"移动"可以原地微调。
static func placement_error(s: Sect, id: StringName, origin: Vector2i, rot: int) -> String:
	if not Catalog.BUILDINGS.has(id):
		return "没有这种建筑"
	for c in cells(id, origin, rot):
		if not in_bounds(c):
			return "超出山门范围"
		match terrain(c):
			"#": return "山峰挡住了"
			"~": return "河流挡住了"
		var other := building_at(s, c)
		if other != &"" and other != id:
			return "与%s重叠" % Catalog.BUILDINGS[other]["name"]
	return ""


static func can_place(s: Sect, id: StringName, origin: Vector2i, rot: int) -> bool:
	return placement_error(s, id, origin, rot) == ""


## 两座已摆放建筑之间的最短曼哈顿距离；任一未摆放返回 -1。紧挨（共边）时为 1。
static func distance(s: Sect, a: StringName, b: StringName) -> int:
	var ca := placed_cells(s, a)
	var cb := placed_cells(s, b)
	if ca.is_empty() or cb.is_empty():
		return -1
	var best := 1 << 20
	for x in ca:
		for y in cb:
			best = mini(best, absi(x.x - y.x) + absi(x.y - y.y))
	return best


static func are_adjacent(s: Sect, a: StringName, b: StringName) -> bool:
	return distance(s, a, b) == 1


## 当前对 id 生效的邻接规则：[{rule, mult, note}]。双方都已摆放且条件成立才算。
static func active_synergies(s: Sect, id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rule in Catalog.SYNERGIES:
		if rule["target"] != id:
			continue
		var d := distance(s, id, rule["other"])
		if d < 0:
			continue
		var hit := false
		match rule["kind"]:
			"adjacent": hit = (d == 1)
			"near": hit = (d <= int(rule["dist"]))
		if hit:
			out.append({"other": rule["other"], "mult": float(rule["mult"]), "note": rule["note"]})
	return out


## 默认的"抓取点"：让建筑的中心大致跟着鼠标走（偶数边长时偏向右下）。
## 鼠标所在格 cursor 对应的左上角 = cursor - grab。
static func default_grab(id: StringName, rot: int = 0) -> Vector2i:
	return size_of(id, rot) / 2


## 假设把 id 摆在 origin，哪些已摆放的建筑会因此与它产生位置影响：{建筑 id: 倍率}。
## 既包括"它受邻居影响"（target 是它），也包括"邻居受它影响"（other 是它）。
## 只用于摆放预览：临时改动 layout 后立刻还原。
static func preview_links(s: Sect, id: StringName, origin: Vector2i, rot: int) -> Dictionary:
	var had := s.layout.has(id)
	var old: Dictionary = s.layout.get(id, {})
	s.layout[id] = {"x": origin.x, "y": origin.y, "rot": rot % 2}
	var out := {}
	for rule in Catalog.SYNERGIES:
		var other: StringName
		if rule["target"] == id:
			other = rule["other"]
		elif rule["other"] == id:
			other = rule["target"]
		else:
			continue
		var d := distance(s, id, other)
		if d < 0:
			continue
		var hit := false
		match rule["kind"]:
			"adjacent": hit = (d == 1)
			"near": hit = (d <= int(rule["dist"]))
		if hit:
			out[other] = float(out.get(other, 1.0)) * float(rule["mult"])
	if had:
		s.layout[id] = old
	else:
		s.layout.erase(id)
	return out


## 假设把 id 摆在 origin（旋转 rot），它的位置倍率会是多少（用于摆放时的预览）。
## 临时改动 layout 后立刻还原，不留下副作用。
static func preview_factor(s: Sect, id: StringName, origin: Vector2i, rot: int) -> float:
	var had := s.layout.has(id)
	var old: Dictionary = s.layout.get(id, {})
	s.layout[id] = {"x": origin.x, "y": origin.y, "rot": rot % 2}
	var f := factor(s, id)
	if had:
		s.layout[id] = old
	else:
		s.layout.erase(id)
	return f


## 位置带来的效果倍率（所有生效规则相乘）。没有摆放信息时为 1.0，不影响效果。
static func factor(s: Sect, id: StringName) -> float:
	var f := 1.0
	for syn in active_synergies(s, id):
		f *= syn["mult"]
	return f
