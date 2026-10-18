extends SceneTree
## 数值模拟报告：批量生成弟子，每人专攻自己上限最高的一项属性，逐年打印成长曲线。
## 用法（在项目根目录）：
##   godot_console --headless -s tools/sim_report.gd -- --n=500 --years=20 --seed=1
## 修炼策略：体力 >= TRAIN_MIN_STAMINA 就修炼，否则休息。

const CHECK_YEARS := [0, 1, 2, 3, 5, 8, 10, 15, 20, 30]
const TRAIN_MIN_STAMINA := 40
const CURVE_NAMES := ["早慧", "晚成", "稳健", "起伏"]


func _initialize() -> void:
	var opts := _parse_args()
	var n: int = opts["n"]
	var years: int = opts["years"]

	var rng := RandomNumberGenerator.new()
	rng.seed = opts["seed"]
	var sect := Sect.new("模拟派", rng)
	var focus := {}
	for i in n:
		var d := DiscipleFactory.create(rng, i)
		sect.add_disciple(d)
		focus[i] = _best_stat(d)

	var history := {0: _snapshot(sect, focus)}
	var trained := 0
	var slots := 0
	for x in years * Balance.XUN_PER_YEAR:
		var plans := {}
		for d in sect.disciples:
			if d.stamina >= TRAIN_MIN_STAMINA:
				plans[d.id] = TrainingPlan.train(focus[d.id])
			else:
				plans[d.id] = TrainingPlan.resting()
		for r in sect.advance_xun(plans):
			slots += 1
			if r["report"]["trained"]:
				trained += 1
		if (x + 1) % Balance.XUN_PER_YEAR == 0:
			history[(x + 1) / Balance.XUN_PER_YEAR] = _snapshot(sect, focus)

	_print_report(n, years, opts["seed"], history, float(trained) / maxi(slots, 1))
	quit()


func _parse_args() -> Dictionary:
	var o := {"n": 500, "years": 20, "seed": 1}
	for a in OS.get_cmdline_user_args():
		for key in o.keys():
			if a.begins_with("--%s=" % key):
				o[key] = int(a.get_slice("=", 1))
	return o


## 上限最高的属性（并列取先出现的）
func _best_stat(d: Disciple) -> StringName:
	var best: StringName = Balance.SKILLS[0]
	for s in Balance.SKILLS:
		if Growth.skill_cap(d, s) > Growth.skill_cap(d, best):
			best = s
	return best


func _snapshot(sect: Sect, focus: Dictionary) -> Array:
	var rows := []
	for d in sect.disciples:
		var s: StringName = focus[d.id]
		rows.append({
			"value": d.skills[s],
			"cap": Growth.skill_cap(d, s),
			"curve": d.curve,
			"age": d.age_years(),
		})
	return rows


func _pct(sorted_vals: Array, p: float) -> int:
	return sorted_vals[roundi((sorted_vals.size() - 1) * p)]


func _print_report(n: int, years: int, seed_value: int, history: Dictionary, duty: float) -> void:
	print("")
	print("===== 数值模拟报告 =====")
	print("弟子 %d 人，模拟 %d 年，种子 %d，每人专攻上限最高的属性" % [n, years, seed_value])
	print("修炼出勤率 %.0f%%（其余旬在休息恢复体力）" % (duty * 100.0))

	var first: Array = history[0]
	var caps := []
	for r in first:
		caps.append(r["cap"])
	caps.sort()
	print("专攻属性的上限：平均 %.1f  P10 %d  P50 %d  P90 %d  最高 %d" % [
		_mean(caps), _pct(caps, 0.1), _pct(caps, 0.5), _pct(caps, 0.9), caps[caps.size() - 1]])

	print("")
	print("--- 专攻属性随时间的变化 ---")
	print("%4s %6s %5s %5s %5s %5s %7s %7s %7s" % ["年", "平均", "P10", "P50", "P90", "最高", ">=60", ">=80", "到顶"])
	for y in CHECK_YEARS:
		if not history.has(y):
			continue
		var rows: Array = history[y]
		var vals := []
		var ge60 := 0
		var ge80 := 0
		var capped := 0
		for r in rows:
			vals.append(r["value"])
			ge60 += 1 if r["value"] >= 60 else 0
			ge80 += 1 if r["value"] >= 80 else 0
			capped += 1 if r["value"] >= r["cap"] else 0
		vals.sort()
		print("%4d %6.1f %5d %5d %5d %5d %6.0f%% %6.0f%% %6.0f%%" % [
			y, _mean(vals), _pct(vals, 0.1), _pct(vals, 0.5), _pct(vals, 0.9), vals[vals.size() - 1],
			100.0 * ge60 / rows.size(), 100.0 * ge80 / rows.size(), 100.0 * capped / rows.size()])

	print("")
	print("--- 按成长曲线分组的平均值 ---")
	var header := "%4s" % "年"
	for name in CURVE_NAMES:
		header += " %6s" % name
	print(header)
	for y in CHECK_YEARS:
		if not history.has(y) or y == 0:
			continue
		var sums := [0.0, 0.0, 0.0, 0.0]
		var counts := [0, 0, 0, 0]
		for r in history[y]:
			sums[r["curve"]] += r["value"]
			counts[r["curve"]] += 1
		var line := "%4d" % y
		for c in 4:
			line += " %6.1f" % (sums[c] / maxi(counts[c], 1))
		print(line)
	print("")


func _mean(vals: Array) -> float:
	var t := 0.0
	for v in vals:
		t += v
	return t / maxi(vals.size(), 1)
