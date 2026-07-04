## IdleSystem - 离线/在线收益系统
## 对应 Java 的 IdleRewardCalculator / JS 的 passive income tracker
##
## 职责:
##   - 计算离线收益（灵石/修为）
##   - 离线时间上限控制（12小时）
##   - 收益系数计算
##   - 在线实时积累收益
class_name IdleSystem
extends Node

# ========== 信号 ==========

signal offline_rewards_calculated(rewards: Dictionary)
signal offline_rewards_collected(rewards: Dictionary)
signal online_rewards_collected(rewards: Dictionary)

# ========== 常量 ==========

const MAX_OFFLINE_HOURS: float = 12.0
const SPIRIT_STONE_RATE_PER_HOUR: float = 100.0
const EXP_RATE_PER_HOUR: float = 800.0
const OFFLINE_COEFF_SPIRIT_STONES: float = 0.6   # 离线效率 60%
const OFFLINE_COEFF_EXP: float = 0.9              # 离线效率 90%

# ========== 在线积累状态（实例变量）==========

var _accumulated_stones: float = 0.0
var _accumulated_exp: float = 0.0

# ========== 静态持久化（跨场景实例保留累计收益）==========
## IdleSystem 由 Home 场景实例化，场景切换时会被销毁。
## 使用静态变量在销毁前保存、创建后恢复累计收益，确保跨场景连续积累。

static var _persisted_stones: float = 0.0
static var _persisted_exp: float = 0.0

# ========== 生命周期 ==========

func _ready() -> void:
	# 从静态变量恢复累计收益（跨场景保留）
	_accumulated_stones = _persisted_stones
	_accumulated_exp = _persisted_exp


func _exit_tree() -> void:
	# 场景销毁前保存累计收益到静态变量
	_persisted_stones = _accumulated_stones
	_persisted_exp = _accumulated_exp


func _process(delta: float) -> void:
	# 每帧积累在线收益（速率 × delta）
	var rate: Dictionary = get_online_rate()
	_accumulated_stones += float(rate.get("spirit_stones_per_sec", 0.0)) * delta
	_accumulated_exp += float(rate.get("exp_per_sec", 0.0)) * delta

# ========== 公开接口 - 离线收益 ==========

## 计算离线收益
## last_timestamp: 上次在线的 Unix 时间戳（秒）
func calculate_offline_rewards(last_timestamp: int) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed_seconds: int = now - last_timestamp
	var elapsed_hours: float = float(elapsed_seconds) / 3600.0

	# 上限 12 小时
	elapsed_hours = min(elapsed_hours, MAX_OFFLINE_HOURS)

	# 不足 1 分钟不计算
	if elapsed_hours < 1.0 / 60.0:
		return {}

	# 从 balance.json 读取配置（如果有）
	var balance: Dictionary = JSONLoader.load_dict("res://data/balance.json")
	var idle_cfg: Dictionary = balance.get("idle", {})
	var max_hours: float = float(idle_cfg.get("max_offline_hours", MAX_OFFLINE_HOURS))
	var ss_rate: float = float(idle_cfg.get("spirit_stone_rate_per_hour", SPIRIT_STONE_RATE_PER_HOUR))
	var exp_rate: float = float(idle_cfg.get("exp_rate_per_hour", EXP_RATE_PER_HOUR))
	var coeff: Dictionary = idle_cfg.get("offline_coefficient", {})
	var ss_coeff: float = float(coeff.get("spirit_stones", OFFLINE_COEFF_SPIRIT_STONES))
	var exp_coeff: float = float(coeff.get("exp", OFFLINE_COEFF_EXP))

	elapsed_hours = min(elapsed_hours, max_hours)

	var rewards: Dictionary = {
		"spirit_stones": int(ss_rate * elapsed_hours * ss_coeff),
		"exp": int(exp_rate * elapsed_hours * exp_coeff),
		"offline_hours": elapsed_hours,
	}

	offline_rewards_calculated.emit(rewards)
	return rewards


## 收取离线收益
func collect_offline_rewards(rewards: Dictionary) -> void:
	if rewards.has("spirit_stones"):
		EconomyManager.add_spirit_stones(rewards["spirit_stones"])
	if rewards.has("exp"):
		EconomyManager.add_exp(rewards["exp"])
	offline_rewards_collected.emit(rewards)


## 获取当前在线收益速率（每秒）
func get_online_rate() -> Dictionary:
	var balance: Dictionary = JSONLoader.load_dict("res://data/balance.json")
	var idle_cfg: Dictionary = balance.get("idle", {})
	return {
		"spirit_stones_per_sec": float(idle_cfg.get("spirit_stone_rate_per_hour", SPIRIT_STONE_RATE_PER_HOUR)) / 3600.0,
		"exp_per_sec": float(idle_cfg.get("exp_rate_per_hour", EXP_RATE_PER_HOUR)) / 3600.0,
	}

# ========== 公开接口 - 在线收益 ==========

## 获取当前未领取的累计收益（不清零）
func get_pending_rewards() -> Dictionary:
	return {
		"spirit_stones": int(_accumulated_stones),
		"exp": int(_accumulated_exp),
	}


## 收取在线累计收益并清零
func collect_online_rewards() -> Dictionary:
	var rewards: Dictionary = {
		"spirit_stones": int(_accumulated_stones),
		"exp": int(_accumulated_exp),
	}
	EconomyManager.add_spirit_stones(rewards["spirit_stones"])
	EconomyManager.add_exp(rewards["exp"])
	_accumulated_stones = 0.0
	_accumulated_exp = 0.0
	# 同步更新静态变量
	_persisted_stones = 0.0
	_persisted_exp = 0.0
	online_rewards_collected.emit(rewards)
	return rewards
