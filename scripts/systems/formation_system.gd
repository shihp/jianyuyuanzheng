## FormationSystem - 阵容系统
## 管理阵容排列、站位、同势力加成计算
class_name FormationSystem
extends RefCounted

const MAX_SIZE: int = 5

# 站位: 前排(0,1,2) 后排(3,4)
# 前排承受更多伤害，后排输出更安全
const FRONT_ROW: Array[int] = [0, 1, 2]
const BACK_ROW: Array[int] = [3, 4]


## 验证阵容合法性
static func validate(hero_ids: Array[String]) -> Dictionary:
	if hero_ids.size() > MAX_SIZE:
		return {"valid": false, "reason": "阵容超过 %d 人上限" % MAX_SIZE}

	var seen: Dictionary = {}
	for hid in hero_ids:
		if seen.has(hid):
			return {"valid": false, "reason": "阵容中有重复修士"}
		seen[hid] = true

	return {"valid": true, "reason": ""}


## 获取阵容势力分布
static func get_faction_distribution(hero_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for hid in hero_ids:
		var faction: String = HeroManager.get_hero_faction(hid)
		counts[faction] = counts.get(faction, 0) + 1
	return counts


## 获取最优同势力加成（从 balance.json 读取配置，仅5人加成）
static func get_best_faction_bonus(hero_ids: Array[String]) -> Dictionary:
	var dist: Dictionary = get_faction_distribution(hero_ids)

	# 从 balance.json 读取同势力加成配置
	var balance: Dictionary = JSONLoader.load_dict("res://data/balance.json")
	var faction_counter: Dictionary = balance.get("faction_counter", {})
	var same_bonus: Dictionary = faction_counter.get("same_faction_bonus", {})
	var required_count: int = int(same_bonus.get("required_count", 5))
	var atk_mult: float = float(same_bonus.get("attack", 1.25))
	var hp_mult: float = float(same_bonus.get("hp", 1.25))

	var best: Dictionary = {"attack": 1.0, "hp": 1.0, "faction": "", "count": 0}
	for faction in dist:
		var count: int = dist[faction]
		if count >= required_count and best.count < count:
			best = {"attack": atk_mult, "hp": hp_mult, "faction": faction, "count": count}

	return best


## 计算阵容总战力
static func calculate_power(hero_ids: Array[String]) -> int:
	var total: int = 0
	for hid in hero_ids:
		var stats: Dictionary = HeroManager.get_hero_stats(hid)
		total += int(stats.atk * 2 + stats.hp * 0.5 + stats.speed * 3)

	# 同势力加成
	var bonus: Dictionary = get_best_faction_bonus(hero_ids)
	total = int(total * bonus.attack)

	return total


## 建议前排坦克后排输出
static func suggest_formation(hero_ids: Array[String]) -> Array[String]:
	var heroes: Array[Dictionary] = []
	for hid in hero_ids:
		var data: Dictionary = HeroManager.get_hero_data(hid)
		heroes.append({"id": hid, "role": data.get("role", "dps")})

	# 坦克在前，输出在后
	heroes.sort_custom(func(a, b):
		var role_order: Dictionary = {"tank": 0, "support": 1, "dps": 2}
		return role_order.get(a.role, 2) < role_order.get(b.role, 2)
	)

	var result: Array[String] = []
	for h in heroes:
		result.append(h.id)
	return result
