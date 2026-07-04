## OfflineRewardPopup - 离线收益弹窗
## 显示离线时长、灵石收益、修为收益，玩家点击领取后入账
extends Control

signal rewards_collected(rewards: Dictionary)

@onready var _time_label: Label = $PopupPanel/VBox/TimeLabel
@onready var _stones_label: Label = $PopupPanel/VBox/StonesLabel
@onready var _exp_label: Label = $PopupPanel/VBox/ExpLabel
@onready var _collect_button: Button = $PopupPanel/VBox/CollectButton

var _rewards: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	if _collect_button:
		_collect_button.pressed.connect(_on_collect_pressed)


## 传入离线收益数据并刷新显示
func setup(rewards: Dictionary) -> void:
	_rewards = rewards
	_refresh_display()


func _refresh_display() -> void:
	var hours: float = float(_rewards.get("offline_hours", 0.0))
	var stones: int = int(_rewards.get("spirit_stones", 0))
	var exp: int = int(_rewards.get("exp", 0))

	if _time_label:
		if hours >= 1.0:
			_time_label.text = "闭关时长: %.1f 小时" % hours
		else:
			var minutes: int = int(hours * 60.0)
			_time_label.text = "闭关时长: %d 分钟" % minutes

	if _stones_label:
		_stones_label.text = "灵石  +%s" % MathUtils.format_big_number(stones)

	if _exp_label:
		_exp_label.text = "修为  +%s" % MathUtils.format_big_number(exp)


func _on_collect_pressed() -> void:
	AudioManager.play_sfx("coin")
	rewards_collected.emit(_rewards)
	queue_free()
