## StageMap - 关卡地图
## 显示: 当前关卡 / 关卡列表 / 星级 / 阵容战力 / 斗法按钮 / 导航
extends Control

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _stage_container: VBoxContainer = $VBox/ScrollContainer/StageContainer
@onready var _battle_button: Button = $VBox/BattleButton
@onready var _power_label: Label = $VBox/PowerLabel

# 最多显示的关卡数
const DISPLAY_COUNT: int = 5


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_update_title()
	_update_power_preview()
	_populate_stage_list()
	if _battle_button:
		_battle_button.pressed.connect(_on_battle_pressed)

	# 监听关卡解锁信号（战斗胜利后刷新）
	StageManager.stage_unlocked.connect(_on_stage_unlocked)


func _exit_tree() -> void:
	if StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.disconnect(_on_stage_unlocked)


func _update_title() -> void:
	if not _title_label:
		return
	var current_stage: int = StageManager.get_current_stage()
	var stage_data: Dictionary = StageManager.get_stage_data(current_stage)
	var stage_name: String = stage_data.get("name", "???")
	var realm_name: String = StageManager.get_realm_name(current_stage)
	var is_tribulation: bool = StageManager.is_tribulation_stage(current_stage)

	var title_text: String = ""
	if not realm_name.is_empty():
		title_text = "【%s】第 %d 关 — %s" % [realm_name, current_stage, stage_name]
	else:
		title_text = "第 %d 关 — %s" % [current_stage, stage_name]
	if is_tribulation:
		title_text += " ⚡渡劫"
	_title_label.text = title_text


## 显示当前阵容总战力 vs 推荐战力
func _update_power_preview() -> void:
	if not _power_label:
		return
	var formation: Array[String] = HeroManager.get_formation()
	if formation.is_empty():
		formation = HeroManager.get_owned_heroes()

	var player_power: int = 0
	if not formation.is_empty():
		player_power = FormationSystem.calculate_power(formation)

	var current_stage: int = StageManager.get_current_stage()
	var stage_data: Dictionary = StageManager.get_stage_data(current_stage)
	var recommended_power: int = int(stage_data.get("recommended_power", 0))

	var color: Color = Color(0.9, 0.9, 0.5)
	if player_power >= recommended_power and recommended_power > 0:
		color = Color(0.3, 1.0, 0.3)
	elif player_power < recommended_power * 0.7 and recommended_power > 0:
		color = Color(1.0, 0.4, 0.4)

	_power_label.text = "阵容战力: %d  /  推荐: %d" % [player_power, recommended_power]
	_power_label.modulate = color


func _populate_stage_list() -> void:
	if not _stage_container:
		return

	# 清空旧内容
	for child in _stage_container.get_children():
		child.queue_free()

	var current_stage: int = StageManager.get_current_stage()

	# 以当前关卡为中心显示 5 个关卡
	var start_stage: int = max(1, current_stage - 2)
	var end_stage: int = start_stage + DISPLAY_COUNT - 1

	for sid in range(start_stage, end_stage + 1):
		var stage_data: Dictionary = StageManager.get_stage_data(sid)
		if stage_data.is_empty():
			break  # 该关卡不存在，停止

		var stage_name: String = stage_data.get("name", "???")
		var is_boss: bool = bool(stage_data.get("is_boss", false))
		var is_tribulation: bool = StageManager.is_tribulation_stage(sid)
		var recommended_power: int = int(stage_data.get("recommended_power", 0))
		var stars: int = StageManager.get_stage_stars(sid)
		var is_unlocked: bool = StageManager.is_stage_unlocked(sid)
		var is_current: bool = (sid == current_stage)

		# 构建显示文本
		var boss_tag: String = ""
		if is_tribulation:
			boss_tag = " ⚡渡劫"
		elif is_boss:
			boss_tag = " [BOSS]"
		var star_text: String = ""
		if stars > 0:
			star_text = " %s" % "★".repeat(stars)

		var label: Label = Label.new()
		label.text = "第%d关  %s%s  战力:%d%s" % [
			sid, stage_name, boss_tag, recommended_power, star_text
		]
		label.add_theme_font_size_override("font_size", 20)

		# 根据状态设置颜色
		if is_current:
			if is_tribulation:
				# 当前渡劫关（金色）
				label.modulate = Color(1.0, 0.8, 0.2)
			else:
				# 当前普通关（金色）
				label.modulate = Color(1.0, 0.9, 0.3)
			label.text += "  ← 当前"
		elif is_tribulation and stars > 0:
			# 已通关渡劫关（紫色）
			label.modulate = Color(0.7, 0.3, 1.0)
		elif is_tribulation:
			# 未通关渡劫关（亮紫色）
			label.modulate = Color(0.8, 0.4, 1.0)
		elif stars > 0:
			# 已通关普通关（绿色）
			label.modulate = Color(0.3, 1.0, 0.3)
		elif not is_unlocked:
			# 未解锁（灰色）
			label.modulate = Color(0.4, 0.4, 0.4)
		else:
			# 已解锁未通关（白色）
			label.modulate = Color(0.9, 0.9, 0.9)

		_stage_container.add_child(label)


func _on_stage_unlocked(_stage_id: int) -> void:
	# 关卡解锁后刷新列表
	_update_title()
	_update_power_preview()
	_populate_stage_list()


func _on_battle_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_battle()
