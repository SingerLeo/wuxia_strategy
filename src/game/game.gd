extends Node
## 全局游戏状态（autoload 名称：Game）。UI 只读取这里的数据，并通过这里的方法修改。

signal state_changed
signal log_added(text: String)

const INITIAL_DISCIPLES := 12

var sect: Sect
## 弟子 id -> 本旬修炼的属性；不在表内或为 &"" 表示休息
var plans: Dictionary = {}


func _ready() -> void:
	if sect == null:
		new_game()


func new_game(seed_value: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	sect = Sect.new("青云门", rng)
	sect.silver = 1000
	plans.clear()
	for i in INITIAL_DISCIPLES:
		sect.add_disciple(DiscipleFactory.create(rng, i, NameGen.person(rng)))
	state_changed.emit()


func find_disciple(id: int) -> Disciple:
	for d in sect.disciples:
		if d.id == id:
			return d
	return null


func plan_of(id: int) -> StringName:
	return plans.get(id, &"")


## stat 为 &"" 表示休息
func set_plan(id: int, stat: StringName) -> void:
	plans[id] = stat
	state_changed.emit()


func end_xun() -> void:
	var training := {}
	for id in plans:
		var stat: StringName = plans[id]
		training[id] = TrainingPlan.train(stat) if stat != &"" else TrainingPlan.resting()
	var reports := sect.advance_xun(training)
	for r in reports:
		var levels: int = r["report"]["levels"]
		if levels > 0:
			var d := find_disciple(r["id"])
			var stat: StringName = plans[d.id]
			log_added.emit("%s 的%s提升了 %d 级，现为 %d。" % [d.display_name, UiText.STAT[stat], levels, d.stats[stat]])
	log_added.emit("—— %s ——" % UiText.date_text(sect))
	state_changed.emit()
