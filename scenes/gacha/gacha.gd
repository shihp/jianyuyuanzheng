## Gacha - 寻仙台（抽卡界面）
## 显示: 仙玉余额 / 保底进度 / 概率公示 / 心愿单 / 抽卡按钮 / 结果列表 / 导航
extends Control

@onready var _jade_label: Label = $VBox/TopBar/JadeLabel
@onready var _pity_label: Label = $VBox/TopBar/PityLabel
@onready var _result_container: VBoxContainer = $VBox/ResultScroll/ResultContainer
@onready var _single_pull_button: Button = $VBox/ButtonBar/SinglePullButton
@onready var _ten_pull_button: Button = $VBox/ButtonBar/TenPullButton
@onready var _hint_label: Label = $VBox/HintLabel

# 动态创建的 UI 元素
var _rates_label: Label = null
var _wishlist_section: VBoxContainer = null
var _wishlist_slots: Array[Label] = []
var _wishlist_edit_button: Button = null
var _hero_select_container: VBoxContainer = null
var _is_editing_wishlist: bool = false

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
	AudioManager.play_bgm("gacha")
	_create_extra_ui()
	_connect_signals()
	_update_info()
	_update_wishlist_display()


## 动态创建概率公示 + 心愿单 UI
func _create_extra_ui() -> void:
	var main_vbox: VBoxContainer = $VBox

	# === 概率公示 ===
	_rates_label = Label.new()
	_rates_label.name = "RatesLabel"
	_rates_label.add_theme_font_size_override("font_size", 14)
	_rates_label.modulate = Color(0.7, 0.7, 0.7)
	main_vbox.add_child(_rates_label)

	# === 心愿单区域 ===
	_wishlist_section = VBoxContainer.new()
	_wishlist_section.name = "WishlistSection"
	main_vbox.add_child(_wishlist_section)

	# 心愿单标题行
	var wl_header: HBoxContainer = HBoxContainer.new()
	var wl_title: Label = Label.new()
	wl_title.text = "心愿单 (SR+可选, 最多3个, 出SR+时50%概率命中)"
	wl_title.add_theme_font_size_override("font_size", 16)
	wl_title.modulate = Color(0.9, 0.8, 0.3)
	wl_header.add_child(wl_title)

	_wishlist_edit_button = Button.new()
	_wishlist_edit_button.text = "编辑"
	_wishlist_edit_button.custom_minimum_size = Vector2(60, 30)
	_wishlist_edit_button.pressed.connect(_on_wishlist_edit_pressed)
	wl_header.add_child(_wishlist_edit_button)
	_wishlist_section.add_child(wl_header)

	# 3个心愿单槽位
	var wl_slots_box: HBoxContainer = HBoxContainer.new()
	for i in range(3):
		var slot_label: Label = Label.new()
		slot_label.text = "[空位]"
		slot_label.add_theme_font_size_override("font_size", 16)
		slot_label.custom_minimum_size = Vector2(150, 24)
		_wishlist_slots.append(slot_label)
		wl_slots_box.add_child(slot_label)
	_wishlist_section.add_child(wl_slots_box)

	# 英雄选择容器（默认隐藏）
	_hero_select_container = VBoxContainer.new()
	_hero_select_container.name = "HeroSelectContainer"
	_hero_select_container.visible = false
	_wishlist_section.add_child(_hero_select_container)


func _connect_signals() -> void:
	if _single_pull_button:
		_single_pull_button.pressed.connect(_on_single_pull_pressed)
	if _ten_pull_button:
		_ten_pull_button.pressed.connect(_on_ten_pull_pressed)
	GachaManager.jade_insufficient.connect(_on_jade_insufficient)
	GachaManager.wishlist_changed.connect(_on_wishlist_changed)
	EconomyManager.resource_changed.connect(_on_resource_changed)


func _update_info() -> void:
	var jade: int = EconomyManager.get_amount(&"jade")
	var pity_remaining: int = GachaManager.get_pity_remaining()
	var total_pulls: int = GachaManager.get_total_pulls()

	if _jade_label:
		_jade_label.text = "仙玉: %d" % jade
	if _pity_label:
		_pity_label.text = "距保底: %d抽 | 总抽: %d" % [pity_remaining, total_pulls]

	# 概率公示
	if _rates_label:
		var rates: Dictionary = GachaManager.get_rates()
		var banner_name: String = GachaManager.get_active_banner_name()
		_rates_label.text = "【%s】概率: R %.1f%% | SR %.1f%% | SSR %.2f%% | UR %.2f%%" % [
			banner_name,
			float(rates.get("R", 0.75)) * 100.0,
			float(rates.get("SR", 0.20)) * 100.0,
			float(rates.get("SSR", 0.045)) * 100.0,
			float(rates.get("UR", 0.005)) * 100.0,
		]

	# 按钮可用性检查（使用 getter 替代常量）
	var single_cost: int = GachaManager.get_single_pull_cost()
	var ten_cost: int = GachaManager.get_ten_pull_cost()
	if _single_pull_button:
		_single_pull_button.disabled = jade < single_cost
	if _ten_pull_button:
		_ten_pull_button.disabled = jade < ten_cost


## 更新心愿单显示
func _update_wishlist_display() -> void:
	var wishlist: Array[String] = GachaManager.get_wishlist()
	for i in range(3):
		if i < wishlist.size():
			var hero_data: Dictionary = HeroManager.get_hero_data(wishlist[i])
			var hero_name: String = hero_data.get("name", "???")
			var rarity: int = int(hero_data.get("rarity", 1))
			var rarity_name: String = _get_rarity_name(rarity)
			_wishlist_slots[i].text = "[%s] %s" % [rarity_name, hero_name]
			_wishlist_slots[i].modulate = _get_rarity_color(rarity)
		else:
			_wishlist_slots[i].text = "[空位]"
			_wishlist_slots[i].modulate = Color(0.5, 0.5, 0.5)


## 切换心愿单编辑模式
func _on_wishlist_edit_pressed() -> void:
	AudioManager.play_sfx("button_click")
	_is_editing_wishlist = not _is_editing_wishlist
	_hero_select_container.visible = _is_editing_wishlist
	_wishlist_edit_button.text = "完成" if _is_editing_wishlist else "编辑"
	if _is_editing_wishlist:
		_populate_hero_select()


## 填充 SR+ 修士选择列表
func _populate_hero_select() -> void:
	# 清空旧内容
	for child in _hero_select_container.get_children():
		child.queue_free()

	var wishlist: Array[String] = GachaManager.get_wishlist()
	var all_heroes: Array = JSONLoader.load_array("res://data/heroes.json")

	# 筛选 SR+ 修士
	for hero in all_heroes:
		var rarity: int = int(hero.get("rarity", 1))
		if rarity < 2:
			continue  # 仅 SR+ 可选

		var hero_id: String = hero.get("id", "")
		var hero_name: String = hero.get("name", "???")
		var rarity_name: String = _get_rarity_name(rarity)

		var hero_btn: Button = Button.new()
		var is_selected: bool = hero_id in wishlist
		hero_btn.text = "[%s] %s%s" % [rarity_name, hero_name, " ✓" if is_selected else ""]
		hero_btn.custom_minimum_size = Vector2(200, 30)
		hero_btn.modulate = _get_rarity_color(rarity)
		hero_btn.pressed.connect(_on_hero_select_pressed.bind(hero_id))
		_hero_select_container.add_child(hero_btn)


## 点击修士选择按钮：添加/移除心愿单
func _on_hero_select_pressed(hero_id: String) -> void:
	AudioManager.play_sfx("button_click")
	var wishlist: Array[String] = GachaManager.get_wishlist()

	if hero_id in wishlist:
		# 已在心愿单 → 移除
		wishlist.erase(hero_id)
		GachaManager.set_wishlist(wishlist)
	else:
		# 不在心愿单 → 添加（如果未满3个）
		if wishlist.size() >= 3:
			if _hint_label:
				_hint_label.text = "心愿单已满（最多3个），请先移除一个"
				_hint_label.modulate = Color(1.0, 0.5, 0.3)
			return
		wishlist.append(hero_id)
		GachaManager.set_wishlist(wishlist)

	# 刷新选择列表
	_populate_hero_select()


func _on_wishlist_changed(_wishlist: Array) -> void:
	_update_wishlist_display()


func _on_single_pull_pressed() -> void:
	AudioManager.play_sfx("button_click")
	var result: Dictionary = GachaManager.single_pull()
	if result.is_empty():
		return  # 仙玉不足，jade_insufficient 信号会处理提示
	AudioManager.play_sfx("pull")
	_display_results([result])
	_update_info()


func _on_ten_pull_pressed() -> void:
	AudioManager.play_sfx("button_click")
	var results: Array = GachaManager.ten_pull()
	if results.is_empty():
		return  # 仙玉不足，jade_insufficient 信号会处理提示
	AudioManager.play_sfx("pull")
	_display_results(results)
	_update_info()


func _on_jade_insufficient(needed: int, current: int) -> void:
	if _hint_label:
		_hint_label.text = "仙玉不足！需要 %d，当前 %d" % [needed, current]
		_hint_label.modulate = Color(1.0, 0.3, 0.3)


func _on_resource_changed(_type: StringName, _new_val: int, _delta: int) -> void:
	_update_info()


func _display_results(results: Array) -> void:
	if not _result_container:
		return

	# 清空旧结果
	for child in _result_container.get_children():
		child.queue_free()

	if results.is_empty():
		return

	var new_count: int = 0
	var frag_total: int = 0
	for result in results:
		var hero_id: String = result.get("hero_id", "")
		var rarity: int = int(result.get("rarity", 1))
		var is_new: bool = bool(result.get("is_new", false))

		if is_new:
			new_count += 1

		var hero_data: Dictionary = HeroManager.get_hero_data(hero_id)
		var hero_name: String = hero_data.get("name", "???")

		var label: Label = Label.new()
		var rarity_name: String = _get_rarity_name(rarity)
		var suffix: String = ""
		if is_new:
			suffix = " [NEW]"
		else:
			var frag_count: int = int(result.get("fragments", 0))
			suffix = " [重复 → 碎片×%d]" % frag_count
			frag_total += frag_count
		label.text = "[%s] %s%s" % [rarity_name, hero_name, suffix]
		label.add_theme_font_size_override("font_size", 22)
		label.modulate = _get_rarity_color(rarity)
		_result_container.add_child(label)

	# 显示获得提示
	if _hint_label:
		if frag_total > 0:
			_hint_label.text = "获得 %d 位修士！（其中 %d 位新修士）| 重复修士转化碎片 ×%d" % [
				results.size(), new_count, frag_total
			]
		else:
			_hint_label.text = "获得 %d 位修士！（其中 %d 位新修士）" % [results.size(), new_count]
		_hint_label.modulate = Color(0.3, 1.0, 0.3)


func _get_rarity_name(rarity: int) -> String:
	if rarity >= 0 and rarity < RARITY_NAMES.size():
		return RARITY_NAMES[rarity]
	return "R"


func _get_rarity_color(rarity: int) -> Color:
	if rarity >= 0 and rarity < RARITY_COLORS.size():
		return RARITY_COLORS[rarity]
	return Color.WHITE
