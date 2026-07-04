## SaveManager - 存档 / 读档 / 版本迁移
## 对应 Java 的 Repository / JS 的 localStorage 封装
##
## 职责:
##   - 玩家数据序列化/反序列化 (JSON 格式)
##   - 存档版本管理与迁移
##   - 自动存档 (30s 定时 / 场景切换 / 后台)
##   - 关键操作即时存档 (save_now)
extends Node

# ========== 信号 ==========

signal save_completed()
signal save_failed(error: String)
signal load_completed(save_data: Dictionary)

# ========== 常量 ==========

const SAVE_PATH: String = "user://save_data.json"
const SAVE_VERSION: int = 2
const AUTO_SAVE_INTERVAL: float = 30.0  # 自动存档间隔（秒），60→30

# ========== 状态 ==========

var _save_data: Dictionary = {}
var _auto_save_timer: Timer = null
var _is_dirty: bool = false  # 数据有变更未保存

# ========== 默认存档 ==========

func _get_default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": {
			"uid": "",
			"nickname": "道友",
			"create_time": int(Time.get_unix_time_from_system()),
			"play_time_seconds": 0,
			"last_save_time": int(Time.get_unix_time_from_system()),  # Bug 修复: 移入 player 段
		},
		"resources": {
			"spirit_stones": 0,    # 灵石（基础货币）
			"jade": 0,             # 仙玉（高级货币）
			"exp": 0,              # 修为（经验）
			"dust": 0,             # 灵尘（升品质材料）
			"fragments": {},       # 修士碎片 {hero_id: count}
		},
		"heroes": {
			"owned": [],           # 已拥有的修士ID列表
			"levels": {},          # {hero_id: level}
			"qualities": {},       # {hero_id: quality_index}
			"formation": [],       # 当前阵容 [hero_id, ...] 最多5个
		},
		"stage": {
			"current_stage": 1,    # 当前关卡
			"max_stage": 1,        # 最高通关
			"stars": {},           # {stage_id: star_count}
		},
		"gacha": {
			"total_pulls": 0,
			"pity_counter": 0,     # 保底计数
			"wishlist": [],        # 心愿单 [hero_id, ...] 最多3个
			"active_banner": "normal",  # 当前卡池ID
		},
		"settings": {
			"bgm_volume": 0.8,
			"sfx_volume": 1.0,
			"language": "zh",
		},
	}

# ========== 生命周期 ==========

func _ready() -> void:
	_save_data = _get_default_save_data()
	load_game()

	# 初始化自动存档定时器
	_auto_save_timer = Timer.new()
	_auto_save_timer.name = "AutoSaveTimer"
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)


func _exit_tree() -> void:
	# 退出前确保存档
	save_game()

# ========== 公开接口 ==========

func save_game() -> void:
	# Bug 修复: 更新 player 段的 last_save_time（而非根级）
	var player_data: Dictionary = _save_data.get("player", {})
	player_data["last_save_time"] = int(Time.get_unix_time_from_system())
	_save_data["player"] = player_data

	var json_string: String = JSON.stringify(_save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if not file:
		save_failed.emit("无法打开存档文件: %s" % FileAccess.get_open_error())
		return

	file.store_string(json_string)
	file.close()
	_is_dirty = false
	save_completed.emit()
	print("[SaveManager] 存档成功")


## 即时存档：标记脏数据并立即执行存档
## 在升级/突破/战斗结束/抽卡等关键操作后调用
func save_now() -> void:
	_is_dirty = true
	save_game()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] 无存档，使用默认数据")
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] 读取存档失败")
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("[SaveManager] JSON 解析失败: %s (行 %d)" % [json.get_error_message(), json.get_error_line()])
		return false

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_error("[SaveManager] 存档格式错误")
		return false

	_save_data = _migrate_save(parsed)
	load_completed.emit(_save_data)
	print("[SaveManager] 读档成功")
	return true


func get_data(section: String) -> Dictionary:
	if _save_data.has(section):
		return _save_data[section]
	push_warning("[SaveManager] 未知存档段: %s" % section)
	return {}


func set_data(section: String, data: Dictionary) -> void:
	_save_data[section] = data
	_is_dirty = true


func mark_dirty() -> void:
	_is_dirty = true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save_data = _get_default_save_data()
	print("[SaveManager] 存档已删除")

# ========== 内部方法 ==========

func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 1)

	# Bug 修复迁移: 将根级 last_save_time 迁移到 player 段
	if data.has("last_save_time"):
		var player_data: Dictionary = data.get("player", {})
		if not player_data.has("last_save_time"):
			player_data["last_save_time"] = int(data["last_save_time"])
			data["player"] = player_data
		data.erase("last_save_time")

	# 确保 player 段存在且有 last_save_time
	var player_data: Dictionary = data.get("player", {})
	if not player_data.has("last_save_time"):
		player_data["last_save_time"] = int(Time.get_unix_time_from_system())
		data["player"] = player_data

	# v1 → v2 迁移: gacha 段增加 wishlist 和 active_banner
	if version < 2:
		var gacha_data: Dictionary = data.get("gacha", {})
		if not gacha_data.has("wishlist"):
			gacha_data["wishlist"] = []
		if not gacha_data.has("active_banner"):
			gacha_data["active_banner"] = "normal"
		data["gacha"] = gacha_data
		print("[SaveManager] 存档迁移 v1 → v2: 补全 gacha.wishlist / gacha.active_banner")

	data["version"] = SAVE_VERSION
	return data


func _on_auto_save() -> void:
	if _is_dirty:
		save_game()
