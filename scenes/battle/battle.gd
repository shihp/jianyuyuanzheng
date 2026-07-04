## Battle - 斗法场景
## 显示: 敌我双方阵容(HP进度条) / 战斗日志 / 绝学按钮 / 加速控制 / 胜负结果
extends Control

@onready var _enemy_container: VBoxContainer = $VBox/BattleArea/EnemySide
@onready var _player_container: VBoxContainer = $VBox/BattleArea/PlayerSide
@onready var _battle_log: Label = $VBox/BattleArea/BattleLog
@onready var _round_label: Label = $VBox/BattleArea/RoundLabel
@onready var _result_panel: Panel = $VBox/ResultPanel
@onready var _result_label: Label = $VBox/ResultPanel/ResultLabel
@onready var _reward_label: Label = $VBox/ResultPanel/RewardLabel
@onready var _continue_button: Button = $VBox/ResultPanel/ContinueButton
@onready var _skill_button: Button = $VBox/SkillButton
@onready var _speed_1x: Button = $VBox/SpeedBar/Speed1x
@onready var _speed_15x: Button = $VBox/SpeedBar/Speed15x
@onready var _speed_2x: Button = $VBox/SpeedBar/Speed2x

var _current_hero_id: String = ""

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_result_panel.visible = false
	_skill_button.disabled = true

	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)
	if _skill_button:
		_skill_button.pressed.connect(_on_skill_pressed)
	if _speed_1x:
		_speed_1x.pressed.connect(_set_speed.bind(1.0))
	if _speed_15x:
		_speed_15x.pressed.connect(_set_speed.bind(1.5))
	if _speed_2x:
		_speed_2x.pressed.connect(_set_speed.bind(2.0))

	AudioManager.play_bgm("battle")
	_start_battle()


func _exit_tree() -> void:
	_disconnect_signals()


func _disconnect_signals() -> void:
	if BattleManager.battle_started.is_connected(_on_battle_started):
		BattleManager.battle_started.disconnect(_on_battle_started)
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)
	if BattleManager.hero_attacked.is_connected(_on_hero_attacked):
		BattleManager.hero_attacked.disconnect(_on_hero_attacked)
	if BattleManager.skill_triggered.is_connected(_on_skill_triggered):
		BattleManager.skill_triggered.disconnect(_on_skill_triggered)
	if BattleManager.skill_ready.is_connected(_on_skill_ready):
		BattleManager.skill_ready.disconnect(_on_skill_ready)
	if BattleManager.round_started.is_connected(_on_round_started):
		BattleManager.round_started.disconnect(_on_round_started)


func _start_battle() -> void:
	var formation: Array[String] = HeroManager.get_formation()
	if formation.is_empty():
		# 没有阵容，用所有拥有的修士
		formation = HeroManager.get_owned_heroes()

	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.hero_attacked.connect(_on_hero_attacked)
	BattleManager.skill_triggered.connect(_on_skill_triggered)
	BattleManager.skill_ready.connect(_on_skill_ready)
	BattleManager.round_started.connect(_on_round_started)

	BattleManager.start_battle(formation, StageManager.get_current_stage())


# ========== 信号回调 ==========

func _on_battle_started(formation: Array) -> void:
	var log_lines: PackedStringArray = []
	log_lines.append("斗法开始！")

	# 渡劫瓶颈提示（T05）
	var current_stage: int = StageManager.get_current_stage()
	if StageManager.is_tribulation_stage(current_stage):
		log_lines.append("⚡ 渡劫瓶颈 — 此关难度提升，谨慎应战！")

	# 同势力加成提示（T02）
	var bonus_info: Dictionary = BattleManager.get_faction_bonus_info()
	if bool(bonus_info.get("active", false)):
		var faction_name: String = _get_faction_display_name(bonus_info.get("faction", ""))
		var atk_pct: int = int((float(bonus_info.get("atk_mult", 1.0)) - 1.0) * 100)
		var hp_pct: int = int((float(bonus_info.get("hp_mult", 1.0)) - 1.0) * 100)
		log_lines.append("⚡ 同势力加成：%s 攻击+%d%% 生命+%d%%" % [faction_name, atk_pct, hp_pct])

	if _battle_log:
		_battle_log.text = "\n".join(log_lines)
	_refresh_units()


## 获取势力显示名称
func _get_faction_display_name(faction: String) -> String:
	match faction:
		"zhengdao": return "正道"
		"modao": return "魔道"
		"yaozu": return "妖族"
		"fomen": return "佛门"
		_: return faction


func _on_round_started(round_num: int) -> void:
	if _round_label:
		_round_label.text = "第 %d / %d 回合" % [round_num, BattleManager.MAX_BATTLE_ROUNDS]


func _on_hero_attacked(attacker_id: String, target_id: String, damage: int, is_crit: bool) -> void:
	if _battle_log:
		var crit_text: String = " 暴击!" if is_crit else ""
		_battle_log.text = "%s → %s: -%d%s" % [
			_get_display_name(attacker_id),
			_get_display_name(target_id),
			damage,
			crit_text
		]
	_refresh_units()


func _on_skill_triggered(hero_id: String, skill_name: String) -> void:
	if _battle_log:
		_battle_log.text = "%s 释放绝学「%s」!" % [_get_display_name(hero_id), skill_name]
	_refresh_units()


func _on_skill_ready(hero_id: String) -> void:
	_current_hero_id = hero_id
	if _skill_button:
		var data: Dictionary = HeroManager.get_hero_data(hero_id)
		var skill_name: String = data.get("skill_name", "绝学")
		_skill_button.text = "绝学: %s" % skill_name
		_skill_button.disabled = false


func _on_battle_ended(victory: bool, rewards: Dictionary) -> void:
	_result_panel.visible = true
	if _skill_button:
		_skill_button.disabled = true

	if victory:
		_result_label.text = "斗法胜利！"
		_result_label.modulate = Color(0.2, 0.8, 0.2)
		AudioManager.play_sfx("victory")

		var stones: int = rewards.get("spirit_stones", 0)
		var exp: int = rewards.get("exp", 0)
		var reward_text: String = "获得: 灵石 +%d  修为 +%d" % [stones, exp]
		if rewards.has("dust"):
			reward_text += "  灵尘 +%d" % rewards["dust"]
		if rewards.has("fragment_hero"):
			var hero_name: String = HeroManager.get_hero_data(rewards["fragment_hero"]).get("name", "")
			reward_text += "\n%s 碎片 +%d" % [hero_name, rewards["fragment_count"]]
		_reward_label.text = reward_text
	else:
		_result_label.text = "斗法失败..."
		_result_label.modulate = Color(0.8, 0.2, 0.2)
		AudioManager.play_sfx("defeat")
		_reward_label.text = "再接再厉，修炼提升后再来挑战"


# ========== UI 刷新 ==========

func _refresh_units() -> void:
	# 刷新敌方显示（保留 EnemyTitle）
	if _enemy_container:
		for child in _enemy_container.get_children():
			if child.name != "EnemyTitle":
				child.queue_free()
		for unit in BattleManager.get_enemy_formation():
			_enemy_container.add_child(_create_unit_display(unit, false))

	# 刷新我方显示（保留 PlayerTitle）
	if _player_container:
		for child in _player_container.get_children():
			if child.name != "PlayerTitle":
				child.queue_free()
		for unit in BattleManager.get_player_formation():
			_player_container.add_child(_create_unit_display(unit, true))


func _create_unit_display(unit: Dictionary, is_player: bool) -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()

	# 名称
	var name_label: Label = Label.new()
	name_label.text = _get_display_name(unit.get("id", "???"))
	name_label.add_theme_font_size_override("font_size", 16)
	if is_player:
		name_label.modulate = Color(0.3, 0.7, 0.9)
	else:
		name_label.modulate = Color(0.9, 0.3, 0.3)
	vbox.add_child(name_label)

	# HP 进度条
	var hp_bar: ProgressBar = ProgressBar.new()
	var hp: int = unit.get("hp", 0)
	var max_hp: int = unit.get("max_hp", 1)
	hp_bar.max_value = max(1, max_hp)
	hp_bar.value = hp
	hp_bar.custom_minimum_size = Vector2(200, 20)
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	# HP 文字
	var hp_label: Label = Label.new()
	hp_label.text = "%d / %d" % [hp, max_hp]
	hp_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hp_label)

	# 能量条（仅玩家方显示）
	if is_player:
		var energy_bar: ProgressBar = ProgressBar.new()
		var energy: int = unit.get("energy", 0)
		energy_bar.max_value = 100
		energy_bar.value = energy
		energy_bar.custom_minimum_size = Vector2(200, 12)
		energy_bar.show_percentage = false
		if energy >= 100:
			energy_bar.modulate = Color(1.0, 0.85, 0.2)
		vbox.add_child(energy_bar)

	return vbox


func _get_display_name(unit_id: String) -> String:
	var data: Dictionary = HeroManager.get_hero_data(unit_id)
	if data.has("name"):
		return data["name"]
	# 敌人 ID 格式: enemy_1_0
	if unit_id.begins_with("enemy_"):
		return "敌方"
	return unit_id


# ========== 按钮事件 ==========

func _set_speed(mult: float) -> void:
	BattleManager.set_speed_multiplier(mult)
	AudioManager.play_sfx("button_click")


func _on_skill_pressed() -> void:
	if not _current_hero_id.is_empty():
		AudioManager.play_sfx("button_click")
		BattleManager.use_skill(_current_hero_id)
		_skill_button.disabled = true
		_skill_button.text = "绝学"
		_current_hero_id = ""
		_refresh_units()


func _on_continue_pressed() -> void:
	_disconnect_signals()
	GameManager.go_stage_map()
