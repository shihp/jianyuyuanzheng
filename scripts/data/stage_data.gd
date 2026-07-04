## StageData - 关卡数据模型
class_name StageData
extends RefCounted

var id: int = 0
var name: String = ""
var chapter: int = 1
var realm_name: String = ""
var is_tribulation: bool = false
var description: String = ""
var recommended_power: int = 0
var enemies: Array = []          # [{faction, hp, atk, speed, skill_name}]
var rewards: Dictionary = {}     # {spirit_stones, exp, items}
var is_boss: bool = false

func from_dict(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	name = data.get("name", "")
	chapter = int(data.get("chapter", 1))
	realm_name = data.get("realm_name", "")
	is_tribulation = bool(data.get("is_tribulation", data.get("is_boss", false)))
	description = data.get("description", "")
	recommended_power = int(data.get("recommended_power", 0))
	enemies = data.get("enemies", [])
	rewards = data.get("rewards", {})
	is_boss = bool(data.get("is_boss", false))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"chapter": chapter,
		"realm_name": realm_name,
		"is_tribulation": is_tribulation,
		"description": description,
		"recommended_power": recommended_power,
		"enemies": enemies,
		"rewards": rewards,
		"is_boss": is_boss,
	}
