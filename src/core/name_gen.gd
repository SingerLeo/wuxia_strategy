class_name NameGen
extends RefCounted
## 随机人名。仅用于占位，后续可换成数据表。

const SURNAMES: Array[String] = [
	"李", "王", "张", "刘", "陈", "杨", "赵", "周", "吴", "徐",
	"孙", "马", "朱", "胡", "郭", "林", "何", "高", "罗", "郑",
	"令狐", "慕容", "上官", "欧阳", "独孤",
]
const GIVEN: Array[String] = [
	"云", "风", "霜", "雪", "剑", "尘", "远", "宁", "青", "墨",
	"明", "月", "山", "川", "松", "鹤", "竹", "清", "阳", "秋",
	"逸", "飞", "岚", "恒", "安", "然", "锋", "岳",
]


static func person(rng: RandomNumberGenerator) -> String:
	var name: String = SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]
	for i in rng.randi_range(1, 2):
		name += GIVEN[rng.randi_range(0, GIVEN.size() - 1)]
	return name
