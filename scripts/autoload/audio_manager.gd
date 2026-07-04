## AudioManager - BGM / SFX 播放控制
## 对应 Java 的 AudioService / JS 的 Web Audio API 封装
##
## 职责:
##   - BGM 播放/切换/淡入淡出
##   - SFX 音效播放
##   - 音量控制 (从存档读取设置)
extends Node

# ========== 信号 ==========

signal bgm_changed(track_name: String)
signal volume_changed(channel: StringName, value: float)

# ========== 常量 ==========

const BGM_PATHS: Dictionary = {
	"home": "res://assets/audio/bgm/home.ogg",
	"battle": "res://assets/audio/bgm/battle.ogg",
	"gacha": "res://assets/audio/bgm/gacha.ogg",
	"menu": "res://assets/audio/bgm/menu.ogg",
}

const SFX_PATHS: Dictionary = {
	"button_click": "res://assets/audio/sfx/button_click.ogg",
	"level_up": "res://assets/audio/sfx/level_up.ogg",
	"pull": "res://assets/audio/sfx/pull.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
	"coin": "res://assets/audio/sfx/coin.ogg",
}

const FADE_DURATION: float = 0.5

# ========== 状态 ==========

var _bgm_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null
var _bgm_volume: float = 0.8
var _sfx_volume: float = 1.0
var _current_bgm: String = ""
var _bgm_tween: Tween = null

# ========== 生命周期 ==========

func _ready() -> void:
	# 创建音频播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	# 从存档加载音量设置
	var settings: Dictionary = SaveManager.get_data("settings")
	_bgm_volume = settings.get("bgm_volume", 0.8)
	_sfx_volume = settings.get("sfx_volume", 1.0)
	_apply_volumes()

	SaveManager.load_completed.connect(_on_load_completed)

# ========== 公开接口 - BGM ==========

func play_bgm(track_name: String) -> void:
	if track_name == _current_bgm:
		return

	if not BGM_PATHS.has(track_name):
		push_warning("[AudioManager] 未知BGM: %s" % track_name)
		return

	# 淡出当前BGM
	if _bgm_player.playing:
		_fade_out_and_switch(BGM_PATHS[track_name], track_name)
	else:
		_load_and_play_bgm(BGM_PATHS[track_name], track_name)


func stop_bgm() -> void:
	if _bgm_player.playing:
		_fade_out_bgm()
	_current_bgm = ""


func get_current_bgm() -> String:
	return _current_bgm

# ========== 公开接口 - SFX ==========

func play_sfx(sfx_name: String) -> void:
	if not SFX_PATHS.has(sfx_name):
		push_warning("[AudioManager] 未知SFX: %s" % sfx_name)
		return

	var path: String = SFX_PATHS[sfx_name]
	if not ResourceLoader.exists(path):
		# 音频文件尚未导入，静默跳过
		return

	var stream: AudioStream = load(path)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.play()

# ========== 公开接口 - 音量 ==========

func set_bgm_volume(value: float) -> void:
	_bgm_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_persist_settings()
	volume_changed.emit(&"bgm", _bgm_volume)


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_persist_settings()
	volume_changed.emit(&"sfx", _sfx_volume)


func get_bgm_volume() -> float:
	return _bgm_volume


func get_sfx_volume() -> float:
	return _sfx_volume

# ========== 内部方法 ==========

func _load_and_play_bgm(path: String, track_name: String) -> void:
	if not ResourceLoader.exists(path):
		print("[AudioManager] BGM文件不存在: %s" % path)
		return

	var stream: AudioStream = load(path)
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(_bgm_volume)
	_bgm_player.play()
	_current_bgm = track_name
	bgm_changed.emit(track_name)


func _fade_out_and_switch(new_path: String, new_name: String) -> void:
	if _bgm_tween:
		_bgm_tween.kill()

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, FADE_DURATION)
	_bgm_tween.tween_callback(func():
		_load_and_play_bgm(new_path, new_name)
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", linear_to_db(_bgm_volume), FADE_DURATION)
	)


func _fade_out_bgm() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, FADE_DURATION)
	_bgm_tween.tween_callback(_bgm_player.stop)


func _apply_volumes() -> void:
	_bgm_player.volume_db = linear_to_db(_bgm_volume)
	_sfx_player.volume_db = linear_to_db(_sfx_volume)


func _on_load_completed(save_data: Dictionary) -> void:
	var settings: Dictionary = save_data.get("settings", {})
	_bgm_volume = settings.get("bgm_volume", 0.8)
	_sfx_volume = settings.get("sfx_volume", 1.0)
	_apply_volumes()


func _persist_settings() -> void:
	SaveManager.set_data("settings", {
		"bgm_volume": _bgm_volume,
		"sfx_volume": _sfx_volume,
		"language": "zh",
	})
	SaveManager.mark_dirty()
