extends GutTest


func _dim(dims: Array[Dictionary], id: StringName) -> float:
	for x in dims:
		if x["id"] == id:
			return x["value"]
	return -1.0


func test_six_dimensions_in_order() -> void:
	var dims := Dimensions.compute(Disciple.new())
	assert_eq(dims.size(), 6)
	var names: Array = []
	for x in dims:
		names.append(x["name"])
	assert_eq(names, ["武功", "内功", "轻灵", "体魄", "才智", "人望"])


func test_wugong_is_max_of_combat_skills_only() -> void:
	var d := Disciple.new()
	d.stats[&"jian"] = 40
	d.stats[&"anqi"] = 62
	d.stats[&"yishu"] = 90    # 医术、毒术不算武功
	d.stats[&"dushu"] = 90
	assert_almost_eq(_dim(Dimensions.compute(d), &"wugong"), 62.0, 0.001)


func test_mixed_dimensions_use_weights() -> void:
	var d := Disciple.new()
	d.stats[&"neigong"] = 40
	d.stats[&"dingli"] = 20
	d.stats[&"qinggong"] = 60
	d.stats[&"shenfa"] = 80
	d.stats[&"fanying"] = 30
	d.stats[&"gengu"] = 70
	d.stats[&"yinggong"] = 50
	d.stats[&"ruangong"] = 40
	d.stats[&"naili"] = 20
	d.stats[&"wuxing"] = 90
	d.stats[&"zhimou"] = 40
	d.stats[&"qinmian"] = 10
	d.stats[&"tongshuai"] = 30
	d.stats[&"meili"] = 60
	d.stats[&"letian"] = 70
	var dims := Dimensions.compute(d)
	assert_almost_eq(_dim(dims, &"neigong"), 32.0, 0.001)   # 40×0.6 + 20×0.4
	assert_almost_eq(_dim(dims, &"qingling"), 62.0, 0.001)  # 24 + 32 + 6
	assert_almost_eq(_dim(dims, &"tipo"), 48.0, 0.001)      # 21 + 15 + 8 + 4
	assert_almost_eq(_dim(dims, &"caizhi"), 54.0, 0.001)    # 36 + 16 + 2
	assert_almost_eq(_dim(dims, &"renwang"), 51.0, 0.001)   # 12 + 18 + 21


func test_mix_weights_sum_to_one() -> void:
	for def in Dimensions.DEFS:
		if def.has("mix"):
			var total := 0.0
			for k in def["mix"]:
				total += def["mix"][k]
			assert_almost_eq(total, 1.0, 0.001, "%s 的权重之和应为 1" % def["name"])


func test_score_scale_is_1_to_20() -> void:
	assert_eq(UiText.score(1), 1)
	assert_eq(UiText.score(5), 1)
	assert_eq(UiText.score(6), 2)
	assert_eq(UiText.score(50), 10)
	assert_eq(UiText.score(100), 20)
	assert_eq(UiText.score(0), 1, "最低为 1")
	assert_eq(UiText.score(37.5), 8)
