## Main - 游戏入口场景
## 负责初始化、离线收益计算和弹窗展示、场景切换到洞府主界面
extends Control

var _offline_rewards: Dictionary = {}
var _idle_system: IdleSystem = null

func _ready() -> void:
	# 设置全屏适配
	set_anchors_preset(PRESET_FULL_RECT)

	# 播放启动BGM
	AudioManager.play_bgm("menu")

	# 检查是否有存档
	if not SaveManager.has_save():
		print("[Main] 新玩家，初始化游戏数据")
		SaveManager.save_game()

	# 计算离线收益
	_calculate_offline()

	# 如果有离线收益，显示弹窗；否则直接进入洞府
	if _offline_rewards.is_empty():
		_go_home()
	else:
		_show_offline_popup()


## 计算离线收益（Bug 修复: 从 player 段读取 last_save_time）
func _calculate_offline() -> void:
	var player_data: Dictionary = SaveManager.get_data("player")
	var last_time: int = int(player_data.get("last_save_time", Time.get_unix_time_from_system()))

	# 创建 IdleSystem 实例
	_idle_system = IdleSystem.new()
	_idle_system.name = "IdleSystem"
	add_child(_idle_system)

	_offline_rewards = _idle_system.calculate_offline_rewards(last_time)


## 显示离线收益弹窗
func _show_offline_popup() -> void:
	var popup_scene: PackedScene = load("res://scenes/ui/offline_reward_popup.tscn")
	if not popup_scene:
		push_error("[Main] 无法加载离线收益弹窗场景")
		_go_home()
		return

	var popup: Control = popup_scene.instantiate()
	add_child(popup)

	# 传入离线收益数据
	if popup.has_method("setup"):
		popup.setup(_offline_rewards)

	# 连接领取信号
	if popup.has_signal("rewards_collected"):
		popup.rewards_collected.connect(_on_rewards_collected)


## 玩家点击领取后入账
func _on_rewards_collected(rewards: Dictionary) -> void:
	if _idle_system:
		_idle_system.collect_offline_rewards(rewards)
		_idle_system.queue_free()
		_idle_system = null
	SaveManager.save_now()
	_go_home()


## 切换到洞府主界面
func _go_home() -> void:
	if _idle_system:
		_idle_system.queue_free()
		_idle_system = null
	await get_tree().create_timer(0.5).timeout
	AudioManager.play_bgm("home")
	GameManager.change_scene(GameManager.GameState.HOME)
	queue_free()
