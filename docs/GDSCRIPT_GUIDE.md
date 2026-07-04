# GDScript 速查手册（Java/JS 开发者专用）

> 你的编程背景：Java / PHP / JavaScript
> GDScript 语法与 JS 非常接近，上手约 1-2 周

## 1. 核心概念对照表

| Java / JS 概念 | GDScript 对应 | 示例 |
|----------------|---------------|------|
| `class Foo` | `class_name Foo` + `extends Node` | 文件顶部声明 |
| `new Foo()` | `Foo.new()` | 实例化 |
| `import` | `preload()` / `load()` | `var scene = load("res://...")` |
| `extends` | `extends` | 完全相同 |
| `interface` | 无直接对应，用 `class_name` + 鸭子类型 | — |
| `public/private` | `_` 前缀 = 约定私有 | `var _internal` |
| `@Autowired` (Spring) | Autoload 单例 | Project Settings 注册 |
| `EventEmitter` | **Signal** | `signal level_up` |
| `addEventListener` | `signal.connect(callable)` | `hero.level_up.connect(on_level_up)` |
| `emit("event")` | `signal.emit()` | `level_up.emit()` |
| Constructor | `_ready()` | 节点进入场景树时调用 |
| `requestAnimationFrame` | `_process(delta)` | 每帧调用 |
| `setInterval` | `Timer` 节点 | `_timer.timeout.connect(callback)` |
| `Promise` / `async/await` | `await` + 协程 | `await get_tree().create_timer(1.0).timeout` |
| `@Value` (Spring) | `@export` | 暴露到 Godot 编辑器面板 |
| `JSON.parse()` | `JSON.new().parse(str)` | 需要 JSON 实例 |
| `JSON.stringify()` | `JSON.stringify(data)` | 全局函数 |
| `localStorage` | `FileAccess` + `user://` 路径 | `FileAccess.open("user://save.json", WRITE)` |
| `this` | `self`（很少需要） | 默认隐式 |
| `null` | `null` | 完全相同 |
| `typeof` | `typeof()` | 返回 Variant.Type 枚举 |
| `instanceof` | `is` | `if node is Control:` |
| `try/catch` | 无直接对应 | 用 `push_error()` + 返回值处理 |

## 2. 变量与类型

### 声明（强烈建议使用类型标注）

```gdscript
# 无类型（不推荐，但合法）
var name = "张三"

# 有类型（推荐，类似 TypeScript）
var name: String = "张三"
var level: int = 1
var rate: float = 0.5
var is_ready: bool = false
var items: Array[String] = []        # 类型化数组
var config: Dictionary = {}          # 类似 JS object
var hero: HeroData = HeroData.new()  # 自定义类型

# 常量
const MAX_LEVEL: int = 240
const RATES: Array[float] = [0.75, 0.20, 0.045, 0.005]

# 枚举
enum GameState { MENU, HOME, BATTLE, GACHA }
var state: GameState = GameState.HOME
```

### @export（暴露到编辑器，类似 Unity 的 SerializeField）

```gdscript
@export var max_hp: int = 1000
@export var hero_name: String = ""
@export_range(0.0, 1.0) var crit_rate: float = 0.05
@export_enum("正道", "魔道", "妖族", "佛门") var faction: String = "正道"
```

## 3. 函数

```gdscript
# 带类型标注的函数
func calculate_damage(atk: float, defense: float) -> int:
    var damage: float = atk - defense
    return max(0, int(damage))

# 默认参数
func greet(name: String = "道友") -> String:
    return "你好, " + name

# 返回多值（用 Dictionary 或 Array）
func get_stats() -> Dictionary:
    return {"atk": 100, "hp": 1000}

# 协程（类似 async/await）
func delayed_action() -> void:
    await get_tree().create_timer(1.0).timeout
    print("1秒后执行")
```

## 4. 信号系统（最重要！）

```gdscript
# 定义信号
signal level_up(new_level: int)
signal damage_taken(amount: int, is_crit: bool)

# 发射信号
level_up.emit(10)
damage_taken.emit(50, true)

# 连接信号（类似 addEventListener）
hero.level_up.connect(_on_hero_level_up)
hero.damage_taken.connect(_on_damage_taken)

# 信号回调
func _on_hero_level_up(new_level: int) -> void:
    print("升级到 %d!" % new_level)

# 一次性连接
hero.level_up.connect(_on_level_up, CONNECT_ONE_SHOT)

# lambda 表达式
button.pressed.connect(func(): print("按钮被点击"))
```

## 5. 节点树操作（类似 DOM）

```gdscript
# 获取子节点（类似 querySelector）
var label = $VBox/TitleLabel           # 等价于 get_node("VBox/TitleLabel")
var label = %TitleLabel                 # Unique Name（类似 getElementById）

# 动态创建节点
var new_label = Label.new()
new_label.text = "新标签"
add_child(new_label)

# 删除节点
new_label.queue_free()                 # 安全删除（下一帧生效）

# 遍历子节点
for child in get_children():
    print(child.name)

# 查找节点
var player = get_tree().get_first_node_in_group("player")
```

## 6. 场景切换

```gdscript
# 加载并实例化场景
var packed_scene = load("res://scenes/battle/battle.tscn")
var battle_scene = packed_scene.instantiate()
add_child(battle_scene)

# 通过 GameManager 单例切换
GameManager.change_scene(GameManager.GameState.BATTLE)
```

## 7. 数据持久化

```gdscript
# 写文件
var file = FileAccess.open("user://save.json", FileAccess.WRITE)
file.store_string(JSON.stringify(data, "\t"))
file.close()

# 读文件
if FileAccess.file_exists("user://save.json"):
    var file = FileAccess.open("user://save.json", FileAccess.READ)
    var text = file.get_as_text()
    file.close()
    var json = JSON.new()
    json.parse(text)
    var data = json.data
```

## 8. 常见陷阱

### 8.1 缩进必须用 Tab
```gdscript
# 正确
func foo():
	var x = 1    # Tab 缩进

# 错误
func foo():
  var x = 1    # 空格缩进，会报错
```

### 8.2 Array 是引用类型（类似 JS）
```gdscript
var a = [1, 2, 3]
var b = a          # b 和 a 指向同一个 Array
b[0] = 99          # a[0] 也变成 99

# 要复制
var c = a.duplicate()  # 浅拷贝
var d = a.duplicate(true)  # 深拷贝
```

### 8.3 Dictionary 也是引用类型
```gdscript
var d1 = {"key": "value"}
var d2 = d1
d2["key"] = "new"    # d1 也变了
var d3 = d1.duplicate()  # 复制
```

### 8.4 整数除法
```gdscript
var a = 7 / 2        # = 3（整数除法！）
var b = 7.0 / 2.0    # = 3.5
var c = float(7) / 2 # = 3.5
```

### 8.5 字符串格式化
```gdscript
# Python 风格
var msg = "灵石: %d, 仙玉: %d" % [stones, jade]
var pct = "%.1f%%" % (rate * 100)
```

## 9. 调试技巧

```gdscript
# print 到控制台
print("调试信息:", value)
printerr("错误信息")      # 红色输出

# push_error / push_warning（显示在 Godot 的 Errors 面板）
push_error("严重错误: 数据格式不对")
push_warning("警告: 值超出范围")

# 断言
assert(level > 0, "等级必须大于0")
```

## 10. 本项目的代码规范

- **类型标注**：所有变量和函数必须标注类型
- **私有变量**：用 `_` 前缀
- **信号命名**：动词过去式（`level_up` 而非 `level_upped`）
- **文件头注释**：每个 .gd 文件必须有 `##` 开头的文档注释
- **系统间通信**：优先用 Signal，避免直接互相调用
- **数据驱动**：数值配置在 `data/*.json`，不在代码中硬编码
