## BattleSystem - 战斗系统辅助逻辑
## 与 BattleManager 配合，提供战斗计算工具
##
## 注意: BattleManager 是 autoload 单例，负责战斗状态管理
##       BattleSystem 是可实例化的逻辑类，用于独立计算
class_name BattleSystem
extends RefCounted

# 势力克制关系: 正道→魔道→妖族→佛门→正道
const FACTION_COUNTERS: Dictionary = {
	"zhengdao": "modao",
	"modao": "yaozu",
	"yaozu": "fomen",
	"fomen": "zhengdao",
}

const ADVANTAGE_MULT: float = 1.25
const DISADVANTAGE_MULT: float = 0.75


## 获取势力克制关系
## 返回: 1 = 克制, -1 = 被克, 0 = 无关系
static func get_faction_advantage(atk_faction: String, def_faction: String) -> int:
	if FACTION_COUNTERS.get(atk_faction, "") == def_faction:
		return 1
	if FACTION_COUNTERS.get(def_faction, "") == atk_faction:
		return -1
	return 0


## 获取克制伤害倍率
static func get_damage_multiplier(atk_faction: String, def_faction: String) -> float:
	var adv: int = get_faction_advantage(atk_faction, def_faction)
	match adv:
		1: return ADVANTAGE_MULT
		-1: return DISADVANTAGE_MULT
		_: return 1.0


## 计算阵容总战力
static func calculate_team_power(formation: Array[Dictionary]) -> int:
	var total: int = 0
	for unit in formation:
		total += int(unit.get("atk", 0) * 2 + unit.get("hp", 0) * 0.5 + unit.get("speed", 0) * 3)
	return total


## 计算同势力加成
## 5个同势力 → 攻击/生命 +25%
static func get_same_faction_bonus(formation: Array[Dictionary]) -> Dictionary:
	var faction_counts: Dictionary = {}
	for unit in formation:
		var f: String = unit.get("faction", "")
		faction_counts[f] = faction_counts.get(f, 0) + 1

	var best_bonus: Dictionary = {"attack": 1.0, "hp": 1.0, "faction": ""}
	for faction in faction_counts:
		if faction_counts[faction] >= 5:
			best_bonus = {"attack": 1.25, "hp": 1.25, "faction": faction}
			break
		elif faction_counts[faction] >= 3:
			best_bonus = {"attack": 1.10, "hp": 1.10, "faction": faction}

	return best_bonus


## 模拟单次攻击伤害
static func simulate_damage(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var base_dmg: float = float(attacker.get("atk", 100))

	# 暴击
	var is_crit: bool = randf() < float(attacker.get("crit_rate", 0.05))
	if is_crit:
		base_dmg *= float(attacker.get("crit_dmg", 1.5))

	# 势力克制
	base_dmg *= get_damage_multiplier(
		attacker.get("faction", ""),
		defender.get("faction", "")
	)

	# 随机浮动 ±10%
	base_dmg *= randf_range(0.9, 1.1)

	return {
		"damage": int(base_dmg),
		"is_crit": is_crit,
		"would_kill": int(base_dmg) >= int(defender.get("hp", 0)),
	}
