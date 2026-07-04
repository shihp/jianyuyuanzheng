class_name MathUtils
## MathUtils - 数学计算工具
## 对应 Java 的 MathUtils / JS 的 Lodash 数学函数
extends RefCounted

# ========== 公开静态接口 ==========

## 线性插值
static func lerp_float(a: float, b: float, t: float) -> float:
	return a + (b - a) * clampf(t, 0.0, 1.0)


## 指数增长 (用于属性曲线)
## 公式: base * (rate ^ level)
static func exponential_growth(base: float, rate: float, level: int) -> float:
	return base * pow(rate, level)


## 对数增长 (用于经验需求曲线)
## 公式: base * level^power
static func power_growth(base: float, power: float, level: int) -> float:
	return base * pow(float(level), power)


## 计算升级所需经验 (类似 AFK Arena)
## 公式: 100 * level^1.5
static func exp_to_next_level(current_level: int) -> int:
	return int(100 * pow(float(current_level), 1.5))


## 计算升级所需灵石
## 公式: 100 * level^1.5
static func cost_to_next_level(current_level: int) -> int:
	return int(100 * pow(float(current_level), 1.5))


## 权重随机选择
## weights: [0.5, 0.3, 0.2] → 返回索引
static func weighted_random(weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return weights.size() - 1


## 钳制到范围
static func clamp_int(value: int, min_val: int, max_val: int) -> int:
	return max(min_val, min(max_val, value))


## 百分比格式化
static func format_percent(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f%%") % (value * 100.0)


## 大数字格式化 (10000 → 1.0万, 10000000 → 1000.0万)
static func format_big_number(value: int) -> String:
	if value >= 100000000:
		return "%.1f亿" % (float(value) / 100000000.0)
	elif value >= 10000:
		return "%.1f万" % (float(value) / 10000.0)
	else:
		return str(value)
