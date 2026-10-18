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
	assert_eq(names, ["功法", "内功", "轻功", "体魄", "聪慧", "统御"])


func test_gongfa_is_max_of_combat_skills_and_medicine_poison() -> void:
	var d := Disciple.new()
	d.skills[&"jian"] = 40
	d.skills[&"yishu"] = 70
	d.skills[&"dugong"] = 55
	d.skills[&"neigong"] = 99   # 内功、轻功不在功法里
	d.skills[&"qinggong"] = 99
	assert_almost_eq(_dim(Dimensions.compute(d), &"gongfa"), 70.0, 0.001)


func test_mixed_dimensions_use_half_and_half() -> void:
	var d := Disciple.new()
	d.skills[&"neigong"] = 40
	d.attributes[&"dingli"] = 20
	d.skills[&"qinggong"] = 60
	d.attributes[&"shenfa"] = 80
	d.attributes[&"lingdao"] = 30
	d.attributes[&"qinhe"] = 50
	var dims := Dimensions.compute(d)
	assert_almost_eq(_dim(dims, &"neigong"), 30.0, 0.001)
	assert_almost_eq(_dim(dims, &"qinggong"), 70.0, 0.001)
	assert_almost_eq(_dim(dims, &"tongyu"), 40.0, 0.001)


func test_single_attribute_dimensions() -> void:
	var d := Disciple.new()
	d.attributes[&"gengu"] = 77
	d.attributes[&"zhimou"] = 33
	var dims := Dimensions.compute(d)
	assert_almost_eq(_dim(dims, &"tipo"), 77.0, 0.001)
	assert_almost_eq(_dim(dims, &"conghui"), 33.0, 0.001)


func test_score_scale_is_1_to_20() -> void:
	assert_eq(UiText.score(1), 1)
	assert_eq(UiText.score(5), 1)
	assert_eq(UiText.score(6), 2)
	assert_eq(UiText.score(50), 10)
	assert_eq(UiText.score(100), 20)
	assert_eq(UiText.score(0), 1, "最低为 1")
	assert_eq(UiText.score(37.5), 8)
