## TopBar - 顶部资源栏
## 显示: 灵石 / 仙玉 / 修为 / 关卡进度
extends Control

@onready var _spirit_stone_label: Label = $HBox/SpiritStoneLabel
@onready var _jade_label: Label = $HBox/JadeLabel
@onready var _exp_label: Label = $HBox/ExpLabel
@onready var _stage_label: Label = $HBox/StageLabel

func _ready() -> void:
	set_anchors_preset(PRESET_TOP_WIDE)
	_refresh()
	EconomyManager.resource_changed.connect(func(_t, _v, _d): _refresh())


func _refresh() -> void:
	if _spirit_stone_label:
		_spirit_stone_label.text = "灵石: %s" % MathUtils.format_big_number(EconomyManager.get_amount(&"spirit_stones"))
	if _jade_label:
		_jade_label.text = "仙玉: %d" % EconomyManager.get_amount(&"jade")
	if _exp_label:
		_exp_label.text = "修为: %s" % MathUtils.format_big_number(EconomyManager.get_amount(&"exp"))
	if _stage_label:
		var current: int = StageManager.get_current_stage()
		var realm_name: String = StageManager.get_realm_name(current)
		if not realm_name.is_empty():
			_stage_label.text = "%s · 第 %d 关" % [realm_name, current]
		else:
			_stage_label.text = "第 %d 关" % current
