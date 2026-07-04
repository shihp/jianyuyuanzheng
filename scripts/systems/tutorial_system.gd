## TutorialSystem - 新手引导系统
## 对应 Java 的 OnboardingService / JS 的 tour.js
##
## 职责:
##   - 新手引导步骤管理
##   - 引导触发与完成判定
##   - 引导进度存档
class_name TutorialSystem
extends Node

# ========== 信号 ==========

signal tutorial_step_started(step_id: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_finished()

# ========== 常量 ==========

const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"id": "welcome",
		"title": "欢迎来到仙途",
		"description": "你将开始修仙之路，先看看你的洞府吧",
		"target_scene": "home",
		"trigger": "auto",
	},
	{
		"id": "first_hero",
		"title": "初始修士",
		"description": "这是你的第一位修士，点击查看详情",
		"target_scene": "home",
		"trigger": "tap_hero",
	},
	{
		"id": "first_battle",
		"title": "首次斗法",
		"description": "前往关卡，开始你的第一场斗法",
		"target_scene": "stage_map",
		"trigger": "enter_stage",
	},
	{
		"id": "first_idle",
		"title": "闭关修炼",
		"description": "即使离线，你的修士也会持续修炼获得资源",
		"target_scene": "home",
		"trigger": "auto",
	},
	{
		"id": "first_gacha",
		"title": "寻仙招募",
		"description": "用仙玉寻仙，获取更多修士",
		"target_scene": "gacha",
		"trigger": "tap_gacha",
	},
	{
		"id": "first_levelup",
		"title": "修士升级",
		"description": "消耗灵石提升修士等级",
		"target_scene": "hero_detail",
		"trigger": "level_up",
	},
]

# ========== 状态 ==========

var _current_step_index: int = 0
var _completed_steps: Array[String] = []
var _is_active: bool = false

# ========== 生命周期 ==========

func _ready() -> void:
	SaveManager.load_completed.connect(_on_load_completed)

# ========== 公开接口 ==========

func start_tutorial() -> void:
	_is_active = true
	_current_step_index = 0
	_show_current_step()


func is_active() -> bool:
	return _is_active


func get_current_step() -> Dictionary:
	if _current_step_index < TUTORIAL_STEPS.size():
		return TUTORIAL_STEPS[_current_step_index]
	return {}


func complete_step(step_id: String) -> void:
	if step_id not in _completed_steps:
		_completed_steps.append(step_id)
	tutorial_step_completed.emit(step_id)

	_current_step_index += 1
	if _current_step_index >= TUTORIAL_STEPS.size():
		_is_active = false
		tutorial_finished.emit()
		print("[TutorialSystem] 新手引导完成")
	else:
		_show_current_step()

	_persist()


func skip_tutorial() -> void:
	_is_active = false
	for step in TUTORIAL_STEPS:
		if step.id not in _completed_steps:
			_completed_steps.append(step.id)
	tutorial_finished.emit()
	_persist()


func is_step_completed(step_id: String) -> bool:
	return step_id in _completed_steps


func get_progress() -> float:
	return float(_completed_steps.size()) / float(TUTORIAL_STEPS.size())

# ========== 内部方法 ==========

func _show_current_step() -> void:
	if _current_step_index >= TUTORIAL_STEPS.size():
		return
	var step: Dictionary = TUTORIAL_STEPS[_current_step_index]
	tutorial_step_started.emit(step.id)
	print("[TutorialSystem] 引导步骤: %s - %s" % [step.title, step.description])


func _on_load_completed(save_data: Dictionary) -> void:
	var settings: Dictionary = save_data.get("settings", {})
	var raw_steps: Array = settings.get("tutorial_completed", [])
	_completed_steps.clear()
	_completed_steps.assign(raw_steps)
	if _completed_steps.size() < TUTORIAL_STEPS.size():
		_current_step_index = _completed_steps.size()
		_is_active = true
	else:
		_is_active = false


func _persist() -> void:
	var settings: Dictionary = SaveManager.get_data("settings")
	settings["tutorial_completed"] = _completed_steps.duplicate()
	SaveManager.set_data("settings", settings)
	SaveManager.mark_dirty()
