## Home - 修炼洞府（主界面）
## 显示: 资源栏(灵石/仙玉/修为/灵尘/碎片) / 修士阵容 / 闭关收益 / 导航
extends Control

@onready var _resource_label: Label = $VBox/TopBar/ResourceContainer/ResourceLabel
@onready var _dust_label: Label = $VBox/TopBar/ResourceContainer/DustLabel
@onready var _stage_label: Label = $VBox/TopBar/StageContainer/StageLabel
@onready var _hero_container: VBoxContainer = $VBox/ContentArea/HeroList
@onready var _idle_label: Label = $VBox/ContentArea/IdlePanel/IdleLabel
@onready var _collect_button: Button = $VBox/ContentArea/IdlePanel/CollectButton

var _idle_system: IdleSystem = null
var _refresh_timer: Timer = null

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	AudioManager.play_bgm("home")
	_setup_idle()
	_setup_refresh_timer()
	_refresh_ui()
	_connect_signals()


func _exit_tree() -> void:
	if EconomyManager.resource_changed.is_connected(_on_resource_changed):
		EconomyManager.resource_changed.disconnect(_on_resource_changed)
	if HeroManager.formation_changed.is_connected(_on_formation_changed):
		HeroManager.formation_changed.disconnect(_on_formation_changed)


func _setup_idle() -> void:
	_idle_system = IdleSystem.new()
	_idle_system.name = "IdleSystem"
	add_child(_idle_system)


func _setup_refresh_timer() -> void:
	# 每秒刷新闭关收益显示
	_refresh_timer = Timer.new()
	_refresh_timer.name = "RefreshTimer"
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(_refresh_timer)


func _connect_signals() -> void:
	EconomyManager.resource_changed.connect(_on_resource_changed)
	HeroManager.formation_changed.connect(_on_formation_changed)
	if _collect_button:
		_collect_button.pressed.connect(_on_collect_pressed)


func _refresh_ui() -> void:
	_update_resources()
	_update_hero_list()
	_update_idle_info()


func _update_resources() -> void:
	var stones: int = EconomyManager.get_amount(&"spirit_stones")
	var jade: int = EconomyManager.get_amount(&"jade")
	var exp: int = EconomyManager.get_amount(&"exp")

	if _resource_label:
		_resource_label.text = "灵石: %s  仙玉: %d  修为: %s" % [
			MathUtils.format_big_number(stones), jade, MathUtils.format_big_number(exp)
		]

	# 灵尘和碎片显示
	if _dust_label:
		var dust: int = EconomyManager.get_amount(&"dust")
		var frag_types: int = EconomyManager.get_total_fragment_types()
		var frag_total: int = EconomyManager.get_total_fragments()
		_dust_label.text = "灵尘: %s  碎片: %d种/%d个" % [
			MathUtils.format_big_number(dust), frag_types, frag_total
		]

	if _stage_label:
		var current: int = StageManager.get_current_stage()
		var realm_name: String = StageManager.get_realm_name(current)
		if not realm_name.is_empty():
			_stage_label.text = "%s · 第 %d 关" % [realm_name, current]
		else:
			_stage_label.text = "第 %d 关" % current


func _update_hero_list() -> void:
	if not _hero_container:
		return

	for child in _hero_container.get_children():
		child.queue_free()

	var formation: Array[String] = HeroManager.get_formation()

	# 显示阵容中的修士
	for hero_id in formation:
		var data: Dictionary = HeroManager.get_hero_data(hero_id)
		var label: Label = Label.new()
		label.text = "[%s] %s Lv.%d %s" % [
			HeroManager.get_hero_quality_name(hero_id),
			data.get("name", "???"),
			HeroManager.get_hero_level(hero_id),
			_get_faction_display(data.get("faction", ""))
		]
		label.add_theme_font_size_override("font_size", 18)
		_hero_container.add_child(label)

	# 提示阵容空位
	var empty_slots: int = 5 - formation.size()
	if empty_slots > 0:
		var empty_label: Label = Label.new()
		empty_label.text = "(还有 %d 个空位)" % empty_slots
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		_hero_container.add_child(empty_label)


func _update_idle_info() -> void:
	if _idle_label and _idle_system:
		# 显示实时累计的待领取收益
		var pending: Dictionary = _idle_system.get_pending_rewards()
		var stones: int = int(pending.get("spirit_stones", 0))
		var exp: int = int(pending.get("exp", 0))
		_idle_label.text = "闭关中... 灵石 +%d  修为 +%d" % [stones, exp]


func _get_faction_display(faction: String) -> String:
	match faction:
		"zhengdao": return "正道"
		"modao": return "魔道"
		"yaozu": return "妖族"
		"fomen": return "佛门"
		_: return "???"


func _on_resource_changed(_type: StringName, _new_val: int, _delta: int) -> void:
	_update_resources()


func _on_formation_changed(_formation: Array) -> void:
	_update_hero_list()


func _on_refresh_timer_timeout() -> void:
	_update_idle_info()


func _on_collect_pressed() -> void:
	if not _idle_system:
		return
	# 收取在线累计收益
	var rewards: Dictionary = _idle_system.collect_online_rewards()
	var stones: int = int(rewards.get("spirit_stones", 0))
	var exp: int = int(rewards.get("exp", 0))
	if stones > 0 or exp > 0:
		AudioManager.play_sfx("coin")
		if _idle_label:
			_idle_label.text = "获得 灵石 +%d  修为 +%d" % [stones, exp]
	else:
		if _idle_label:
			_idle_label.text = "暂无收益可领取"
	# 定时器会在 1 秒后刷新显示为当前累计量
