## NavBar - 底部导航栏
## 按钮: 洞府 / 斗法 / 寻仙 / 修士
extends Control

func _ready() -> void:
	set_anchors_preset(PRESET_BOTTOM_WIDE)


func _on_home_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_home()


func _on_battle_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_stage_map()


func _on_gacha_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_gacha()


func _on_hero_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_hero_list()
