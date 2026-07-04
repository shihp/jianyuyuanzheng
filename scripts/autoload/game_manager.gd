## GameManager - 游戏状态机 + 场景切换
## 对应 Java Spring 的 Application 主控 / JS 的 window.app 路由
##
## 职责:
##   - 管理游戏全局状态 (菜单/洞府/斗法/寻仙/修士/关卡)
##   - 场景切换 (带过渡动画)
##   - 游戏生命周期 (启动/暂停/恢复/退出)
extends Node

# ========== 信号 ==========

signal scene_changed(scene_name: StringName)
signal game_paused()
signal game_resumed()
signal back_to_home()

# ========== 枚举 ==========

enum GameState {
	MENU,        # 启动菜单
	HOME,        # 修炼洞府（主界面）
	BATTLE,      # 斗法场景
	GACHA,       # 寻仙抽卡
	HERO_LIST,   # 修士列表
	HERO_DETAIL, # 修士详情
	STAGE_MAP,   # 关卡地图
}

# ========== 常量 ==========

const SCENE_PATHS: Dictionary = {
	GameState.MENU: "res://scenes/main/main.tscn",
	GameState.HOME: "res://scenes/home/home.tscn",
	GameState.BATTLE: "res://scenes/battle/battle.tscn",
	GameState.GACHA: "res://scenes/gacha/gacha.tscn",
	GameState.HERO_LIST: "res://scenes/hero/hero_list.tscn",
	GameState.HERO_DETAIL: "res://scenes/hero/hero_detail.tscn",
	GameState.STAGE_MAP: "res://scenes/stage/stage_map.tscn",
}

# ========== 状态 ==========

var current_state: GameState = GameState.MENU
var previous_state: GameState = GameState.MENU
var _scene_container: Control = null

## 当前选中的修士ID（hero_list → hero_detail 传参用）
var selected_hero_id: String = ""

# ========== 生命周期 ==========

func _ready() -> void:
	# 监听应用前后台切换（移动端关键）
	_update_scene_container()


func _notification(what: int) -> void:
	# 移动端后台/前台切换
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android 返回键
			if current_state != GameState.HOME:
				change_scene(GameState.HOME)
		NOTIFICATION_APPLICATION_PAUSED:
			# 进入后台 → 立即存档
			if SaveManager:
				SaveManager.save_game()
			game_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			# 恢复前台 → 计算离线收益
			game_resumed.emit()

# ========== 场景切换 ==========

func change_scene(new_state: GameState) -> void:
	if new_state == current_state and _scene_container.get_child_count() > 0:
		return

	if not SCENE_PATHS.has(new_state):
		push_error("[GameManager] 未知的场景状态: %d" % new_state)
		return

	var scene_path: String = SCENE_PATHS[new_state]
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_error("[GameManager] 无法加载场景: %s" % scene_path)
		return

	# 清除当前场景
	if _scene_container:
		for child in _scene_container.get_children():
			child.queue_free()

	# 实例化新场景
	var new_scene: Node = packed_scene.instantiate()
	if _scene_container:
		_scene_container.add_child(new_scene)

	previous_state = current_state
	current_state = new_state
	scene_changed.emit(StringName(GameState.keys()[new_state]))

	print("[GameManager] 场景切换 → %s" % GameState.keys()[new_state])


func go_home() -> void:
	change_scene(GameState.HOME)


func go_battle() -> void:
	change_scene(GameState.BATTLE)


func go_gacha() -> void:
	change_scene(GameState.GACHA)


func go_hero_list() -> void:
	change_scene(GameState.HERO_LIST)


func go_stage_map() -> void:
	change_scene(GameState.STAGE_MAP)

# ========== 内部方法 ==========

func _update_scene_container() -> void:
	# 查找或创建场景容器
	if not _scene_container:
		_scene_container = Control.new()
		_scene_container.name = "SceneContainer"
		_scene_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_scene_container)
