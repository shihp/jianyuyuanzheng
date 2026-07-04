## GachaManager - 抽卡 / 保底 / 概率 / 心愿单 / 碎片转换
## 对应 Java 的 GachaService / JS 的 loot box controller
##
## 职责:
##   - 单抽 / 十连
##   - 概率计算（品质分级，从 gacha.json 读取）
##   - 保底计数与触发
##   - 心愿单系统（SR+ 50%概率出心愿单修士）
##   - 重复修士转碎片（按 rarity 查 fragment_conversion）
##   - 卡池管理（多 banner 切换）
extends Node

# ========== 信号 ==========

signal pull_started(count: int)
signal pull_completed(results: Array)
signal pity_triggered()
signal jade_insufficient(needed: int, current: int)
signal wishlist_changed(wishlist: Array)

# ========== 常量 ==========

# 品质索引 → 名称映射
const RARITY_NAMES: Array[String] = ["", "R", "SR", "SSR", "UR"]

# ========== 状态 ==========

var _pity_counter: int = 0
var _total_pulls: int = 0
var _gacha_config: Dictionary = {}        # gacha.json 完整配置
var _active_banner_id: String = "normal"  # 当前卡池 ID
var _wishlist: Array[String] = []         # 心愿单 hero_id 列表
var _fragment_conversion: Dictionary = {} # 碎片转换配置 {rarity_name: count}

# ========== 生命周期 ==========

func _ready() -> void:
	_load_gacha_config()
	_load_from_save()
	SaveManager.load_completed.connect(_on_load_completed)


## 加载 gacha.json 配置
func _load_gacha_config() -> void:
	_gacha_config = JSONLoader.load_dict("res://data/gacha.json")
	_fragment_conversion = _gacha_config.get("fragment_conversion", {})
	print("[GachaManager] 加载 gacha.json: %d 个卡池, 碎片转换 %d 档" % [
		_gacha_config.get("banners", []).size(), _fragment_conversion.size()
	])

# ========== 配置 Getter（替代硬编码常量）==========

## 获取单抽消耗（仙玉）
func get_single_pull_cost() -> int:
	var banner: Dictionary = _get_active_banner()
	return int(banner.get("cost_per_pull", 200))


## 获取十连消耗（仙玉）
func get_ten_pull_cost() -> int:
	var banner: Dictionary = _get_active_banner()
	return int(banner.get("cost_per_ten", 2000))


## 获取保底阈值
func get_pity_threshold() -> int:
	var banner: Dictionary = _get_active_banner()
	return int(banner.get("pity_threshold", 30))


## 获取当前卡池概率配置
func get_rates() -> Dictionary:
	var banner: Dictionary = _get_active_banner()
	return banner.get("rates", {"R": 0.75, "SR": 0.20, "SSR": 0.045, "UR": 0.005})


## 获取心愿单配置
func get_wishlist_config() -> Dictionary:
	return _gacha_config.get("wishlist", {"max_size": 3, "min_rarity": 2, "probability": 0.5})

# ========== 卡池管理 ==========

## 获取所有卡池列表
func get_banners() -> Array:
	return _gacha_config.get("banners", [])


## 获取当前激活的卡池配置
func _get_active_banner() -> Dictionary:
	var banners: Array = _gacha_config.get("banners", [])
	for banner in banners:
		if banner.get("banner_id", "") == _active_banner_id:
			return banner
	# 回退到第一个卡池或默认值
	if not banners.is_empty():
		return banners[0]
	return {
		"banner_id": "normal",
		"banner_name": "寻仙台",
		"cost_per_pull": 200,
		"cost_per_ten": 2000,
		"pity_threshold": 30,
		"rates": {"R": 0.75, "SR": 0.20, "SSR": 0.045, "UR": 0.005},
		"available_heroes": "all",
	}


## 获取当前激活卡池 ID
func get_active_banner_id() -> String:
	return _active_banner_id


## 获取当前激活卡池信息（供 UI 显示）
func get_active_banner() -> Dictionary:
	return _get_active_banner()


## 设置激活卡池
func set_active_banner(banner_id: String) -> void:
	_active_banner_id = banner_id
	_persist()


## 获取当前激活卡池名称
func get_active_banner_name() -> String:
	var banner: Dictionary = _get_active_banner()
	return banner.get("banner_name", "寻仙台")

# ========== 心愿单 ==========

## 获取当前心愿单
func get_wishlist() -> Array[String]:
	return _wishlist.duplicate()


## 设置心愿单（校验：数量≤max_size, rarity≥min_rarity, 无重复, hero存在）
func set_wishlist(hero_ids: Array[String]) -> bool:
	var wl_cfg: Dictionary = get_wishlist_config()
	var max_size: int = int(wl_cfg.get("max_size", 3))
	var min_rarity: int = int(wl_cfg.get("min_rarity", 2))

	# 校验数量
	if hero_ids.size() > max_size:
		push_warning("[GachaManager] 心愿单超过最大数量 %d" % max_size)
		return false

	# 校验无重复 + 存在性 + 品质
	var seen: Dictionary = {}
	for hid in hero_ids:
		# 无重复
		if seen.has(hid):
			push_warning("[GachaManager] 心愿单有重复修士: %s" % hid)
			return false
		seen[hid] = true
		# hero 存在
		var hero_data: Dictionary = HeroManager.get_hero_data(hid)
		if hero_data.is_empty():
			push_warning("[GachaManager] 心愿单修士不存在: %s" % hid)
			return false
		# 品质 >= min_rarity
		var rarity: int = int(hero_data.get("rarity", 1))
		if rarity < min_rarity:
			push_warning("[GachaManager] 心愿单修士品质不足 (需≥%d): %s" % [min_rarity, hid])
			return false

	_wishlist = hero_ids.duplicate()
	_persist()
	wishlist_changed.emit(_wishlist.duplicate())
	return true


## 清空心愿单
func clear_wishlist() -> void:
	_wishlist.clear()
	_persist()
	wishlist_changed.emit(_wishlist.duplicate())

# ========== 碎片转换 ==========

## 将重复修士转换为碎片（按 rarity 查 fragment_conversion）
func _convert_to_fragments(hero_id: String) -> int:
	var rarity: int = HeroManager.get_hero_rarity(hero_id)
	var rarity_name: String = _rarity_index_to_name(rarity)
	var count: int = int(_fragment_conversion.get(rarity_name, 10))
	EconomyManager.add_fragments(hero_id, count)
	return count

# ========== 公开接口 ==========

func single_pull() -> Dictionary:
	var cost: int = get_single_pull_cost()
	if not EconomyManager.spend_jade(cost):
		jade_insufficient.emit(cost, EconomyManager.get_amount(&"jade"))
		return {}

	pull_started.emit(1)
	var result: Dictionary = _do_pull()
	pull_completed.emit([result])
	return result


func ten_pull() -> Array:
	var cost: int = get_ten_pull_cost()
	if not EconomyManager.spend_jade(cost):
		jade_insufficient.emit(cost, EconomyManager.get_amount(&"jade"))
		return []

	pull_started.emit(10)
	var results: Array = []
	for i in range(10):
		results.append(_do_pull())

	# 十连保底至少一个SR+
	if not _has_sr_or_above(results):
		# 替换最后一个为SR
		results[-1] = _force_pull_rarity(2)  # rarity=2 是SR

	pull_completed.emit(results)
	return results


func get_pity_counter() -> int:
	return _pity_counter


func get_pity_remaining() -> int:
	return get_pity_threshold() - _pity_counter


func get_total_pulls() -> int:
	return _total_pulls

# ========== 核心逻辑 ==========

func _do_pull() -> Dictionary:
	_total_pulls += 1
	_pity_counter += 1

	var rarity: int = _roll_rarity()

	# 保底检查
	var pity_threshold: int = get_pity_threshold()
	if _pity_counter >= pity_threshold and rarity < 3:  # 3=SSR
		rarity = 3  # 强制SSR
		_pity_counter = 0
		pity_triggered.emit()

	if rarity >= 3:  # SSR或以上 → 重置保底
		_pity_counter = 0

	# 从对应品质池中随机一个修士
	var hero_id: String = _pick_hero_by_rarity(rarity)

	# 添加到玩家收藏（新修士添加，重复转碎片）
	var is_new: bool = not HeroManager.is_owned(hero_id)
	var result: Dictionary = {
		"hero_id": hero_id,
		"rarity": rarity,
		"is_new": is_new,
	}

	if is_new:
		HeroManager.add_hero(hero_id)
	else:
		# 重复修士 → 转碎片
		var frag_count: int = _convert_to_fragments(hero_id)
		result["fragments"] = frag_count

	_persist()

	return result


## 从当前卡池概率配置随机品质
func _roll_rarity() -> int:
	var rates: Dictionary = get_rates()
	var ur: float = float(rates.get("UR", 0.005))
	var ssr: float = float(rates.get("SSR", 0.045))
	var sr: float = float(rates.get("SR", 0.20))

	var roll: float = randf()
	if roll < ur:
		return 4   # UR
	elif roll < ur + ssr:
		return 3   # SSR
	elif roll < ur + ssr + sr:
		return 2   # SR
	else:
		return 1   # R


## 从对应品质池中随机一个修士（含心愿单逻辑 + banner 过滤）
func _pick_hero_by_rarity(rarity: int) -> String:
	# 心愿单逻辑：SR+ 且心愿单非空 且随机命中概率
	var wl_cfg: Dictionary = get_wishlist_config()
	var min_rarity: int = int(wl_cfg.get("min_rarity", 2))
	var wl_prob: float = float(wl_cfg.get("probability", 0.5))

	if rarity >= min_rarity and not _wishlist.is_empty() and randf() < wl_prob:
		# 从心愿单中筛选同 rarity 修士
		var wl_candidates: Array[String] = []
		for hid in _wishlist:
			var hero_data: Dictionary = HeroManager.get_hero_data(hid)
			if not hero_data.is_empty() and int(hero_data.get("rarity", 1)) == rarity:
				wl_candidates.append(hid)
		if not wl_candidates.is_empty():
			return wl_candidates[randi() % wl_candidates.size()]

	# 从 banner 可用英雄池筛选
	var candidates: Array[String] = _get_banner_candidates(rarity)

	if candidates.is_empty():
		# 降级查找：从全部英雄中选
		var all_heroes: Array = JSONLoader.load_array("res://data/heroes.json")
		for hero in all_heroes:
			candidates.append(hero["id"])

	if candidates.is_empty():
		return ""

	return candidates[randi() % candidates.size()]


## 获取当前卡池中指定品质的候选修士
func _get_banner_candidates(rarity: int) -> Array[String]:
	var banner: Dictionary = _get_active_banner()
	var available: Variant = banner.get("available_heroes", "all")
	var candidates: Array[String] = []

	if available == "all":
		# 全部英雄
		var all_heroes: Array = JSONLoader.load_array("res://data/heroes.json")
		for hero in all_heroes:
			if int(hero.get("rarity", 1)) == rarity:
				candidates.append(hero["id"])
	else:
		# 指定英雄池
		var available_list: Array = available
		for hid in available_list:
			var hero_data: Dictionary = HeroManager.get_hero_data(hid)
			if not hero_data.is_empty() and int(hero_data.get("rarity", 1)) == rarity:
				candidates.append(hid)

	return candidates


## 强制抽出指定品质的修士（十连保底用）
func _force_pull_rarity(rarity: int) -> Dictionary:
	var hero_id: String = _pick_hero_by_rarity(rarity)
	var is_new: bool = not HeroManager.is_owned(hero_id)
	var result: Dictionary = {
		"hero_id": hero_id,
		"rarity": rarity,
		"is_new": is_new,
	}

	if is_new:
		HeroManager.add_hero(hero_id)
	else:
		var frag_count: int = _convert_to_fragments(hero_id)
		result["fragments"] = frag_count

	_persist()
	return result


func _has_sr_or_above(results: Array) -> bool:
	for r in results:
		if r.get("rarity", 0) >= 2:
			return true
	return false

# ========== 辅助方法 ==========

## 品质索引转名称 (1→"R", 2→"SR", 3→"SSR", 4→"UR")
func _rarity_index_to_name(rarity: int) -> String:
	if rarity >= 0 and rarity < RARITY_NAMES.size():
		return RARITY_NAMES[rarity]
	return "R"

# ========== 存档 ==========

func _load_from_save() -> void:
	var save: Dictionary = SaveManager.get_data("gacha")
	_total_pulls = save.get("total_pulls", 0)
	_pity_counter = save.get("pity_counter", 0)
	var raw_wishlist: Array = save.get("wishlist", [])
	_wishlist.clear()
	_wishlist.assign(raw_wishlist)
	_active_banner_id = save.get("active_banner", "normal")


func _on_load_completed(save_data: Dictionary) -> void:
	var save: Dictionary = save_data.get("gacha", {})
	_total_pulls = save.get("total_pulls", 0)
	_pity_counter = save.get("pity_counter", 0)
	var raw_wishlist: Array = save.get("wishlist", [])
	_wishlist.clear()
	_wishlist.assign(raw_wishlist)
	_active_banner_id = save.get("active_banner", "normal")


func _persist() -> void:
	SaveManager.set_data("gacha", {
		"total_pulls": _total_pulls,
		"pity_counter": _pity_counter,
		"wishlist": _wishlist.duplicate(),
		"active_banner": _active_banner_id,
	})
	SaveManager.mark_dirty()
