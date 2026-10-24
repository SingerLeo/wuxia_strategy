class_name Catalog
extends RefCounted
## 产业与建筑的目录，以及与资源相关的常量。全部是占位数值，调平衡时只改这里。
## 以后内容多了可以整体移到 data/ 下的 JSON。

# --- 持续支出 ---
const DISCIPLE_UPKEEP := 2           ## 养育弟子：每人每旬

# --- 底蕴的来源 ---
const LEGACY_PER_XP := 0.1           ## 弟子本旬获得的技能经验 → 底蕴
const LEGACY_PER_PRESTIGE := 1.0     ## 获得的威望 → 底蕴

# --- 开局 ---
const START_SILVER := 1000
const START_ESTATES := {&"farm": 2}

# --- 产业：购置后每旬产生收入 ---
const ESTATES := {
	&"farm": {"name": "田产", "price": 300, "income": 9, "max": 6, "desc": "山下的良田，每旬收租。"},
	&"shop": {"name": "商铺", "price": 600, "income": 20, "max": 4, "desc": "镇上的铺面，收益更高。"},
}

# --- 建筑：花银两升级，每旬需要维护费 ---
# costs[i]：升到第 i+1 级的花费；upkeep[i]：处于第 i+1 级时每旬的维护费
# size：占地 [宽, 高]（格），可旋转；color：山门地图上的颜色
const BUILDINGS := {
	&"dojo": {
		"name": "练武场", "desc": "每级弟子修炼经验 +10%", "size": [3, 3], "color": "#7a4a3a",
		"costs": [200, 400, 800, 1500, 3000], "upkeep": [3, 6, 10, 16, 24],
	},
	&"clinic": {
		"name": "药庐", "desc": "每级弟子休息时多恢复 5 点体力", "size": [2, 2], "color": "#3f6b50",
		"costs": [150, 300, 600, 1200, 2400], "upkeep": [2, 4, 7, 11, 16],
	},
	&"library": {
		"name": "藏经阁", "desc": "每级底蕴产出 +15%", "size": [2, 3], "color": "#4a5a7a",
		"costs": [250, 500, 1000, 2000, 4000], "upkeep": [3, 6, 10, 16, 24],
	},
	&"kitchen": {
		"name": "伙房", "desc": "每级养育弟子的费用 -8%", "size": [2, 2], "color": "#8a6a3a",
		"costs": [180, 360, 720, 1400, 2800], "upkeep": [2, 4, 6, 9, 13],
	},
}

# --- 建筑效果（每级） ---
const DOJO_XP_PER_LEVEL := 0.10
const CLINIC_REST_PER_LEVEL := 5
const LIBRARY_LEGACY_PER_LEVEL := 0.15
const KITCHEN_UPKEEP_CUT_PER_LEVEL := 0.08

# --- 拆除 ---
const DEMOLISH_REFUND := 0.5         ## 拆除时退还已投入总花费的比例

# --- 山门地图 ---
# 每行一排格子：. 空地  # 山石（不可建）  ~ 池塘（不可建）
const MAP := [
	"............",
	".##.....~~..",
	".#......~~..",
	"............",
	"............",
	"......#.....",
	"............",
	".....##.....",
]

# --- 位置带来的加成（邻接规则）---
# target 是被影响的建筑，other 是它的"邻居"；两座都已摆放且满足条件时，target 的效果乘以 mult。
#   kind = "adjacent"：两座建筑共用一条边（紧挨着）
#   kind = "near"：两座建筑之间的最短曼哈顿距离 <= dist（相隔不到 dist-1 格）
const SYNERGIES := [
	{"target": &"clinic", "other": &"dojo", "kind": "adjacent", "mult": 1.5,
		"note": "药庐紧挨练武场，随到随治"},
	{"target": &"kitchen", "other": &"clinic", "kind": "adjacent", "mult": 1.25,
		"note": "伙房紧挨药庐，药膳进补"},
	{"target": &"library", "other": &"dojo", "kind": "near", "dist": 2, "mult": 0.7,
		"note": "藏经阁离练武场太近，喧闹难静心"},
]
