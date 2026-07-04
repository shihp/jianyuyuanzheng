# Overview: 仿《剑与远征》修仙放置 RPG — 竞品分析 + PRD

## 完成内容

### 阶段一：竞品分析（2026-07-03）
产品战略团队完成《剑与远征》及同类放置 RPG 的全面竞品分析，三位成员（竞析/数析/瑞思）并行调研后汇总。

### 阶段二：PRD 撰写（2026-07-04）
基于用户确认的关键决策（Godot 4 / 东方修仙 / 考虑商业化 / Java·PHP·JS），三位成员（数析/析客/路径）并行+串行产出完整 MVP 功能规格书。

## 关键产出

### 交付文件
1. **竞品分析报告**: `deliverables/product-strategy/competitive-analysis-afk-arena-2026-07-03.md`
2. **PRD 功能规格书**: `deliverables/product-strategy/prd-afk-xianxia-mvp-2026-07-03.md`
3. **PRD 原始文件**: `docs/PRD_MVP_v1.md`

### 核心发现
- 放置 RPG 全球市场 24 亿美元，CAGR 9.8-12.5%，仍在增长
- 修仙题材在中国市场用户基础强（一念逍遥峰值月流水过亿），天然适配放置 RPG
- Godot 4 移动端必须用 Compatibility 渲染器，商业案例少但技术可行
- 微信小游戏是最现实的分发渠道（社交裂变 + 避开 iOS IAP 难题）

### PRD 关键数据
- **游戏暂定名**：仙途远征
- **P0 需求**：9 个（34 人天）— 闭关收益/斗法/四势力克制/修炼突破/境界渡劫/寻仙/存档/新手引导/资源经济
- **P1 需求**：4 个（13 人天）— 万象阵/机缘礼包/仙途任务/仙铺
- **开发时间线**：中性估算 21 周（5 个月），6 阶段 4 里程碑
- **首发平台**：微信小游戏优先
- **变现模式**：F2P + 激励广告 + 轻度 IAP

## 关键决策（已确认）
1. 引擎：Godot 4（用户选择）
2. 题材：东方修仙
3. 目标：考虑商业化
4. 平台：移动端优先（微信小游戏首发）
5. 编程基础：Java / PHP / JS

## 待用户确认
- Q1：美术风格（Q版卡通 vs 水墨写意 vs 半写实国风）
- Q2：品质阶数（建议 6 阶：凡→灵→玄→地→天→仙）
- Q3：初始修士数量（建议 24 个）
- Q6：开发周期预期（中性 21 周是否可接受）

## 后续事项
- 在 Godot 中 F5 运行测试 Phase 0+1 核心循环
- 测试要点：离线收益弹窗 / 修士升级+突破 / 斗法异步战斗+绝学+加速 / 资源显示
- 有报错截图发给 AI 修复

---

## 阶段三：Godot 项目骨架搭建（2026-07-04）

基于 PRD 9.1 节技术架构方案，搭建完整 Godot 4 项目骨架。所有文件已就绪，用户下载 Godot 后可直接导入运行。

### 产出文件（46 个文件）

| 类别 | 数量 | 说明 |
|------|------|------|
| project.godot | 1 | Compatibility 渲染器 / 1080×1920 竖屏 / 8 个 autoload 注册 |
| .gitignore | 1 | Godot 4 专用 |
| Autoload 单例 | 8 | GameManager / SaveManager / EconomyManager / HeroManager / BattleManager / GachaManager / StageManager / AudioManager |
| 数据模型 | 3 | HeroData / StageData / GachaData |
| 系统逻辑 | 4 | IdleSystem / BattleSystem / FormationSystem / TutorialSystem |
| 工具类 | 2 | JSONLoader / MathUtils |
| JSON 数据表 | 7 | balance / heroes(24个) / stages(10关) / gacha / factions / skills / items |
| 场景文件 | 10 | main / home / battle / gacha / hero_list / hero_detail / stage_map / top_bar / nav_bar |
| 脚本 | 10 | 对应场景的 GDScript |
| 文档 | 2 | SETUP.md（Godot 安装指南）/ GDSCRIPT_GUIDE.md（Java/JS 开发者速查） |

### 骨架特性
- 8 个全局单例覆盖全部 6 大核心系统 + 2 个支撑系统
- 数据驱动设计：所有数值通过 JSON 配置，不改代码可调参
- 24 个初始修士（4 势力 × 6 修士）数据已录入
- 10 个关卡（含 boss 关）数据已录入
- 完整存档/读档系统（JSON 格式，自动存档 + 版本迁移）
- 离线收益计算（12h 上限，灵石 60% / 修为 90% 效率）
- 新手引导框架（6 步骤，进度存档）
- 场景切换框架（7 个场景状态，带 Android 返回键支持）

---

## 阶段四：交互功能实现（2026-07-04）

实现 NavBar 导航、实时闭关收益、寻仙抽卡、修士名册、关卡地图 5 大交互功能。修改 9 个文件。

## 阶段五：MVP Phase 0+1 实现（2026-07-04）

走标准 SOP：架构师设计 → 工程师实现 → 主理人验证。修改/新建 19 个文件，修复 4 个关键 Bug。

### 修复的 Bug
1. 离线收益失效（last_save_time 存储位置错误）
2. 战斗能量永远为 0（缺少 energy 赋值）
3. 战斗同步执行无过程展示（改为 await Timer 异步）
4. 升级/突破成本错误（改为读 balance.json + 增加修为消耗）

### 实现的功能
| P0 需求 | 实现内容 |
|---------|---------|
| P0-07 存档系统 | 30s 自动存档 + save_now 即时存档 + 离线时间戳修复 + 旧存档迁移 |
| P0-01 闭关收益 | 离线收益弹窗（独立 Control 组件）+ 在线实时积累 |
| P0-04 修炼突破 | hero_detail 完整界面：属性/升级(灵石+修为)/突破(灵尘+碎片)/阵容切换 |
| P0-02 斗法系统 | 异步回合制战斗 + 能量/绝学 + 1x/1.5x/2x 加速 + HP/能量进度条 + 势力克制 + 奖励(含碎片) |
| P0-09 资源经济 | 5 种资源显示(灵石/仙玉/修为/灵尘/碎片) + 新玩家 5000 仙玉 |

### 设计文档
- `docs/system_design.md` — 增量架构设计 + 任务分解
- `docs/class-diagram.mermaid` — 类图
- `docs/sequence-diagram.mermaid` — 时序图
