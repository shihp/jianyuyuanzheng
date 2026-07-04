# 仙途远征 - Godot 项目搭建指南

## 1. 下载安装 Godot 4

### 方式一：官网下载（推荐）
1. 访问 https://godotengine.org/download
2. 下载 **Godot 4.3+** Windows 版（Standard 版本即可）
3. 解压到任意目录，例如 `D:\Godot\godot.exe`
4. 无需安装，直接运行

### 方式二：Steam
- Steam 搜索 "Godot Engine"，免费安装

### 方式三：命令行（Scoop）
```
scoop install godot
```

## 2. 打开项目

1. 运行 Godot
2. 选择 **Import**（导入）
3. 浏览选择 `D:\01GAME\DEMO1\project.godot`
4. 点击 **Import & Edit**

## 3. 项目配置检查

打开后请检查以下设置（应已预配置好）：

### 渲染器
- `Project → Project Settings → Rendering`
- `renderer/rendering_method` = `gl_compatibility` ✓
- `renderer/rendering_method.mobile` = `gl_compatibility` ✓

### 窗口尺寸
- `Project → Project Settings → Display`
- `window/size/viewport_width` = `1080` ✓
- `window/size/viewport_height` = `1920` ✓
- `window/stretch/mode` = `canvas_items` ✓
- `window/stretch/aspect` = `keep` ✓

### Autoload 单例
- `Project → Project Settings → Autoload`
- 应有 8 个已注册单例：
  - GameManager, SaveManager, EconomyManager, HeroManager
  - BattleManager, GachaManager, StageManager, AudioManager

## 4. 运行项目

按 **F5**（或点击右上角 ▶ 播放按钮）

首次运行会弹出选择主场景的对话框，选择 `scenes/main/main.tscn`

预期行为：
1. 显示黑屏 + "仙途远征 载入中..." 文字
2. 0.5 秒后自动切换到洞府主界面
3. 显示资源栏（灵石: 0, 仙玉: 0, 修为: 0）
4. 显示初始修士 "李寒山"
5. 显示"闭关中..."提示和"收取闭关收益"按钮

## 5. Git 版本控制（可选）

```bash
cd D:/01GAME/DEMO1
git init
git add .
git commit -m "初始化 Godot 项目骨架"
```

## 6. 目录结构总览

```
res://
├── project.godot          ← Godot 项目配置
├── .gitignore
├── scenes/                ← 场景文件
│   ├── main/              ← 入口场景
│   ├── home/              ← 修炼洞府（主界面）
│   ├── battle/            ← 斗法场景
│   ├── gacha/             ← 寻仙抽卡
│   ├── hero/              ← 修士列表/详情
│   ├── stage/             ← 关卡地图
│   └── ui/                ← UI 组件
├── scripts/               ← GDScript 脚本
│   ├── autoload/          ← 8 个全局单例
│   ├── data/              ← 数据模型类
│   ├── systems/           ← 游戏系统逻辑
│   └── utils/             ← 工具类
├── data/                  ← JSON 配置数据表
│   ├── balance.json       ← 数值平衡配置
│   ├── heroes.json        ← 24 个修士数据
│   ├── stages.json        ← 10 个关卡数据
│   ├── gacha.json         ← 抽卡配置
│   ├── factions.json      ← 4 势力配置
│   ├── skills.json        ← 绝学数据
│   └── items.json         ← 道具数据
├── assets/                ← 美术/音频资源（待填充）
│   ├── sprites/
│   ├── audio/
│   ├── fonts/
│   └── shaders/
└── plugins/               ← 插件目录（Phase 5 商业化）
```

## 7. 下一步开发

按 PRD 路线图，Phase 0 的目标是：

| 序号 | 任务 | 对应 PRD 需求 | 预计工作量 |
|------|------|-------------|-----------|
| 1 | 验证 Godot 移动端 APK 导出 | 技术验证 | 1 天 |
| 2 | 完善 P0-09 资源经济系统 | P0-09 | 2 天 |
| 3 | 完善 P0-07 存档系统 | P0-07 | 3 天 |
| 4 | 完成 "Dodge the Creeps" 官方教程 | 学习 | 3 天 |
