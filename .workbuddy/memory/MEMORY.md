# 项目记忆

## 项目概述
仿《剑与远征》放置 RPG 游戏开发项目，用户第一个游戏项目，从零开始学习，为原创游戏打基础。

## 关键决策（已确认）
- **引擎**：Godot 4（用户选择，免费开源、2D 原生支持好、包体小）
- **题材**：东方修仙（修仙题材天然适配放置 RPG：修炼=挂机、渡劫=卡关、突破=升品质）
- **目标**：考虑商业化（不只是纯学习）
- **编程基础**：Java / PHP / JS（无游戏开发经验）
- **MVP 范围**：6 大核心系统（离线收益、自动战斗+大招、3-4 阵营克制、英雄升品质、关卡推进、基础抽卡+保底）
- **平台**：移动端优先
- **差异化策略**：修仙题材差异化 + 商业化付费模型 + 优质原创音乐

## 待确认事项
（已全部确认，无待确认项）

## 工作流进度
- [x] 工作流 2：竞品分析（2026-07-03 完成）
- [x] 工作流 1：PRD 撰写（2026-07-04 完成）
- [x] Godot 项目骨架搭建（2026-07-04 完成，46 个文件）
- [x] 交互功能实现（2026-07-04 完成，9 个文件重写：NavBar/实时闭关/抽卡/名册/关卡）
- [x] MVP Phase 0+1 实现（2026-07-04 完成，19 个文件：存档/离线收益弹窗/修士修炼突破/斗法异步战斗/资源经济）
- [x] MVP Phase 2 系统深化（2026-07-04 完成，17 个文件：同势力5人加成/境界渡劫20关/寻仙心愿单+碎片转换+读gacha.json）
- [ ] MVP Phase 2 测试验证（待用户在 Godot 中 F5 运行测试）

## PRD 关键产出
- **游戏暂定名**：仙途远征
- **P0 需求**：9 个（34 人天）— 闭关收益/斗法/四势力克制/修炼突破/境界渡劫/寻仙/存档/新手引导/资源经济
- **P1 需求**：4 个（13 人天）— 万象阵/机缘礼包/仙途任务/仙铺
- **P2 需求**：6 个（42 人天）— 论剑台/宗门/限时秘境/仙友/外观/仙界远征
- **开发时间线**：中性估算 21 周（5 个月），6 阶段 4 里程碑
- **首发平台**：微信小游戏优先
- **变现模式**：F2P + 激励广告 + 轻度 IAP（月卡/首充/机缘礼包）
- **Steam Plan B**：移动端变现不及预期时转为买断制

## PRD 待确认问题（高紧迫度）
- Q1：美术风格（Q版卡通 vs 水墨写意 vs 半写实国风）
- Q2：品质阶数（建议 6 阶：凡→灵→玄→地→天→仙）
- Q3：初始修士数量（建议 24 个 = 4 势力 × 6 修士）
- Q6：开发周期预期（中性 21 周是否可接受）

## 交付物文件
- 竞品分析：`deliverables/product-strategy/competitive-analysis-afk-arena-2026-07-03.md`
- PRD 功能规格书：`deliverables/product-strategy/prd-afk-xianxia-mvp-2026-07-03.md`
- PRD 原始文件（析客产出）：`docs/PRD_MVP_v1.md`
- Godot 安装指南：`docs/SETUP.md`
- GDScript 速查手册（Java/JS 开发者专用）：`docs/GDSCRIPT_GUIDE.md`

## Godot 项目骨架（2026-07-04 搭建）
- project.godot：Compatibility 渲染器 / 1080×1920 竖屏 / 8 autoload 单例
- 8 个 autoload：GameManager / SaveManager / EconomyManager / HeroManager / BattleManager / GachaManager / StageManager / AudioManager
- 3 个数据模型：HeroData / StageData / GachaData（class_name 注册）
- 4 个系统：IdleSystem / BattleSystem / FormationSystem / TutorialSystem
- 2 个工具类：JSONLoader / MathUtils（class_name 注册）
- 7 个 JSON 数据表：balance / heroes(24个) / stages(20关) / gacha / factions / skills / items
- 10 个场景：main / home / battle / gacha / hero_list / hero_detail / stage_map / top_bar / nav_bar
- 数据驱动设计：数值全在 data/*.json，不改代码可调参
- 用户需自行下载 Godot 4.3+，导入 project.godot 即可运行

## Phase 2 增量（2026-07-04 完成）
- 存档格式升级 v1→v2（新增 gacha.wishlist + gacha.active_banner，_migrate_save 自动迁移）
- P0-03 同势力5人加成：BattleManager._apply_faction_bonus() 读 balance.json same_faction_bonus，仅玩家方5人同势力时 atk/hp ×1.25
- P0-05 境界渡劫：stages.json 扩展到20关，渡劫关4/8/12/16/20(is_tribulation=true)，1-12关练气期/13-20关筑基期
- P0-06 寻仙系统：GachaManager 读 gacha.json（移除全部硬编码常量），心愿单(3槽位/SR+/50%概率)，碎片转换(R=10/SR=30/SSR=80/UR=200)，概率公示UI
- 架构设计文档：`docs/system_design_phase2.md` + 2个mermaid图
- 3个轻微观察项（非阻断）：gacha.gd缺_exit_tree/gacha_data类型不兼容/降级查找不过滤rarity
