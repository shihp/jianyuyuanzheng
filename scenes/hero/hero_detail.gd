## HeroDetail - 修士详情界面
## 显示: 修士信息 / 属性面板 / 升级 / 突破 / 阵容切换 / 导航
extends Control

var _hero_id: String = ""

# UI 引用
var _name_label: Label = null
var _sub_info_label: Label = null
var _hp_label: Label = null
var _atk_label: Label = null
var _spd_label: Label = null
var _crit_rate_label: Label = null
var _crit_dmg_label: Label = null
var _level_label: Label = null
var _level_cost_label: Label = null
var _level_up_button: Button = null
var _quality_name_label: Label = null
var _fragment_label: Label = null
var _quality_cost_label: Label = null
var _quality_up_button: Button = null
var _formation_button: Button = null

# 品质名称
const RARITY_NAMES: Array[String] = ["", "R", "SR", "SSR", "UR"]
const RARITY_COLORS: Array[Color] = [
	Color.WHITE,
	Color(0.6, 0.6, 0.6),    # R  - 灰色
	Color(0.3, 0.5, 1.0),    # SR - 蓝色
	Color(0.7, 0.3, 1.0),    # SSR- 紫色
	Color(1.0, 0.8, 0.2),    # UR - 金色
]


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_hero_id = GameManager.selected_hero_id
	if _hero_id.is_empty():
		push_error("[HeroDetail] 未设置 selected_hero_id")
		GameManager.go_hero_list()
		return

	_build_ui()
	_refresh_ui()

	# 连接信号
	HeroManager.hero_leveled_up.connect(_on_hero_changed)
	HeroManager.hero_quality_up.connect(_on_hero_changed)
	EconomyManager.resource_changed.connect(_on_resource_changed)
	HeroManager.formation_changed.connect(_on_formation_changed)


func _exit_tree() -> void:
	if HeroManager.hero_leveled_up.is_connected(_on_hero_changed):
		HeroManager.hero_leveled_up.disconnect(_on_hero_changed)
	if HeroManager.hero_quality_up.is_connected(_on_hero_changed):
		HeroManager.hero_quality_up.disconnect(_on_hero_changed)
	if EconomyManager.resource_changed.is_connected(_on_resource_changed):
		EconomyManager.resource_changed.disconnect(_on_resource_changed)
	if HeroManager.formation_changed.is_connected(_on_formation_changed):
		HeroManager.formation_changed.disconnect(_on_formation_changed)


# ========== UI 构建 ==========

func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1, 1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 主容器
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10.0
	vbox.offset_top = 10.0
	vbox.offset_right = -10.0
	vbox.offset_bottom = -70.0
	add_child(vbox)

	# 标题
	var title: Label = _make_label("修士详情", 26, Color(0.9, 0.85, 0.5))
	vbox.add_child(title)

	# 修士名称
	_name_label = _make_label("", 24, Color.WHITE)
	vbox.add_child(_name_label)

	# 副信息（势力 + 称号）
	_sub_info_label = _make_label("", 18, Color(0.7, 0.7, 0.75))
	vbox.add_child(_sub_info_label)

	# 滚动区域
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# --- 属性面板 ---
	content.add_child(_make_section_title("属性"))
	var stats_panel: PanelContainer = _make_panel()
	var stats_vbox: VBoxContainer = _make_panel_vbox(stats_panel)
	_hp_label = _make_label("", 18, Color(0.9, 0.4, 0.4))
	_atk_label = _make_label("", 18, Color(1.0, 0.6, 0.3))
	_spd_label = _make_label("", 18, Color(0.4, 0.9, 0.6))
	_crit_rate_label = _make_label("", 18, Color(0.8, 0.6, 1.0))
	_crit_dmg_label = _make_label("", 18, Color(0.8, 0.6, 1.0))
	stats_vbox.add_child(_hp_label)
	stats_vbox.add_child(_atk_label)
	stats_vbox.add_child(_spd_label)
	stats_vbox.add_child(_crit_rate_label)
	stats_vbox.add_child(_crit_dmg_label)
	content.add_child(stats_panel)

	# --- 升级区域 ---
	content.add_child(_make_section_title("修炼"))
	var level_panel: PanelContainer = _make_panel()
	var level_vbox: VBoxContainer = _make_panel_vbox(level_panel)
	_level_label = _make_label("", 20, Color(0.9, 0.85, 0.5))
	_level_cost_label = _make_label("", 16, Color(0.7, 0.7, 0.7))
	_level_up_button = Button.new()
	_level_up_button.text = "修炼"
	_level_up_button.custom_minimum_size = Vector2(0, 50)
	_level_up_button.add_theme_font_size_override("font_size", 22)
	_level_up_button.pressed.connect(_on_level_up_pressed)
	level_vbox.add_child(_level_label)
	level_vbox.add_child(_level_cost_label)
	level_vbox.add_child(_level_up_button)
	content.add_child(level_panel)

	# --- 突破区域 ---
	content.add_child(_make_section_title("突破"))
	var quality_panel: PanelContainer = _make_panel()
	var quality_vbox: VBoxContainer = _make_panel_vbox(quality_panel)
	_quality_name_label = _make_label("", 20, Color(0.9, 0.85, 0.5))
	_fragment_label = _make_label("", 16, Color(0.7, 0.7, 0.7))
	_quality_cost_label = _make_label("", 16, Color(0.7, 0.7, 0.7))
	_quality_up_button = Button.new()
	_quality_up_button.text = "突破"
	_quality_up_button.custom_minimum_size = Vector2(0, 50)
	_quality_up_button.add_theme_font_size_override("font_size", 22)
	_quality_up_button.pressed.connect(_on_quality_up_pressed)
	quality_vbox.add_child(_quality_name_label)
	quality_vbox.add_child(_fragment_label)
	quality_vbox.add_child(_quality_cost_label)
	quality_vbox.add_child(_quality_up_button)
	content.add_child(quality_panel)

	# --- 阵容按钮 ---
	_formation_button = Button.new()
	_formation_button.text = "加入阵容"
	_formation_button.custom_minimum_size = Vector2(0, 50)
	_formation_button.add_theme_font_size_override("font_size", 20)
	_formation_button.pressed.connect(_on_formation_pressed)
	content.add_child(_formation_button)

	# 返回按钮
	var back_btn: Button = Button.new()
	back_btn.text = "返回名册"
	back_btn.custom_minimum_size = Vector2(0, 50)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): GameManager.go_hero_list())
	content.add_child(back_btn)

	# NavBar
	var nav_scene: PackedScene = load("res://scenes/ui/nav_bar.tscn")
	if nav_scene:
		var nav: Control = nav_scene.instantiate()
		nav.offset_top = -60.0
		add_child(nav)


# ========== UI 刷新 ==========

func _refresh_ui() -> void:
	if not HeroManager.is_owned(_hero_id):
		return

	var data: Dictionary = HeroManager.get_hero_data(_hero_id)
	var hero_name: String = data.get("name", "???")
	var title: String = data.get("title", "")
	var rarity: int = HeroManager.get_hero_rarity(_hero_id)
	var quality_name: String = HeroManager.get_hero_quality_name(_hero_id)
	var faction: String = _get_faction_display(HeroManager.get_hero_faction(_hero_id))
	var level: int = HeroManager.get_hero_level(_hero_id)
	var stats: Dictionary = HeroManager.get_hero_stats(_hero_id)

	# 名称行
	var rarity_str: String = _get_rarity_name(rarity)
	if _name_label:
		_name_label.text = "[%s] [%s] %s  Lv.%d" % [rarity_str, quality_name, hero_name, level]
		_name_label.modulate = _get_rarity_color(rarity)

	# 副信息
	if _sub_info_label:
		_sub_info_label.text = "%s  「%s」" % [faction, title]

	# 属性
	if _hp_label:
		_hp_label.text = "生命: %s" % MathUtils.format_big_number(stats.hp)
	if _atk_label:
		_atk_label.text = "攻击: %d" % stats.atk
	if _spd_label:
		_spd_label.text = "速度: %d" % stats.speed
	if _crit_rate_label:
		_crit_rate_label.text = "暴击率: %s" % MathUtils.format_percent(stats.crit_rate)
	if _crit_dmg_label:
		_crit_dmg_label.text = "暴击伤害: %s" % MathUtils.format_percent(stats.crit_dmg)

	# 升级区域
	var max_level: int = HeroManager.get_max_level()
	var level_cost: Dictionary = HeroManager.get_level_up_cost(_hero_id)
	if _level_label:
		if level >= max_level:
			_level_label.text = "等级: %d / %d (已满级)" % [level, max_level]
		else:
			_level_label.text = "等级: %d / %d" % [level, max_level]
	if _level_cost_label:
		if level >= max_level:
			_level_cost_label.text = "已达最高等级"
		else:
			_level_cost_label.text = "消耗: 灵石 %s + 修为 %s" % [
				MathUtils.format_big_number(level_cost.spirit_stones),
				MathUtils.format_big_number(level_cost.exp)
			]
	if _level_up_button:
		_level_up_button.disabled = not HeroManager.can_level_up(_hero_id)
		_level_up_button.text = "修炼" if level < max_level else "已满级"

	# 突破区域
	var quality: int = HeroManager.get_hero_quality(_hero_id)
	var quality_cost: Dictionary = HeroManager.get_quality_up_cost(_hero_id)
	var fragment_count: int = EconomyManager.get_fragments(_hero_id)
	if _quality_name_label:
		if quality >= HeroManager.QUALITY_NAMES.size() - 1:
			_quality_name_label.text = "品质: %s (已满品)" % quality_name
		else:
			_quality_name_label.text = "品质: %s → %s" % [quality_name, HeroManager.QUALITY_NAMES[quality + 1]]
	if _fragment_label:
		_quality_up_button.text = "突破"
		_fragment_label.text = "持有碎片: %d" % fragment_count
	if _quality_cost_label:
		if quality >= HeroManager.QUALITY_NAMES.size() - 1:
			_quality_cost_label.text = "已达最高品质"
		else:
			_quality_cost_label.text = "消耗: 灵尘 %d + 碎片 %d" % [quality_cost.dust, quality_cost.fragments]
	if _quality_up_button:
		_quality_up_button.disabled = not HeroManager.can_quality_up(_hero_id)
		if quality >= HeroManager.QUALITY_NAMES.size() - 1:
			_quality_up_button.text = "已满品"

	# 阵容按钮
	if _formation_button:
		if HeroManager.is_in_formation(_hero_id):
			_formation_button.text = "移出阵容"
		else:
			_formation_button.text = "加入阵容"
		_formation_button.disabled = false


# ========== 事件回调 ==========

func _on_hero_changed(_hero_id_changed: String, _new_val: int) -> void:
	_refresh_ui()


func _on_resource_changed(_type: StringName, _new_val: int, _delta: int) -> void:
	_refresh_ui()


func _on_formation_changed(_formation: Array) -> void:
	_refresh_ui()


func _on_level_up_pressed() -> void:
	AudioManager.play_sfx("button_click")
	if HeroManager.level_up(_hero_id):
		AudioManager.play_sfx("coin")
	_refresh_ui()


func _on_quality_up_pressed() -> void:
	AudioManager.play_sfx("button_click")
	if HeroManager.quality_up(_hero_id):
		AudioManager.play_sfx("coin")
	_refresh_ui()


func _on_formation_pressed() -> void:
	AudioManager.play_sfx("button_click")
	if HeroManager.is_in_formation(_hero_id):
		HeroManager.remove_from_formation(_hero_id)
	else:
		if not HeroManager.add_to_formation(_hero_id):
			# 阵容已满
			if _formation_button:
				_formation_button.text = "阵容已满(最多5人)"
				await get_tree().create_timer(1.5).timeout
	_refresh_ui()

# ========== 工具方法 ==========

func _get_faction_display(faction: String) -> String:
	match faction:
		"zhengdao": return "正道"
		"modao": return "魔道"
		"yaozu": return "妖族"
		"fomen": return "佛门"
		_: return "未知"


func _get_rarity_name(rarity: int) -> String:
	if rarity >= 0 and rarity < RARITY_NAMES.size():
		return RARITY_NAMES[rarity]
	return "R"


func _get_rarity_color(rarity: int) -> Color:
	if rarity >= 0 and rarity < RARITY_COLORS.size():
		return RARITY_COLORS[rarity]
	return Color.WHITE


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


func _make_section_title(text: String) -> Label:
	return _make_label(text, 22, Color(0.9, 0.85, 0.5))


func _make_panel() -> PanelContainer:
	# PanelContainer auto-sizes to fit children + draws panel background
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_constant_override("margin_left", 15)
	panel.add_theme_constant_override("margin_top", 10)
	panel.add_theme_constant_override("margin_right", 15)
	panel.add_theme_constant_override("margin_bottom", 10)
	return panel


func _make_panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	return vbox
