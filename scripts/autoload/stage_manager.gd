## StageManager - 关卡进度 / 难度计算 / 卡关检测
## 对应 Java 的 StageService / JS 的 level progression manager
##
## 职责:
##   - 关卡数据加载
##   - 关卡推进与解锁
##   - 难度计算（含早期保护机制）
##   - 卡关检测与提示
extends Node

# ========== 信号 ==========

signal stage_cleared(stage_id: int, stars: int)
signal stage_unlocked(stage_id: int)
signal stuck_detected(stage_id: int, suggested_actions: Array)

# ========== 常量 ==========

# 早期保护：1-20关敌人削弱15%
const EARLY_GAME_STAGES: int = 20
const EARLY_GAME_DEBUFF: float = 0.15

# ========== 状态 ==========

var _stage_db: Dictionary = {}          # {stage_id: Dictionary}
var _current_stage: int = 1
var _max_stage: int = 1
var _stage_stars: Dictionary = {}       # {stage_id: star_count}
var _consecutive_losses: int = 0       # 连败计数（卡关检测）

# ========== 生命周期 ==========

func _ready() -> void:
	_load_stage_database()
	_load_from_save()
	SaveManager.load_completed.connect(_on_load_completed)

# ========== 数据加载 ==========

func _load_stage_database() -> void:
	var data: Array = JSONLoader.load_array("res://data/stages.json")
	for stage in data:
		var sid: int = int(stage.get("id", 0))
		_stage_db[sid] = stage
	print("[StageManager] 加载 %d 个关卡数据" % _stage_db.size())


func _load_from_save() -> void:
	var save: Dictionary = SaveManager.get_data("stage")
	_current_stage = save.get("current_stage", 1)
	_max_stage = save.get("max_stage", 1)
	_stage_stars = save.get("stars", {})

# ========== 公开接口 ==========

func get_current_stage() -> int:
	return _current_stage


func get_max_stage() -> int:
	return _max_stage


func get_stage_data(stage_id: int) -> Dictionary:
	return _stage_db.get(stage_id, {})


func is_stage_unlocked(stage_id: int) -> bool:
	return stage_id <= _max_stage


func get_stage_stars(stage_id: int) -> int:
	return _stage_stars.get(stage_id, 0)


func get_total_stars() -> int:
	var total: int = 0
	for stars in _stage_stars.values():
		total += stars
	return total


func get_stage_enemy_stats(stage_id: int) -> Dictionary:
	var data: Dictionary = get_stage_data(stage_id)
	var enemies: Array = data.get("enemies", [])

	# 早期保护
	if stage_id <= EARLY_GAME_STAGES:
		var debuffed_enemies: Array = []
		for e in enemies:
			var debuffed: Dictionary = e.duplicate()
			debuffed["hp"] = int(e.get("hp", 500) * (1.0 - EARLY_GAME_DEBUFF))
			debuffed["atk"] = int(e.get("atk", 50) * (1.0 - EARLY_GAME_DEBUFF))
			debuffed_enemies.append(debuffed)
		return {"enemies": debuffed_enemies, "debuffed": true}

	return {"enemies": enemies, "debuffed": false}


## 获取关卡奖励（从 stages.json 读取）
func get_stage_rewards(stage_id: int) -> Dictionary:
	var data: Dictionary = get_stage_data(stage_id)
	return data.get("rewards", {})

# ========== 境界与渡劫（Phase 2 新增）==========

## 获取境界名称
func get_realm_name(stage_id: int) -> String:
	var data: Dictionary = get_stage_data(stage_id)
	return data.get("realm_name", "")


## 是否为渡劫瓶颈关（兼容旧数据：回退到 is_boss）
func is_tribulation_stage(stage_id: int) -> bool:
	var data: Dictionary = get_stage_data(stage_id)
	if data.has("is_tribulation"):
		return bool(data.get("is_tribulation", false))
	# 兼容旧数据：回退到 is_boss
	return bool(data.get("is_boss", false))


## 获取渡劫关信息（供 UI 提示）
func get_tribulation_info(stage_id: int) -> Dictionary:
	var is_trib: bool = is_tribulation_stage(stage_id)
	var data: Dictionary = get_stage_data(stage_id)
	return {
		"is_tribulation": is_trib,
		"name": data.get("name", ""),
		"description": data.get("description", ""),
	}


## 获取当前境界进度
## 返回 {"realm_name": String, "current": int, "total": int}
## current = 当前关卡在当前境界内的序号, total = stages_per_realm
func get_realm_progress() -> Dictionary:
	var current: int = _current_stage
	var realm_name: String = get_realm_name(current)

	# 从 balance.json 读取每境界关数
	var balance: Dictionary = JSONLoader.load_dict("res://data/balance.json")
	var realms_cfg: Dictionary = balance.get("realms", {})
	var total: int = int(realms_cfg.get("stages_per_realm", 40))

	# 计算当前关卡在当前境界内的序号
	var stage_in_realm: int = current
	if not realm_name.is_empty():
		# 找到该境界第一关的 ID
		var first_stage: int = current
		for sid in range(1, current + 1):
			if get_realm_name(sid) == realm_name:
				first_stage = sid
				break
		stage_in_realm = current - first_stage + 1

	return {
		"realm_name": realm_name,
		"current": stage_in_realm,
		"total": total,
	}

# ========== 关卡推进 ==========

## 通关关卡：解锁下一关 + 记录星级
func clear_stage(stage_id: int, stars: int = 1) -> void:
	stage_cleared.emit(stage_id, stars)

	# 更新星级
	var prev_stars: int = _stage_stars.get(stage_id, 0)
	_stage_stars[stage_id] = max(prev_stars, stars)

	# 推进关卡
	if stage_id == _current_stage:
		_current_stage += 1
		_max_stage = max(_max_stage, _current_stage)
		stage_unlocked.emit(_current_stage)

	_consecutive_losses = 0  # 重置连败
	_persist()
	SaveManager.save_now()


## 完成关卡（clear_stage 的语义化别名）
func complete_stage(stage_id: int, stars: int = 1) -> void:
	clear_stage(stage_id, stars)


func fail_stage(stage_id: int) -> void:
	_consecutive_losses += 1

	# 连败3次 → 卡关检测
	if _consecutive_losses >= 3:
		var suggestions: Array = _get_stuck_suggestions()
		stuck_detected.emit(stage_id, suggestions)
		_consecutive_losses = 0  # 重置，避免频繁提示


func _get_stuck_suggestions() -> Array:
	var suggestions: Array = []

	# 检查是否有修士可以升级
	var heroes: Array[String] = HeroManager.get_owned_heroes()
	if not heroes.is_empty():
		suggestions.append("升级修士提升战力")

	# 检查是否有修士可以升品质
	for hid in heroes:
		if HeroManager.get_hero_quality(hid) < 5:
			if EconomyManager.get_fragments(hid) >= 20:
				suggestions.append("升品质「%s」" % HeroManager.get_hero_data(hid).get("name", ""))
				break

	# 检查阵容是否不满
	if HeroManager.get_formation().size() < 5:
		suggestions.append("补满5人阵容")

	# 检查是否可以抽卡
	if EconomyManager.get_amount(&"jade") >= 200:
		suggestions.append("寻仙获取更强修士")

	return suggestions

# ========== 内部方法 ==========

func _on_load_completed(save_data: Dictionary) -> void:
	var save: Dictionary = save_data.get("stage", {})
	_current_stage = save.get("current_stage", 1)
	_max_stage = save.get("max_stage", 1)
	_stage_stars = save.get("stars", {})


func _persist() -> void:
	SaveManager.set_data("stage", {
		"current_stage": _current_stage,
		"max_stage": _max_stage,
		"stars": _stage_stars.duplicate(),
	})
	SaveManager.mark_dirty()
