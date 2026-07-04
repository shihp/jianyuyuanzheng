## HeroList - 修士名册
## 显示: 所有已拥有修士列表 / 品质颜色区分 / 点击进入详情 / 导航
extends Control

@onready var _hero_container: VBoxContainer = $VBox/ScrollContainer/HeroContainer

# 品质名称: 索引 0 不使用, 1=R, 2=SR, 3=SSR, 4=UR
const RARITY_NAMES: Array[String] = ["", "R", "SR", "SSR", "UR"]

# 品质颜色: R=灰色, SR=蓝色, SSR=紫色, UR=金色
const RARITY_COLORS: Array[Color] = [
	Color.WHITE,
	Color(0.6, 0.6, 0.6),    # R  - 灰色
	Color(0.3, 0.5, 1.0),    # SR - 蓝色
	Color(0.7, 0.3, 1.0),    # SSR- 紫色
	Color(1.0, 0.8, 0.2),    # UR - 金色
]


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_populate_hero_list()
	# 监听修士获取信号，自动刷新
	HeroManager.hero_acquired.connect(_on_hero_acquired)


func _exit_tree() -> void:
	if HeroManager.hero_acquired.is_connected(_on_hero_acquired):
		HeroManager.hero_acquired.disconnect(_on_hero_acquired)


func _populate_hero_list() -> void:
	if not _hero_container:
		return

	# 清空旧内容
	for child in _hero_container.get_children():
		child.queue_free()

	var heroes: Array[String] = HeroManager.get_owned_heroes()

	if heroes.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "暂无修士，请前往寻仙台招募"
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		empty_label.add_theme_font_size_override("font_size", 20)
		_hero_container.add_child(empty_label)
		return

	for hero_id in heroes:
		var data: Dictionary = HeroManager.get_hero_data(hero_id)
		var hero_name: String = data.get("name", "???")
		var title: String = data.get("title", "")
		var rarity: int = HeroManager.get_hero_rarity(hero_id)
		var level: int = HeroManager.get_hero_level(hero_id)
		var quality_name: String = HeroManager.get_hero_quality_name(hero_id)
		var faction: String = _get_faction_display(HeroManager.get_hero_faction(hero_id))
		var in_formation: bool = HeroManager.is_in_formation(hero_id)

		# 创建可点击的 Button 条目
		var btn: Button = Button.new()
		var formation_tag: String = " [阵容]" if in_formation else ""
		btn.text = "[%s] [%s] %s 「%s」 Lv.%d %s%s" % [
			_get_rarity_name(rarity), quality_name, hero_name, title, level, faction, formation_tag
		]
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(0, 55)
		btn.modulate = _get_rarity_color(rarity)
		# 通过闭包传递 hero_id
		btn.pressed.connect(_on_hero_item_pressed.bind(hero_id))
		_hero_container.add_child(btn)


func _on_hero_item_pressed(hero_id: String) -> void:
	AudioManager.play_sfx("button_click")
	# 设置选中的修士ID，供 hero_detail 读取
	GameManager.selected_hero_id = hero_id
	GameManager.change_scene(GameManager.GameState.HERO_DETAIL)


func _on_hero_acquired(_hero_id: String) -> void:
	_populate_hero_list()


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
