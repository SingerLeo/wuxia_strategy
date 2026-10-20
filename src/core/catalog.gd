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
const BUILDINGS := {
	&"dojo": {
		"name": "练武场", "desc": "每级弟子修炼经验 +10%",
		"costs": [200, 400, 800, 1500, 3000], "upkeep": [3, 6, 10, 16, 24],
	},
	&"clinic": {
		"name": "药庐", "desc": "每级弟子休息时多恢复 5 点体力",
		"costs": [150, 300, 600, 1200, 2400], "upkeep": [2, 4, 7, 11, 16],
	},
	&"library": {
		"name": "藏经阁", "desc": "每级底蕴产出 +15%",
		"costs": [250, 500, 1000, 2000, 4000], "upkeep": [3, 6, 10, 16, 24],
	},
}

# --- 建筑效果（每级） ---
const DOJO_XP_PER_LEVEL := 0.10
const CLINIC_REST_PER_LEVEL := 5
const LIBRARY_LEGACY_PER_LEVEL := 0.15
