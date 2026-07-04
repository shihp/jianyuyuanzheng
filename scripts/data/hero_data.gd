## HeroData - 修士数据模型定义
## 对应 Java 的 Hero POJO / JS 的 TypeScript interface
## 
## 用法:
##   var hero = HeroData.new()
##   hero.from_dict({"id": "hero_001", "name": "张三", ...})
##   print(hero.name, hero.atk)
class_name HeroData
extends RefCounted

# ========== 属性定义 ==========

var id: String = ""
var name: String = ""
var title: String = ""           # 称号
var faction: String = ""         # 势力: zhengdao/modao/yaozu/fomen
var rarity: int = 1              # 品质: 1=R, 2=SR, 3=SSR, 4=UR
var role: String = "dps"         # 定位: dps/tank/support
var skill_name: String = ""      # 绝学名称
var skill_desc: String = ""      # 绝学描述

# 基础属性
var base_atk: float = 100.0
var base_hp: float = 1000.0
var growth_atk: float = 10.0
var growth_hp: float = 80.0
var speed: int = 100
var crit_rate: float = 0.05
var crit_dmg: float = 1.5

# 绝学属性
var skill_damage_mult: float = 1.5
var skill_cooldown: int = 3      # 冷却回合

# ========== 序列化 ==========

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	title = data.get("title", "")
	faction = data.get("faction", "")
	rarity = int(data.get("rarity", 1))
	role = data.get("role", "dps")
	skill_name = data.get("skill_name", "")
	skill_desc = data.get("skill_desc", "")
	base_atk = float(data.get("base_atk", 100))
	base_hp = float(data.get("base_hp", 1000))
	growth_atk = float(data.get("growth_atk", 10))
	growth_hp = float(data.get("growth_hp", 80))
	speed = int(data.get("speed", 100))
	crit_rate = float(data.get("crit_rate", 0.05))
	crit_dmg = float(data.get("crit_dmg", 1.5))
	skill_damage_mult = float(data.get("skill_damage_mult", 1.5))
	skill_cooldown = int(data.get("skill_cooldown", 3))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"title": title,
		"faction": faction,
		"rarity": rarity,
		"role": role,
		"skill_name": skill_name,
		"skill_desc": skill_desc,
		"base_atk": base_atk,
		"base_hp": base_hp,
		"growth_atk": growth_atk,
		"growth_hp": growth_hp,
		"speed": speed,
		"crit_rate": crit_rate,
		"crit_dmg": crit_dmg,
		"skill_damage_mult": skill_damage_mult,
		"skill_cooldown": skill_cooldown,
	}


func get_rarity_name() -> String:
	match rarity:
		1: return "R"
		2: return "SR"
		3: return "SSR"
		4: return "UR"
		_: return "R"


func get_faction_name() -> String:
	match faction:
		"zhengdao": return "正道"
		"modao": return "魔道"
		"yaozu": return "妖族"
		"fomen": return "佛门"
		_: return "未知"
