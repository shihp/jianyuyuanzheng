## GachaData - 抽卡数据模型
class_name GachaData
extends RefCounted

var banner_id: String = ""
var banner_name: String = ""
var banner_type: String = "normal"  # normal / limited / faction
var cost_per_pull: int = 200
var cost_per_ten: int = 2000
var pity_threshold: int = 30
var rates: Dictionary = {
	"R": 0.75,
	"SR": 0.20,
	"SSR": 0.045,
	"UR": 0.005,
}
var featured_heroes: Array = []  # UP 修士列表
var available_heroes: Array = []  # 可抽取的修士池
var wishlist_config: Dictionary = {}  # 心愿单配置 {max_size, min_rarity, probability}

func from_dict(data: Dictionary) -> void:
	banner_id = data.get("banner_id", "")
	banner_name = data.get("banner_name", "")
	banner_type = data.get("banner_type", "normal")
	cost_per_pull = int(data.get("cost_per_pull", 200))
	cost_per_ten = int(data.get("cost_per_ten", 2000))
	pity_threshold = int(data.get("pity_threshold", 30))
	rates = data.get("rates", rates)
	featured_heroes = data.get("featured_heroes", [])
	available_heroes = data.get("available_heroes", [])
	wishlist_config = data.get("wishlist", {})


func get_rarity_for_roll(roll: float) -> int:
	# roll: 0.0 ~ 1.0 → 返回 rarity (1-4)
	if roll < rates.get("UR", 0.005):
		return 4
	elif roll < rates.get("UR", 0.005) + rates.get("SSR", 0.045):
		return 3
	elif roll < rates.get("UR", 0.005) + rates.get("SSR", 0.045) + rates.get("SR", 0.20):
		return 2
	else:
		return 1
