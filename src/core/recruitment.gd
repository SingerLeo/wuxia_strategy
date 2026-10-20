class_name Recruitment
extends RefCounted
## 山门招生（B 类，P0）：每季一批候选人，玩家花银两招收。
## 质量随门派威望提升；要价随潜力上涨。纯逻辑，不依赖场景树。

## 每季候选人数
const CANDIDATES_PER_SEASON := 3
## 威望转化为质量加成：每 5 点威望 +1 属性/潜力期望，最多 +25
const PRESTIGE_PER_BONUS := 5
const MAX_QUALITY_BONUS := 25.0
## 要价 = PRICE_BASE + 潜力
const PRICE_BASE := 40


## 威望带来的质量加成（加在属性与潜力的生成均值上）
static func quality_bonus(prestige: int) -> float:
	return minf(float(prestige / PRESTIGE_PER_BONUS), MAX_QUALITY_BONUS)


## 候选人的要价（银两）
static func asking_price(d: Disciple) -> int:
	return PRICE_BASE + d.potential


## 生成一批候选人。start_id 为第一个候选人的 id，之后递增。
## 返回的候选人尚未加入门派；落选者（id 空缺）随季节刷新消失。
static func generate(rng: RandomNumberGenerator, prestige: int, start_id: int) -> Array[Disciple]:
	var boost := quality_bonus(prestige)
	var out: Array[Disciple] = []
	for i in CANDIDATES_PER_SEASON:
		var d := DiscipleFactory.create(rng, start_id + i, NameGen.person(rng), boost)
		out.append(d)
	return out
