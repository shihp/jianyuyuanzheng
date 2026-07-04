## EconomyManager - 资源管理统一入口
## 对应 Java 的 WalletService / JS 的 currency store
##
## 职责:
##   - 管理所有游戏货币 (灵石/仙玉/修为/灵尘/碎片)
##   - 资源增减 + 余额校验
##   - 资源变更信号广播
extends Node

# ========== 信号 ==========

signal resource_changed(resource_type: StringName, new_value: int, delta: int)
signal resource_insufficient(resource_type: StringName, needed: int, current: int)

# ========== 枚举 ==========

enum ResourceType {
	SPIRIT_STONES,  # 灵石
	JADE,           # 仙玉
	EXP,            # 修为
	DUST,           # 灵尘
}

const RESOURCE_KEYS: Array[StringName] = [
	&"spirit_stones",
	&"jade",
	&"exp",
	&"dust",
]

# ========== 状态 ==========

var _resources: Dictionary = {
	&"spirit_stones": 0,
	&"jade": 0,
	&"exp": 0,
	&"dust": 0,
}

# ========== 生命周期 ==========

func _ready() -> void:
	add_jade(5000)
	# 从存档加载资源（先读取，避免 add_jade 覆盖存档数据）
	var saved_res: Dictionary = SaveManager.get_data("resources")
	for key in RESOURCE_KEYS:
		if saved_res.has(String(key)):
			_resources[key] = saved_res[String(key)]
	# 加载碎片数据
	_fragments = saved_res.get("fragments", {}).duplicate()
	# 新玩家赠送 5000 仙玉
	if not SaveManager.has_save():
		add_jade(5000)
	# 监听存档加载完成
	SaveManager.load_completed.connect(_on_load_completed)

# ========== 公开接口 ==========

func get_amount(resource_type: StringName) -> int:
	return _resources.get(resource_type, 0)


func can_afford(resource_type: StringName, amount: int) -> bool:
	return get_amount(resource_type) >= amount


func add(resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var old: int = _resources.get(resource_type, 0)
	_resources[resource_type] = old + amount
	resource_changed.emit(resource_type, _resources[resource_type], amount)
	_persist()


func spend(resource_type: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(resource_type, amount):
		resource_insufficient.emit(resource_type, amount, get_amount(resource_type))
		return false
	_resources[resource_type] -= amount
	resource_changed.emit(resource_type, _resources[resource_type], -amount)
	_persist()
	return true


func set_amount(resource_type: StringName, amount: int) -> void:
	var old: int = _resources.get(resource_type, 0)
	_resources[resource_type] = max(0, amount)
	resource_changed.emit(resource_type, _resources[resource_type], _resources[resource_type] - old)
	_persist()


func add_spirit_stones(amount: int) -> void:
	add(&"spirit_stones", amount)


func add_jade(amount: int) -> void:
	add(&"jade", amount)


func add_exp(amount: int) -> void:
	add(&"exp", amount)


func add_dust(amount: int) -> void:
	add(&"dust", amount)


func spend_spirit_stones(amount: int) -> bool:
	return spend(&"spirit_stones", amount)


func spend_jade(amount: int) -> bool:
	return spend(&"jade", amount)


func spend_dust(amount: int) -> bool:
	return spend(&"dust", amount)


func spend_exp(amount: int) -> bool:
	return spend(&"exp", amount)

# ========== 碎片系统（按修士 ID 存储）==========

var _fragments: Dictionary = {}  # {hero_id: count}

func get_fragments(hero_id: String) -> int:
	return _fragments.get(hero_id, 0)


func add_fragments(hero_id: String, count: int) -> void:
	_fragments[hero_id] = get_fragments(hero_id) + count
	_persist()


func spend_fragments(hero_id: String, count: int) -> bool:
	if get_fragments(hero_id) < count:
		return false
	_fragments[hero_id] -= count
	if _fragments[hero_id] <= 0:
		_fragments.erase(hero_id)
	_persist()
	return true


func get_fragment_count(hero_id: String) -> int:
	return get_fragments(hero_id)


## 获取拥有碎片的修士种类数（用于 UI 显示）
func get_total_fragment_types() -> int:
	return _fragments.size()


## 获取所有碎片总量
func get_total_fragments() -> int:
	var total: int = 0
	for count in _fragments.values():
		total += count
	return total

# ========== 内部方法 ==========

func _on_load_completed(save_data: Dictionary) -> void:
	var saved_res: Dictionary = save_data.get("resources", {})
	for key in RESOURCE_KEYS:
		if saved_res.has(String(key)):
			_resources[key] = saved_res[String(key)]
	_fragments = saved_res.get("fragments", {}).duplicate()


func _persist() -> void:
	# 写回存档
	var res_data: Dictionary = {}
	for key in RESOURCE_KEYS:
		res_data[String(key)] = _resources[key]
	res_data["fragments"] = _fragments.duplicate()
	SaveManager.set_data("resources", res_data)
	SaveManager.mark_dirty()
