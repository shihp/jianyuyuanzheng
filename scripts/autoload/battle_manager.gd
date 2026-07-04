## BattleManager - 战斗状态 / 伤害计算 / 胜负判定
## 对应 Java 的 BattleService / JS 的 combat engine
##
## 职责:
##   - 异步自动战斗循环（await Timer 实现回合间延迟）
##   - 伤害计算（含克制/暴击）
##   - 能量系统（每次攻击 +25，满 100 可释放绝学）
##   - 手动/自动绝学触发
##   - 速度倍率控制（1x/1.5x/2x）
##   - 胜负判定与奖励发放
extends Node

# ========== 信号 ==========

signal battle_started(formation: Array)
signal battle_ended(victory: bool, rewards: Dictionary)
signal hero_attacked(attacker_id: String, target_id: String, damage: int, is_crit: bool)
signal skill_triggered(hero_id: String, skill_name: String)
signal stage_progress(current_round: int, total_rounds: int)
signal skill_ready(hero_id: String)
signal round_started(round_num: int)

# ========== 枚举 ==========

enum BattleState {
	IDLE,
	IN_PROGRESS,
	VICTORY,
	DEFEAT,
}

# ========== 常量 ==========

const MAX_BATTLE_ROUNDS: int = 15  # 最多15回合，防死循环
const FACTION_ADVANTAGE_MULT: float = 1.25
const FACTION_DISADVANTAGE_MULT: float = 0.75
const BASE_TURN_DELAY: float = 1.0  # 1x 速度下每回合延迟（秒）
const ENERGY_PER_ATTACK: int = 25
const ENERGY_MAX: int = 100

# 势力克制: 正道→魔道→妖族→佛门→正道
const FACTION_COUNTERS: Dictionary = {
	"zhengdao": "modao",
	"modao": "yaozu",
	"yaozu": "fomen",
	"fomen": "zhengdao",
}

# ========== 状态 ==========

var battle_state: BattleState = BattleState.IDLE
var _player_formation: Array[Dictionary] = []  # [{id, hp, atk, speed, ...}]
var _enemy_formation: Array[Dictionary] = []
var _current_round: int = 0
var _speed_multiplier: float = 1.0
var _stage_id: int = 1
var _balance_cache: Dictionary = {}  # balance.json 缓存
var _faction_bonus_info: Dictionary = {"active": false, "faction": "", "atk_mult": 1.0, "hp_mult": 1.0}

# ========== 生命周期 ==========

func _ready() -> void:
	_load_balance_config()


## 加载 balance.json 配置到缓存
func _load_balance_config() -> void:
	_balance_cache = JSONLoader.load_dict("res://data/balance.json")
	print("[BattleManager] 加载 balance.json 配置: %d 段" % _balance_cache.size())

# ========== 公开接口 ==========

func start_battle(player_hero_ids: Array[String], stage_id: int) -> void:
	_stage_id = stage_id
	# 重置同势力加成状态
	_faction_bonus_info = {"active": false, "faction": "", "atk_mult": 1.0, "hp_mult": 1.0}
	_player_formation = _build_formation(player_hero_ids, true)
	_enemy_formation = _build_enemy_formation(stage_id)

	if _player_formation.is_empty():
		push_error("[BattleManager] 玩家阵容为空")
		battle_ended.emit(false, {})
		return

	battle_state = BattleState.IN_PROGRESS
	_current_round = 0
	battle_started.emit(player_hero_ids)

	# 开始异步战斗循环
	_run_battle()


## 设置速度倍率（1.0 / 1.5 / 2.0）
func set_speed_multiplier(mult: float) -> void:
	_speed_multiplier = clampf(mult, 0.5, 4.0)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func get_battle_state() -> BattleState:
	return battle_state


func get_player_formation() -> Array[Dictionary]:
	return _player_formation.duplicate(true)


func get_enemy_formation() -> Array[Dictionary]:
	return _enemy_formation.duplicate(true)


## 检查指定修士是否可以释放绝学
func can_use_skill(hero_id: String) -> bool:
	for unit in _player_formation:
		if unit.get("id", "") == hero_id:
			return unit.get("energy", 0) >= ENERGY_MAX and unit.get("hp", 0) > 0
	return false


## 手动触发绝学
func use_skill(hero_id: String) -> void:
	for unit in _player_formation:
		if unit.get("id", "") == hero_id and unit.get("energy", 0) >= ENERGY_MAX:
			_use_ultimate(unit)
			return

# ========== 战斗核心逻辑（异步）==========

func _run_battle() -> void:
	while battle_state == BattleState.IN_PROGRESS:
		_current_round += 1
		round_started.emit(_current_round)
		stage_progress.emit(_current_round, MAX_BATTLE_ROUNDS)

		if _current_round > MAX_BATTLE_ROUNDS:
			# 超时 → 失败
			_end_battle(false)
			return

		# 回合间延迟（受速度倍率影响）
		var delay: float = BASE_TURN_DELAY / _speed_multiplier
		await get_tree().create_timer(delay).timeout

		# 检查战斗是否在等待期间结束
		if battle_state != BattleState.IN_PROGRESS:
			return

		# 按速度排序，依次攻击
		var all_units: Array[Dictionary] = []
		for u in _player_formation:
			if u.hp > 0:
				all_units.append(u)
		for u in _enemy_formation:
			if u.hp > 0:
				all_units.append(u)

		all_units.sort_custom(func(a, b): return a.speed > b.speed)

		for unit in all_units:
			if unit.hp <= 0:
				continue
			if battle_state != BattleState.IN_PROGRESS:
				return

			_attack(unit)

			# 单位间小延迟
			await get_tree().create_timer(delay * 0.3).timeout

			# 每次攻击后检查胜负
			if _is_team_wiped(_player_formation):
				_end_battle(false)
				return
			if _is_team_wiped(_enemy_formation):
				_end_battle(true)
				return

		# 回合末：自动释放待发绝学
		_auto_release_ultimates()


func _attack(attacker: Dictionary) -> void:
	var is_player: bool = attacker.get("is_player", false)
	var targets: Array[Dictionary] = []
	var enemy_team: Array[Dictionary] = _enemy_formation if is_player else _player_formation

	for u in enemy_team:
		if u.hp > 0:
			targets.append(u)

	if targets.is_empty():
		return

	# 选择目标（最前排）
	var target: Dictionary = targets[0]

	# 计算伤害
	var damage: int = _calculate_damage(attacker, target)
	var is_crit: bool = damage > int(attacker.atk * 1.2)

	target.hp = max(0, target.hp - damage)
	hero_attacked.emit(attacker.id, target.id, damage, is_crit)

	# Bug 修复: 每次攻击获得能量
	attacker["energy"] = min(attacker.get("energy", 0) + ENERGY_PER_ATTACK, ENERGY_MAX)

	# 能量满时通知 UI（仅玩家方）
	if attacker.get("energy", 0) >= ENERGY_MAX and is_player:
		skill_ready.emit(attacker.id)


## 释放绝学（消耗 100 能量，造成技能倍率伤害）
func _use_ultimate(attacker: Dictionary) -> void:
	if attacker.get("energy", 0) < ENERGY_MAX:
		return

	attacker["energy"] = 0

	var is_player: bool = attacker.get("is_player", false)
	var enemy_team: Array[Dictionary] = _enemy_formation if is_player else _player_formation

	var targets: Array[Dictionary] = []
	for u in enemy_team:
		if u.hp > 0:
			targets.append(u)

	if targets.is_empty():
		return

	var skill_name: String = attacker.get("skill_name", "绝学")
	var skill_mult: float = float(attacker.get("skill_damage_mult", 1.5))
	skill_triggered.emit(attacker.id, skill_name)

	# 绝学对全体存活敌人造成伤害
	for target in targets:
		var base_dmg: int = _calculate_damage(attacker, target)
		var skill_dmg: int = int(base_dmg * skill_mult)
		target.hp = max(0, target.hp - skill_dmg)
		hero_attacked.emit(attacker.id, target.id, skill_dmg, true)


## 回合末自动释放所有待发绝学
func _auto_release_ultimates() -> void:
	# 玩家方
	for unit in _player_formation:
		if unit.hp > 0 and unit.get("energy", 0) >= ENERGY_MAX:
			_use_ultimate(unit)
			await get_tree().create_timer(0.2 / _speed_multiplier).timeout

	# 敌方
	for unit in _enemy_formation:
		if unit.hp > 0 and unit.get("energy", 0) >= ENERGY_MAX:
			_use_ultimate(unit)
			await get_tree().create_timer(0.2 / _speed_multiplier).timeout


func _calculate_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var base_dmg: float = float(attacker.atk)

	# 暴击判定
	var crit_rate: float = attacker.get("crit_rate", 0.05)
	var is_crit: bool = randf() < crit_rate
	if is_crit:
		base_dmg *= attacker.get("crit_dmg", 1.5)

	# 势力克制
	var atk_faction: String = attacker.get("faction", "")
	var def_faction: String = defender.get("faction", "")
	if _is_counter(atk_faction, def_faction):
		base_dmg *= FACTION_ADVANTAGE_MULT
	elif _is_counter(def_faction, atk_faction):
		base_dmg *= FACTION_DISADVANTAGE_MULT

	# 随机浮动 ±10%
	base_dmg *= randf_range(0.9, 1.1)

	return int(base_dmg)


func _is_counter(atk_faction: String, def_faction: String) -> bool:
	return FACTION_COUNTERS.get(atk_faction, "") == def_faction


func _is_team_wiped(team: Array[Dictionary]) -> bool:
	for unit in team:
		if unit.hp > 0:
			return false
	return true


func _end_battle(victory: bool) -> void:
	battle_state = BattleState.VICTORY if victory else BattleState.DEFEAT

	var rewards: Dictionary = {}
	if victory:
		rewards = _calculate_rewards()
		_apply_rewards(rewards)
		StageManager.clear_stage(_stage_id)
	else:
		StageManager.fail_stage(_stage_id)

	battle_ended.emit(victory, rewards)
	SaveManager.save_now()
	print("[BattleManager] 战斗结束 → %s" % ("胜利" if victory else "失败"))

# ========== 阵容构建 ==========

func _build_formation(hero_ids: Array[String], is_player: bool) -> Array[Dictionary]:
	var formation: Array[Dictionary] = []
	for hid in hero_ids:
		if not HeroManager.is_owned(hid):
			continue
		var stats: Dictionary = HeroManager.get_hero_stats(hid)
		var data: Dictionary = HeroManager.get_hero_data(hid)
		formation.append({
			"id": hid,
			"hp": stats.hp,
			"max_hp": stats.hp,
			"atk": stats.atk,
			"speed": stats.speed,
			"crit_rate": stats.crit_rate,
			"crit_dmg": stats.crit_dmg,
			"faction": HeroManager.get_hero_faction(hid),
			"energy": 0,
			"skill_name": data.get("skill_name", "绝学"),
			"skill_damage_mult": float(data.get("skill_damage_mult", 1.5)),
			"is_player": is_player,
		})
	# 玩家方阵容构建完成后应用同势力加成
	if is_player:
		_apply_faction_bonus(formation)
	return formation


## 应用同势力5人加成：检测阵容中同势力≥5的势力，对该势力所有单位乘算 atk/hp/max_hp
func _apply_faction_bonus(formation: Array[Dictionary]) -> void:
	if formation.is_empty():
		return

	# 从 balance.json 读取同势力加成配置
	var faction_counter: Dictionary = _balance_cache.get("faction_counter", {})
	var same_bonus: Dictionary = faction_counter.get("same_faction_bonus", {})
	var required_count: int = int(same_bonus.get("required_count", 5))
	var atk_mult: float = float(same_bonus.get("attack", 1.25))
	var hp_mult: float = float(same_bonus.get("hp", 1.25))

	# 统计阵容势力分布
	var faction_counts: Dictionary = {}
	for unit in formation:
		var faction: String = unit.get("faction", "")
		if faction.is_empty():
			continue
		faction_counts[faction] = faction_counts.get(faction, 0) + 1

	# 找到满足 required_count 的势力
	var bonus_faction: String = ""
	for faction in faction_counts:
		if int(faction_counts[faction]) >= required_count:
			bonus_faction = faction
			break

	if bonus_faction.is_empty():
		_faction_bonus_info = {"active": false, "faction": "", "atk_mult": 1.0, "hp_mult": 1.0}
		return

	# 对该势力所有单位乘算属性
	for unit in formation:
		if unit.get("faction", "") == bonus_faction:
			unit["atk"] = int(float(unit["atk"]) * atk_mult)
			unit["hp"] = int(float(unit["hp"]) * hp_mult)
			unit["max_hp"] = int(float(unit["max_hp"]) * hp_mult)

	_faction_bonus_info = {
		"active": true,
		"faction": bonus_faction,
		"atk_mult": atk_mult,
		"hp_mult": hp_mult,
	}
	print("[BattleManager] 同势力加成激活: %s 攻击×%.2f 生命×%.2f" % [bonus_faction, atk_mult, hp_mult])


## 获取同势力加成信息（供 UI 显示）
func get_faction_bonus_info() -> Dictionary:
	return _faction_bonus_info.duplicate()


func _build_enemy_formation(stage_id: int) -> Array[Dictionary]:
	# 使用 StageManager 的早期保护机制
	var result: Dictionary = StageManager.get_stage_enemy_stats(stage_id)
	var enemies: Array = result.get("enemies", [])
	var formation: Array[Dictionary] = []
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		formation.append({
			"id": "enemy_%d_%d" % [stage_id, i],
			"hp": int(e.get("hp", 500)),
			"max_hp": int(e.get("hp", 500)),
			"atk": int(e.get("atk", 50)),
			"speed": int(e.get("speed", 80)),
			"crit_rate": 0.05,
			"crit_dmg": 1.5,
			"faction": e.get("faction", ""),
			"energy": 0,
			"skill_name": e.get("skill_name", ""),
			"skill_damage_mult": 1.5,
			"is_player": false,
		})
	return formation

# ========== 奖励 ==========

func _calculate_rewards() -> Dictionary:
	# 从 stages.json 读取奖励
	var stage_rewards: Dictionary = StageManager.get_stage_rewards(_stage_id)
	var rewards: Dictionary = {
		"spirit_stones": int(stage_rewards.get("spirit_stones", 100 + _stage_id * 20)),
		"exp": int(stage_rewards.get("exp", 80 + _stage_id * 15)),
		"stage": _stage_id,
	}

	# Boss 关卡额外掉落碎片
	var stage_data: Dictionary = StageManager.get_stage_data(_stage_id)
	if bool(stage_data.get("is_boss", false)):
		# 随机势力碎片
		var drop_factions: Array[String] = ["zhengdao", "modao", "yaozu", "fomen"]
		var random_faction: String = drop_factions[randi() % drop_factions.size()]
		rewards["dust"] = 10 + _stage_id * 2
		rewards["fragment_faction"] = random_faction
		rewards["fragment_count"] = 5

	return rewards


func _apply_rewards(rewards: Dictionary) -> void:
	if rewards.has("spirit_stones"):
		EconomyManager.add_spirit_stones(rewards["spirit_stones"])
	if rewards.has("exp"):
		EconomyManager.add_exp(rewards["exp"])
	if rewards.has("dust"):
		EconomyManager.add_dust(rewards["dust"])
	# 碎片奖励 - 给对应势力的随机已拥有修士
	if rewards.has("fragment_faction") and rewards.has("fragment_count"):
		var faction: String = rewards["fragment_faction"]
		var count: int = rewards["fragment_count"]
		var owned: Array[String] = HeroManager.get_owned_heroes()
		var faction_heroes: Array[String] = []
		for hid in owned:
			if HeroManager.get_hero_faction(hid) == faction:
				faction_heroes.append(hid)
		if not faction_heroes.is_empty():
			var target_hero: String = faction_heroes[randi() % faction_heroes.size()]
			EconomyManager.add_fragments(target_hero, count)
			rewards["fragment_hero"] = target_hero
		else:
			# 无对应势力修士 → 转换为灵尘
			EconomyManager.add_dust(count * 3)
