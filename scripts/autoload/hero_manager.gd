## HeroManager - 修士数据 / 阵容 / 升级 / 突破
## 对应 Java 的 HeroService / JS 的 character roster manager
##
## 职责:
##   - 修士数据加载与缓存
##   - 拥有/升级/突破/升品质
##   - 阵容管理（最多5人）
extends Node

# ========== 信号 ==========

signal hero_acquired(hero_id: String)
signal hero_leveled_up(hero_id: String, new_level: int)
signal hero_quality_up(hero_id: String, new_quality: int)
signal formation_changed(formation: Array)

# ========== 常量 ==========

const MAX_FORMATION_SIZE: int = 5
const QUALITY_NAMES: Array[String] = ["凡", "灵", "玄", "地", "天", "仙"]
const QUALITY_MULTIPLIERS: Array[float] = [1.0, 1.5, 2.2, 3.5, 5.0, 8.0]
const DEFAULT_EXP_COST_RATIO: float = 0.8  # 修为消耗 = 灵石消耗 × 0.8

# ========== 状态 ==========

var _hero_db: Dictionary = {}           # 原始数据 {hero_id: Dictionary}
var _owned_heroes: Array[String] = []   # 已拥有修士ID
var _hero_levels: Dictionary = {}       # {hero_id: int}
var _hero_qualities: Dictionary = {}    # {hero_id: int} (0-5)
var _formation: Array[String] = []      # 当前阵容
var _balance_cache: Dictionary = {}     # balance.json 缓存

# ========== 生命周期 ==========

func _ready() -> void:
	_load_balance()
	_load_hero_database()
	_load_from_save()
	SaveManager.load_completed.connect(_on_load_completed)

# ========== 数据加载 ==========

func _load_balance() -> void:
	_balance_cache = JSONLoader.load_dict("res://data/balance.json")


func _load_hero_database() -> void:
	var data: Array = JSONLoader.load_array("res://data/heroes.json")
	for hero in data:
		if hero.has("id"):
			_hero_db[hero["id"]] = hero
	print("[HeroManager] 加载 %d 个修士数据" % _hero_db.size())


func _load_from_save() -> void:
	var save: Dictionary = SaveManager.get_data("heroes")
	var raw_owned: Array = save.get("owned", [])
	_owned_heroes.clear()
	_owned_heroes.assign(raw_owned)
	_hero_levels = save.get("levels", {})
	_hero_qualities = save.get("qualities", {})
	var raw_formation: Array = save.get("formation", [])
	_formation.clear()
	_formation.assign(raw_formation)

	# 新玩家给一个初始修士
	if _owned_heroes.is_empty():
		_grant_starter_hero()


func _grant_starter_hero() -> void:
	# 正道初始修士
	add_hero("hero_zhengdao_001")

# ========== 公开接口 - 拥有 ==========

func add_hero(hero_id: String) -> bool:
	if not _hero_db.has(hero_id):
		push_warning("[HeroManager] 未知修士: %s" % hero_id)
		return false
	if hero_id in _owned_heroes:
		# 已拥有 → 返回 false（碎片转换由 GachaManager 处理）
		return false
	_owned_heroes.append(hero_id)
	_hero_levels[hero_id] = 1
	_hero_qualities[hero_id] = 0
	hero_acquired.emit(hero_id)
	_persist()
	return true


func is_owned(hero_id: String) -> bool:
	return hero_id in _owned_heroes


func get_owned_heroes() -> Array[String]:
	return _owned_heroes.duplicate()

# ========== 公开接口 - 属性 ==========

func get_hero_data(hero_id: String) -> Dictionary:
	return _hero_db.get(hero_id, {})


func get_hero_level(hero_id: String) -> int:
	return _hero_levels.get(hero_id, 1)


func get_hero_quality(hero_id: String) -> int:
	return _hero_qualities.get(hero_id, 0)


func get_hero_quality_name(hero_id: String) -> String:
	var q: int = get_hero_quality(hero_id)
	if q >= 0 and q < QUALITY_NAMES.size():
		return QUALITY_NAMES[q]
	return "凡"


func get_hero_faction(hero_id: String) -> String:
	var data: Dictionary = get_hero_data(hero_id)
	return data.get("faction", "")


func get_hero_rarity(hero_id: String) -> int:
	var data: Dictionary = get_hero_data(hero_id)
	return data.get("rarity", 1)  # 1=R, 2=SR, 3=SSR, 4=UR


func get_hero_stats(hero_id: String) -> Dictionary:
	var data: Dictionary = get_hero_data(hero_id)
	var level: int = get_hero_level(hero_id)
	var quality: int = get_hero_quality(hero_id)

	# 属性 = (基础 + 等级 × 成长) × 品质系数
	var base_atk: float = float(data.get("base_atk", 100))
	var base_hp: float = float(data.get("base_hp", 1000))
	var growth_atk: float = float(data.get("growth_atk", 10))
	var growth_hp: float = float(data.get("growth_hp", 80))
	var q_mult: float = QUALITY_MULTIPLIERS[quality] if quality < QUALITY_MULTIPLIERS.size() else 1.0

	return {
		"atk": int((base_atk + level * growth_atk) * q_mult),
		"hp": int((base_hp + level * growth_hp) * q_mult),
		"speed": int(data.get("speed", 100)),
		"crit_rate": float(data.get("crit_rate", 0.05)),
		"crit_dmg": float(data.get("crit_dmg", 1.5)),
	}

# ========== 公开接口 - 升级 ==========

## 获取最大等级
func get_max_level() -> int:
	var hero_level_cfg: Dictionary = _balance_cache.get("hero_level", {})
	return int(hero_level_cfg.get("max_level", 240))


## 获取升级成本（灵石 + 修为）
func get_level_up_cost(hero_id: String) -> Dictionary:
	var level: int = get_hero_level(hero_id)
	var hero_level_cfg: Dictionary = _balance_cache.get("hero_level", {})
	var cost_base: float = float(hero_level_cfg.get("cost_base", 100))
	var cost_exp: float = float(hero_level_cfg.get("cost_exponent", 1.5))
	var exp_ratio: float = float(hero_level_cfg.get("exp_cost_ratio", DEFAULT_EXP_COST_RATIO))

	var spirit_stone_cost: int = int(cost_base * pow(float(level), cost_exp))
	var exp_cost: int = int(float(spirit_stone_cost) * exp_ratio)

	return {
		"spirit_stones": spirit_stone_cost,
		"exp": exp_cost,
	}


## 是否可以升级
func can_level_up(hero_id: String) -> bool:
	if not is_owned(hero_id):
		return false
	if get_hero_level(hero_id) >= get_max_level():
		return false
	var cost: Dictionary = get_level_up_cost(hero_id)
	if not EconomyManager.can_afford(&"spirit_stones", cost["spirit_stones"]):
		return false
	if not EconomyManager.can_afford(&"exp", cost["exp"]):
		return false
	return true


## 升级：消耗灵石 + 修为
func level_up(hero_id: String) -> bool:
	if not is_owned(hero_id):
		return false

	var level: int = get_hero_level(hero_id)
	if level >= get_max_level():
		push_warning("[HeroManager] 已达最大等级 %d" % get_max_level())
		return false

	var cost: Dictionary = get_level_up_cost(hero_id)
	var stone_cost: int = cost["spirit_stones"]
	var exp_cost: int = cost["exp"]

	# 检查资源是否足够
	if not EconomyManager.can_afford(&"spirit_stones", stone_cost):
		return false
	if not EconomyManager.can_afford(&"exp", exp_cost):
		return false

	# 消耗资源
	EconomyManager.spend_spirit_stones(stone_cost)
	EconomyManager.spend(&"exp", exp_cost)

	# 升级
	_hero_levels[hero_id] = level + 1
	hero_leveled_up.emit(hero_id, _hero_levels[hero_id])
	_persist()
	SaveManager.save_now()
	return true

# ========== 公开接口 - 升品质 ==========

## 获取升品质成本（灵尘 + 碎片）
func get_quality_up_cost(hero_id: String) -> Dictionary:
	var quality: int = get_hero_quality(hero_id)
	var quality_cfg: Dictionary = _balance_cache.get("quality", {})
	var dust_costs: Array = quality_cfg.get("dust_cost_per_tier", [0, 50, 100, 200, 400, 800])
	var fragment_costs: Array = quality_cfg.get("fragment_cost_per_tier", [0, 20, 40, 80, 160, 320])

	var tier_index: int = quality + 1
	var dust_cost: int = int(dust_costs[tier_index]) if tier_index < dust_costs.size() else 0
	var fragment_cost: int = int(fragment_costs[tier_index]) if tier_index < fragment_costs.size() else 0

	return {
		"dust": dust_cost,
		"fragments": fragment_cost,
	}


## 是否可以升品质
func can_quality_up(hero_id: String) -> bool:
	if not is_owned(hero_id):
		return false
	var quality: int = get_hero_quality(hero_id)
	if quality >= QUALITY_NAMES.size() - 1:
		return false  # 已满品质
	var cost: Dictionary = get_quality_up_cost(hero_id)
	if not EconomyManager.can_afford(&"dust", cost["dust"]):
		return false
	if EconomyManager.get_fragments(hero_id) < cost["fragments"]:
		return false
	return true


## 升品质：消耗灵尘 + 碎片（从 balance.json 读取成本）
func quality_up(hero_id: String) -> bool:
	if not is_owned(hero_id):
		return false

	var quality: int = get_hero_quality(hero_id)
	if quality >= QUALITY_NAMES.size() - 1:
		push_warning("[HeroManager] 已达最高品质")
		return false

	var cost: Dictionary = get_quality_up_cost(hero_id)
	var dust_cost: int = cost["dust"]
	var fragment_cost: int = cost["fragments"]

	# 检查资源
	if EconomyManager.get_fragments(hero_id) < fragment_cost:
		return false
	if not EconomyManager.can_afford(&"dust", dust_cost):
		return false

	# 消耗资源
	EconomyManager.spend(&"dust", dust_cost)
	EconomyManager.spend_fragments(hero_id, fragment_cost)

	# 升品质
	_hero_qualities[hero_id] = quality + 1
	hero_quality_up.emit(hero_id, _hero_qualities[hero_id])
	_persist()
	SaveManager.save_now()
	return true

# ========== 公开接口 - 阵容 ==========

func get_formation() -> Array[String]:
	return _formation.duplicate()


func set_formation(hero_ids: Array[String]) -> bool:
	# 校验：最多5人，全部已拥有，无重复
	if hero_ids.size() > MAX_FORMATION_SIZE:
		return false
	var seen: Dictionary = {}
	for hid in hero_ids:
		if not is_owned(hid):
			return false
		if seen.has(hid):
			return false
		seen[hid] = true

	_formation = hero_ids.duplicate()
	formation_changed.emit(_formation.duplicate())
	_persist()
	return true


func add_to_formation(hero_id: String) -> bool:
	if not is_owned(hero_id):
		return false
	if hero_id in _formation:
		return false
	if _formation.size() >= MAX_FORMATION_SIZE:
		return false
	_formation.append(hero_id)
	formation_changed.emit(_formation.duplicate())
	_persist()
	return true


func remove_from_formation(hero_id: String) -> void:
	_formation.erase(hero_id)
	formation_changed.emit(_formation.duplicate())
	_persist()


func is_in_formation(hero_id: String) -> bool:
	return hero_id in _formation

# ========== 内部方法 ==========

func _on_load_completed(save_data: Dictionary) -> void:
	var save: Dictionary = save_data.get("heroes", {})
	var raw_owned: Array = save.get("owned", [])
	_owned_heroes.clear()
	_owned_heroes.assign(raw_owned)
	_hero_levels = save.get("levels", {})
	_hero_qualities = save.get("qualities", {})
	var raw_formation: Array = save.get("formation", [])
	_formation.clear()
	_formation.assign(raw_formation)
	if _owned_heroes.is_empty():
		_grant_starter_hero()


func _persist() -> void:
	SaveManager.set_data("heroes", {
		"owned": _owned_heroes.duplicate(),
		"levels": _hero_levels.duplicate(),
		"qualities": _hero_qualities.duplicate(),
		"formation": _formation.duplicate(),
	})
	SaveManager.mark_dirty()
