# AGENTS.md

本文档面向 AI 编码助手，介绍本项目（GodotPVZ-Dream_me）的整体架构、开发约定与操作方式。阅读者事先不了解本项目。项目内注释、提交信息、文档均使用中文，请保持这一惯例。

> 必读资料：本项目有两份核心开发文档，内容比本文件更细，动手前应先阅读：
> - `docs/开发相关.md` —— 目录说明、碰撞系统、种植系统、创建新角色/僵尸的完整步骤、组件职责、信号连接规则
> - `docs/子弹说明文档.md` —— 子弹继承体系、`init_bullet` 参数、移动组件、新增子弹步骤

---

## 1. 项目概述

使用 **Godot 4.7.1**（纯 GDScript，无 C#）对原版《植物大战僵尸》(PVZ) 的高保真复刻，除了僵王和部分小游戏外已基本实现全部原版内容。支持冒险/迷你游戏/解密/生存/自定义关卡、花园、图鉴、商店、多用户存档、罐子模式、"我是僵尸"模式等。

- 许可：**自定义非商用许可**（禁止任何商业用途），详见 `LICENSE`。
- 版权注意：原版资源（图片、音频等）因版权问题**不包含在本仓库中**，代码仍通过 `res://assets/...` 引用它们。因此**克隆仓库后直接运行会报大量缺失资源错误**，需要先从 QQ 群/大版本更新视频简介获取完整 `assets/` 目录（见 `.gitignore` 中 `assets` 条目）。
- 交流：QQ 群 1046565016。

## 2. 技术栈与环境

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.7.1（`project.godot` 中 `config/features=PackedStringArray("4.7", "GL Compatibility")`；本机编辑器 `D:\Godot\Godot_v4.7.1-stable_win64.exe`） |
| 语言 | GDScript（`.gd`），`class_name` 全局类型大量使用 |
| 渲染 | `gl_compatibility`（桌面与移动端一致） |
| 视口 | 1066×600，stretch mode `canvas_items` |
| 物理层 | 13 个自定义 2D 物理层（见 `project.godot` 的 `[layer_names]`） |
| 依赖 | 无第三方包管理器依赖，仅依赖引擎 + `addons/` 内置插件 |
| 导出 | Windows Desktop（`export_presets.cfg` preset.0）、Android（preset.1） |

入口场景：`res://scenes/main/01StartMenu.tscn`（开始菜单）。

## 3. 运行与构建

```bash
# 打开项目（需已安装 Godot 4.7.x，headless 编译验证用 `Godot_v4.7.1-stable_win64.exe --headless --path . --editor --quit`，退出时可能因 spine GDExtension 报段错误，属既有问题，不影响导入/编译结果）
godot --path . --editor        # 编辑器
godot --path .                 # 直接运行（进入开始菜单）
```

- 构建/导出：在编辑器中 项目 → 导出，使用 `export_presets.cfg` 中已有的 Windows / Android 预设（导出路径指向本机绝对路径，需按需修改）。
- 命令行导出示例：`godot --headless --path . --export-release "Windows Desktop" out.exe`
- 本机开发环境无自动化构建脚本/CI，一切以编辑器操作为准。

## 4. 测试方式

**没有单元测试框架，也没有 CI。** 测试方式是直接在编辑器中运行场景：

- 直接运行主游戏场景（如 `res://scenes/main/MainGame01Front.tscn`）会使用场景上 `game_para` 导出参数，且 `is_test=true`（卡片无冷却），可通过 `MainGameManager` 节点上的测试参数调试：阳光数、所有僵尸死亡、游戏速度（`test_time_scale` 超过 8 会破坏代码执行顺序导致神秘 bug）。
- `scenes/test/`、`scripts/examples/` 中有零散的测试场景/资源（如 `test/LawnMoweredZombie.tscn`、`test/104_0_0011.tres`），属于手工测试素材。
- `scenes/main/` 下存在 `.tmp` 文件（如 `MainGame01Front_test.tscn453788864.tmp`），是编辑器崩溃/操作残留的临时备份，**不要编辑、不要依赖**。

## 5. 目录结构

```
addons/          编辑器插件（R2Ga_PVZ、anim_player_refactor 等，见 §10）
animation/       动画文件（大部分为独立 .tres）
assets/          美术/音频素材 —— 因版权问题不在仓库中，需自行获取
data/            Theme 主题资源、almanac_data.json（图鉴数据，中文）、LawnStrings.txt（原版字符串）
docs/            开发文档（开发相关.md、子弹说明文档.md）
level_game_para/ 自定义关卡的 ResourceLevelData 参数文件（.tres）
readme_show/     README 展示图
resources/       character_resource（body_change 掉血变化、plant_condition 种植条件）、
                 crazy_dave_resource（戴夫对话）、level_date_resource（内置关卡数据）
scenes/          场景，按域分目录（main/character/bullet/ui/manager/...）
scripts/         脚本，与 scenes 镜像分目录
shaders/         着色器（.gdshader）
shader_material/ 材质文件（僵尸出土等）
test/            手工测试场景/资源
```

`scripts/` 下除自动加载脚本外，主要域目录：

- `autoload/` —— 全局单例（`global/` 下是 Global 场景的子系统：注册表 + 服务）
- `manager/` —— 主游戏子管理器体系（见 §6.3）
- `character/` —— 角色基类 + 各植物/僵尸 + `components/` 组件系统
- `bullet/` —— 子弹脚本（`component/movement/` 移动组件）
- `resources/` —— 自定义 Resource 脚本（`level/` 关卡、`plant_condition/` 种植条件、`save_game/` 存档资源）
- `consts/` —— 全局枚举常量（`ConstLevelData`，见其 README）
- `fx/` —— 特效（`bullet_effect/` 子弹击中特效等）
- `ui/`、`main_game_item/`、`main_game_canvas_layer/`、`garden/`、`almanac/`、`crazy_dave/`、`store/`、`choose_level/`、`start_menu/` —— 各玩法域

## 6. 架构总览

### 6.1 自动加载单例（Autoload，共 7 个，定义于 `project.godot`）

> 注册顺序即初始化顺序：`SoundManager`、`EventBus` 必须排在 `Global` 之前（`Global._ready()` 会应用用户配置，依赖这两个单例已就绪）。

| 单例 | 来源 | 职责 |
|---|---|---|
| `SoundManager` | `scenes/autoload/sound_manager.tscn` | BGM/音效播放、音频对象池、按钮音效自动绑定（`setup_ui_*_sound`） |
| `EventBus` | `scripts/autoload/event_bus.gd` | 事件总线：`push_event` / `subscribe`，支持优先级、一次性订阅、过滤器 |
| `Global` | `scenes/autoload/global.tscn` | **全局门面**：持有各注册表与服务引用；`Global.main_game`（当前主游戏管理器）、`Global.game_para`（当前关卡参数）、`Global.time_scale` |
| `SceneRegistry` | `scripts/autoload/scene_registry.gd` | 散落场景的预加载常量（阳光、特效、戴夫、道具等） |
| `AllCards` | `scenes/autoload/all_cards.tscn` | 全部卡片；游戏创建卡片时从它复制 |
| `GlobalUtils` | `scripts/autoload/util/global_utils.gd` | 工具函数（列表补全、时间字符串、速度系数乘积、一次性计时器等） |
| `TreePauseManager` | `scripts/autoload/tree_pause_manager.gd` | 树暂停管理，按 `E_PauseFactor`（菜单/游戏结束/重新选卡）累加暂停因素 |

### 6.2 Global 门面与数据驱动注册表

`Global` 场景结构（业务代码**只能**通过 `Global.xxx` 访问这些子节点，禁止 `get_node`/`%` 直接访问，以保护初始化顺序）：

```
Global (global.gd)
├── Registry
│   ├── CharacterRegistry   植物/僵尸类型枚举 + 信息字典（数据驱动核心，776 行）
│   ├── MainSceneRegistry   场景枚举 + 场景路径表 MainScenesMap
│   ├── BulletRegistry      子弹类型枚举 + 场景表 + AttackMode（伤害种类）
│   └── ItemRegistry        道具注册表
├── UserManager     用户管理（user://current_user.ini）
├── SaveService     全局存档服务（JSON + 自动存档，见 §6.7）
├── ConfigService   用户配置（user://<用户>/config.ini，音量/控制台选项）
├── GlobalGameState 金币、花园数据、关卡状态、当前植物/僵尸列表
└── GlobalReadData  图鉴 JSON、自然刷怪白/黑名单、罐子白/黑名单
```

**CharacterRegistry 是核心数据源**：`PlantType`（P001~P049 + P999模仿者/P1000发芽/P1001~1003保龄球）、`ZombieType`（Z001~Z025 + Z1001）。每种植物/僵尸在 `PlantInfo`/`ZombieInfo` 字典中登记：名称、冷却、阳光消耗、**场景预加载**、种植条件资源（植物）/行类型（僵尸）。查询用 `Global.character_registry.get_plant_info(type, attr)` / `get_zombie_info(type, attr)`。**新增植物/僵尸必须在此登记**，否则无法在游戏中创建。

`MainSceneRegistry.MainScenesMap` 是场景切换表（开始菜单、各选关场景、花园/图鉴/商店、3 个主游戏场景）。场景间跳转统一走该表。

### 6.3 主游戏管理器体系

主游戏场景继承链：`MainGame00Base.tscn`（含全部管理器与 UI 骨架）→ `MainGame01Front.tscn`（白天）/ `MainGame02Back.tscn`（泳池）/ `MainGame03Roof.tscn`（屋顶）。

- 根节点 `MainGameManager`（`scripts/manager/main_game_manager.gd`）持有全部子管理器引用（`%` 唯一名）与运行阶段 `E_MainGameProgress`（选卡→准备→游戏→结束→重新选卡），阶段切换通过 `EventBus.push_event("main_game_progress_update", ...)` 广播。
- 场景内子管理器继承抽象基类 `MainGameSubManager`（`scripts/manager/main_game_sub_manager.gd`）：在 `_enter_tree` 解析 `main_game`/`game_para`，实现 `init_manager()`。
- 子管理器（均在 `Manager` 节点下）：`CardManager`（卡槽）、`HandManager`（手上物品状态机）、`ZombieManager`（出怪/波次/魅惑管理，含 `zm_zombie_wave_*` 子管理器）、`GameItemManager`（小推车/脑子/道具）、`PlantCellManager`（植物格子 + 墓碑）、`BackgroundManager`（背景）、`DaySunsManager`（天降阳光）、`DropItemManager`（掉落物）。
- 全局跨场景运行数据由 `Global.global_game_state` 承担（文档中提到的 `MainGameDate` 自动加载已不存在，`scripts/manager/main_game_date.gd` 为空壳遗留脚本，勿引用）。

### 6.4 角色系统（植物/僵尸）

**继承体系**（脚本与场景均为继承）：

```
Character000Base (scenes/character/character_000_base.tscn)
├── Plant000Base  (scenes/character/plant/plant_000_base.tscn)
│   └── 各植物：plant_001_pea_shooter_single.tscn 等（底部植物另继承 plant_000_down_base.tscn）
└── Zombie000Base (scenes/character/zombie/zombie_000_base.tscn)
    └── 各僵尸：zombie_001_norm.tscn 等
```

- 角色根节点只处理基础属性、动画、body 相关与少数高度耦合的特殊功能（土豆雷准备、大嘴花攻击、魅惑），其余能力全部由**组件**实现。
- **初始化约定**：创建角色时，在 `add_child` 之前调用 `init_*()` 传入参数（行、格子、初始化类型等）；角色不重写 `_ready()`，而是重写对应的 `init_norm()` / `init_show()` / `init_garden()`。`_ready()` 按 `character_init_type`（`E_CharacterInitType.IsNorm/IsShow/IsGarden`）分发到 `ready_norm()`/`ready_show()`/`ready_garden()`。
- 创建僵尸统一走 `ZombieManager.create_norm_zombie()`。
- 正常出战（Norm）角色死亡**必须**通过血量组件掉血死亡，禁止直接删除。
- 组件基类 `ComponentNormBase`：所有组件支持按 `E_IsEnableFactor`（初始化类型/阶段/睡眠/害怕/魅惑/攻击/死亡等）启用/禁用。
- 常用组件（`scripts/character/components/`）：`component_hp`（血量）、`component_hurt_box`（受击盒）、`component_attack_*`（攻击行为）、`component_detect`（检测）、`component_move`（移动）、`component_anim_*`（动画）、`component_sleep`、`component_scaredy`、`component_blink`、`component_bomb_*`（爆炸）、`component_charred`（灰烬）、`component_garden`（花园）、`iron_node`（铁器）、`drop_body`（掉手/头）等。脚本命名无统一前缀（`component_*` 或 `*_component`），按子目录归类。

### 6.5 子弹系统

详见 `docs/子弹说明文档.md`。要点：

- 脚本继承：`Bullet000Base` → `Bullet000NormBase` → `BulletLinear000Base`（直线）/ `Bullet000ParabolaBase`（抛物线贝塞尔）/ `Bullet000TrackBase`（追踪）；特殊弹（玉米加农炮）只继承 `Bullet000Base`，走独立 `init_cannon` 流程。
- 标准子弹发射后调用 `init_bullet(字典)`（键见 `E_InitParasAttr`）。
- 移动逻辑在 `MovementComponent`（`scripts/bullet/component/movement/`），由子弹根节点在 `_physics_process` 统一调用 `physics_process_bullet_move`，移动组件不单独开 `_physics_process`。
- 新增子弹：基于三种运动基类场景之一新建场景 + 脚本继承对应父类 + 在 `BulletRegistry` 登记 `BulletType`。

### 6.6 碰撞与种植系统

- 物理层含义见 `docs/开发相关.md`（layer 1~13：World、植物/僵尸受击检测、子弹、保龄球、魅惑层、真实受击层、道具层等）。
- 斜面（屋顶）地图区分"检测层面"与"真实层面"受击盒：子弹检测真实碰撞箱，其余检测走检测层面。爆炸特效在真实层面、检测框在检测层面。
- 种植：植物格子 `PlantCell` 管理每格植物，按位置分 `Norm`（普通）/`Down`（底部：花盆/睡莲）/`Float`（漂浮：咖啡豆）/`Shell`（壳：南瓜头）四个容器；`down` 植物通过 `DownPlantSelfContainer` 带动 norm/shell 植物移动。
- 种植条件用自定义资源 `ResourcePlantCondition`（`scripts/resources/plant_condition/`），**必须**保存在 `resources/character_resource/plant_condition/`；特殊植物（双格玉米加农炮等）重写资源脚本。
- 地形类型：`"1 无", "2 草地", "4 花盆", "8 水", "16 睡莲", "32 屋顶/裸地"`，可组合（豌豆射手 = 22）。
- 植物攻击检测受击状态 `E_BeAttackStatusPlant`（正常/悬浮/地刺/低矮）、僵尸 `E_BeAttackStatusZombie`（正常/跳跃/水下/空中/地下等）决定能否被攻击。

### 6.7 关卡参数与存档

- 关卡参数：自定义资源 `ResourceLevelData`（`scripts/resources/level/level_data.gd`），包含背景/BGM/雾雨/出怪/卡槽/罐子/"我是僵尸"/小游戏物品等全部规则；游戏开始调用 `init_para()` 做硬性修正（传送带禁选卡、出怪白名单过滤等）。内置关卡资源在 `resources/level_date_resource/`，自定义关卡在 `level_game_para/`。
- 存档（分层）：
  - 用户：`user://current_user.ini`（`UserManager`）
  - 全局数据：`user://<用户>/GlobalSaveGame.json`（`SaveService`，金币/花园/关卡状态/选卡，自动存档 60s）
  - 配置：`user://<用户>/config.ini`（`ConfigService`）
  - 关卡进度：`user://<用户>/main_game_saves_data/<模式>_<页>_<关>.tres`（`ResourceSaveGameMainGame`，仅支持植物数据与僵尸波次）
- 注意：文档称"读档系统只能从空白场景读档"。

### 6.8 卡片系统

所有卡片在 `AllCards`（自动加载场景）中；创建卡片时从 `AllCards` 复制。候选卡槽卡片用 `CardInBeCard` 场景传入 `Card` 参数创建。卡片的静态角色在 `Card/CardBg/CharacterStatic` 下。快捷键 `ShortcutKeys_Card1~10`、`ShortcutKeys_Shovel` 定义于 `project.godot` 的 `[input]`。

### 6.9 干员系统（明日方舟同人）

详见 **`docs/明日方舟干员系统.md`**。要点：

- **干员 = PlantType 子集**（P050 起）：`Operator000Base extends Plant000Base`（场景 `scenes/character/operator/operator_000_base.tscn`），复用植物种植/格子/被啃食/行渲染完整管线；`Summon000Base extends Operator000Base` 为召唤物基类。
- **部署点数（DP）**：干员消耗独立部署点数（非阳光），`OperatorManager`（主游戏 `Manager` 节点下）持有并自动回复，广播 `update_deploy_point`；干员卡片 `CardBase.is_operator_card = true`。关卡参数在 `ResourceLevelData` 干员分组（`is_can_use_operator` 等）。
- **技能**：`SkillComponent`（`scripts/character/components/skill_component/`）管理技能条（HP 条上方），支持攻击/时间回复、自动/手动触发；子类重写 `_on_skill_use()`、`get_attack_paras()` 实现技能效果与连射/暴击。
- **点击交互**：`OperatorManager._unhandled_input` 物理点查询选中干员，弹出 `scenes/operator/operator_menu.tscn`（撤退返还 70% DP 复用 `be_shovel_kill()`，技能按钮手动触发）；召唤物默认禁用撤退/手动技能。
- **干员唯一性**：每种干员场上最多 1 个（卡片置灰 + 手持拦截，见 `OperatorManager.get_operator_count_by_type`）。
- **攻击范围/方向**：干员为**有限格子范围**攻击（`DetectComponentOperator`，范围形状 `ATTACK_RANGE_SHAPE`），部署时按鼠标相对格子位置选择 4 向方向并显示范围预览（`hm_character`）；攻击朝目标发射跨行直线子弹。**范围形状用 `O/X` 网格表述**（`O`=干员自身格，`X`=攻击覆盖格，每行左对齐；如克洛丝速射手 3×4 为 `XXXX/OXXX/XXXX` 的 3 行、桃金娘执旗手为 `OX` 自身+前方一格，维什戴尔 5×5 菱形为 `XXX/XXXX/OXXXX/XXXX/XXX`，见 docs §3.1/§4.1/§5.1）；`get_attack_range_shape()` 返回 `Array[Vector2i]`（`(行偏移, 列偏移)`，`(0,0)` 为自身格）。
- **阻挡数**：干员 `Operator000Base.block_count`（默认 1，近卫/重装等后续覆盖为 2~3）；`DetectComponent._judge_enemy_is_can_be_attack` 对干员调用 `is_block_full()`——已阻挡僵尸数 ≥ `block_count` 时新僵尸**穿过不停止**（`get_blocked_zombie_count()` 统计 `zombie.is_attack` 且 `detect_component.enemy_can_be_attacked == self` 的僵尸）。桃金娘执旗手特性"技能发动期间阻挡数变为0"用**禁用受击盒**实现（`_set_blocking(false)` → `hurt_box_component.disable_component(Character)`），僵尸检测不到她 → 已在啃食的僵尸也停止啃食继续移动穿过。
- **攻击周期（`AttackComponentOperator`，one-shot 计时器 + 每轮手动武装）**：索敌 → 播攻击动画 → 等 `bullet_spawn_delay`（与动画"松手"时刻对齐）→ 按 `get_attack_paras()` 连射（`burst_interval` 间隔，二连发两箭可辨）→ 广播 `signal_operator_shoot`（技能点回复）。保证：索敌后**立即攻击**（无基类随机初始延迟）、下一轮间隔 = `max(攻击间隔, 攻击动画时长)`（**攻击动画一定播完才开始下一轮**）、计时器到点目标过期时**立即重新索敌一次**（不整轮跳过）、无目标时快速重试（`RETRY_INTERVAL=0.25s`）。计时器在干员场景里必须 `one_shot = true`。
- **技能选择面板（多技能干员选卡）**：数据驱动——注册表 `PlantInfoAttribute.OperatorSkills`（`{技能id: {name, desc, icon}}`，desc 每行 ≤ 约20个汉字）登记，`CardSlotCandidate.operator_skill_card_appear(类型)` 动态生成按钮（面板结构：`AllOperatorSkillCard` 全屏覆盖 + 居中 `Panel`(470×480) + `SkillList`(内缩 **36px**，内腔 398×408，避开面板 ~30px 装饰边框) + `SkillButtonList`，标题 22 号字、按钮 15 号字），**新多技能干员只登记数据不改面板**。注意 `AllOperatorSkillCard` 必须 `visible = false` 且 `_ready` 防御性隐藏——编辑器自动保存会省略默认值行，丢掉后开局显示空技能页。
- **范围预览统一挂世界画布**：`OperatorRangePreview`（部署预览 `hm_character` 与干员菜单 `operator_menu` 都挂主游戏场景根、**z_index=0**，低于植物行 z=10 避免盖在干员脸上），多边形即世界坐标，条纹 shader（`operator_range_stripes.gdshader`）在世界坐标空间计算，**随分辨率同步缩放**（任何窗口尺寸下条纹与草坪相对宽度一致）；不要挂 `CanvasLayerTemp` 等图层画布。
- **迷你血条/技能条**：头顶 15×2px 蓝色血条 + 紧挨其下的技能条，半透明黑背景，与植物僵尸的大血条样式不同。血条/技能条 `Control` 设 `z_as_relative=false` + `z_index=1000` 全局置顶，避免被其他干员身体覆盖（见 `operator_000_base.tscn` 的 `HpControl`/`SkillControl`）。
- **动画约定**：固定动画名 `idle/attack/skill/die`，`AnimComponentOperator`（基于 AnimationPlayer）播放，轨道作用于 `Body/BodyCorrect/OperatorSprite` 容器；素材为 Spine 3.8.99，当前用立绘占位，Spine 模型接入/提取/运行全流程见 **§10 明日方舟 Spine 素材管线**。**坑**：干员场景的 `AnimationTree` 仅为满足攻击组件基类的 `$"../AnimationTree"` 引用，必须显式 `active=false`（默认 active 会重置 OperatorSprite 的 modulate 导致形象透明）；动画轨道 `update` 用 0（continuous）否则不插值。
- 选卡界面干员页：`CardSlotCandidate` 的 `GridContainerOperator`，白名单 `Global.global_game_state.curr_operator`；植物/模仿者页会过滤掉干员类型。

### 6.10 添加干员总流程（以克洛丝为模板，详见 docs/明日方舟干员系统.md）

1. **素材准备（必做第 1 步，每次添加干员都必须先做，禁止用占位立绘代替提交）**：
   - **先从游戏目录提取 Spine 正/背面双素材**：用 **ArkUnpacker**（`tools/ArkUnpacker-v5.1.0.exe -m ab --spine --image --text`）解 `chararts/char_<id>.ab`，输出 `BattleFront/`（正）与 `BattleBack/`（背）两套；正面三件套 `skel/atlas/png` 放 `assets/image/operator/<干员id>/`（id = 素材文件夹名 = 场景 `operator_id` = 校准 JSON 键），背面放 `<id>/back/` 子目录。（旧 `extract_ab.py` 需 UnityPy 且同名覆盖只留正面，**勿用**）
   - **alpha 合成**：战斗模型主纹理 alpha 分离在 `'<名>[alpha]'` 纹理 → `python tools/spine_extract/merge_alpha.py <主>.png <alpha>.png`（覆盖主图；需 Pillow，用项目内隔离 venv 安装后跑）
   - 改过素材后**强制重导入**（删对应 `.import` + `.godot/imported/` 缓存，跑 `godot --headless --editor --quit`；删 `.import` 后**首次跑会因 png 尚未导入报 preload "no resource loaders"，再跑一次即恢复**）
2. **数值**（wiki **满级 + 满潜五档累加**；"满级"= 该干员可达的最高精英阶段满级：★3 精英1满级、★4~6 精英2满级等，见 docs §1.8 星级等级上限表）：
   - `scripts/autoload/global/character_registry.gd`：`PlantType` 枚举（P050 起）+ `OperatorPlantType` + `PlantInfo` 登记（`SunCost`=部署费用、`CoolTime`=再部署、`PlantConditionResource`、`PlantScenes`）
   - **数据驱动字段（干员卡牌/调试工具/出战通用，必登记）**：`OperatorDisplayName`（中文显示名）、`OperatorCardBg`（整卡图）、`OperatorBulletScene`（攻击子弹场景）、`OperatorAttackAnims`（攻击动画候选，无单 Attack 素材时用）、`OperatorAttackModes`（攻击模式表，调试工具模拟技能用：`{显示名: {count, mult, is_skill3}}`）；**多技能干员另登记 `OperatorSkills`**（选卡技能选择面板数据：`{技能id: {name, desc, icon}}`，desc 每行 ≤ 约20个汉字）
   - 场景 `HpComponent.max_hp`、子弹场景 `attack_value`（攻击力）、`AttackComponent.attack_cd`（攻击间隔）
3. **场景与脚本**：从 `operator_000_base.tscn` 新建继承场景，脚本 `extends Operator000Base`，设 `plant_type`、`operator_id`；重写 `get_attack_paras()`（连射/暴击天赋）、`_on_skill_use()`（技能效果）
4. **Spine 接入**：场景 `Body/BodyCorrect/OperatorSprite` 下挂 `OperatorSpineSprite`（`skel_path`/`atlas_path` + `back_skel_path`/`back_atlas_path`）；动画名**可配置**（`anim_name_idle/enter/die` + `attack_anim_names` 多攻击动画随机，克洛丝默认 `Idle/Attack/Start/Die`，维什戴尔 `Idle/Attack_A~C/Start/Die`，见 `docs/明日方舟干员系统.md` §4.5）；**`AnimationTree` 必须 `active=false`**
5. **攻击/检测**：`AttackComponentOperator`（`attack_cd`/`attack_bullet_type`/`bullet_spawn_offset`/`bullet_spawn_delay`）+ `DetectComponentOperator`（范围形状默认克洛丝 3×4，不同干员覆盖 `Operator000Base.get_attack_range_shape()`，如维什戴尔 5×5 菱形；干员唯一性/无视屋顶/转身逻辑在基类无需改）
6. **校准**：跑 `test/operator_debug_tool.tscn` 调发射延迟/发射点/血条尺寸 → **「应用」**写 `data/operator_calibration.json`（游戏运行时读取覆盖，不写场景文件）；工具已通用化（显示名/子弹/攻击动画/攻击模式均从注册表读取），仅需在工具脚本 `OPERATOR_GAME_VALUES` 登记校准初始值（JSON 无此干员时回退）
7. **卡片与白名单**：`scenes/autoload/all_cards.tscn` 的 `PlantCards2` 加一个**默认状态**的 `Card` 实例（`card_plant_type` + `is_operator_card = true`；多技能干员额外设 `is_multi_skill_operator = true`）；**卡牌背景/角色隐藏由代码自动处理**（`CardBase.get_operator_full_card_texture()` 读注册表 `OperatorCardBg` 设置整卡、`Card._ready` 自动隐藏静态角色，无需手工覆盖 CardBg/CharacterStatic）；`Global.global_game_state.curr_operator` 加入白名单
8. **音效（可选）**：默认部署/死亡/技能发动音效由基类 `Operator000Base` 的 `get_deploy_sfx()`/`get_death_sfx()`/`get_skill_use_sfx()` 钩子提供（默认键 `OperatorDeploy`/`OperatorDeath`/`OperatorSkill`，无专属音效的干员自动使用）；有专属音效时覆盖钩子返回专属键（如维什戴尔三技能返回空、由 `_skill3_activate` 播 `WisdelSkill3Start`）
9. **验证**：`godot --headless --editor --quit` 编译零错误；`test/operator_spine_check.gd`（干员场景冒烟）、`test/operator_back_view.tscn`（正/背面朝向查看）；进游戏实测部署（两段式）/攻击/技能/转身/撤退

**新增干员文件速查（必改清单）**：

| # | 文件 | 改动 |
|---|---|---|
| 1 | `scripts/autoload/global/character_registry.gd` | `PlantType` 枚举（P052 起）+ `OperatorPlantType` 加入 + `PlantInfo` 登记（数值 + `OperatorDisplayName`/`OperatorCardBg`/`OperatorBulletScene`/`OperatorAttackAnims`/`OperatorAttackModes`；多技能干员加 `OperatorSkills`） |
| 2 | `assets/image/operator/<id>/` | Spine 素材三件套（skel/atlas/png，背面放 `back/` 子目录）+ 整卡图（卡牌用） |
| 3 | `scenes/character/operator/operator_0XX_xxx.tscn` + `scripts/character/operator/operator_0XX_xxx.gd` | 从 `operator_000_base` 继承；`plant_type`/`operator_id`；`HpComponent.max_hp`、`AttackComponentOperator`（`attack_cd`/`attack_bullet_type`/发射点）、`DetectComponentOperator`；重写 `get_attack_paras()`/`_on_skill_use()`/`get_attack_range_shape()`；Spine 挂 `OperatorSprite` 下 |
| 4 | `scenes/autoload/all_cards.tscn` | `PlantCards2` 加一个**默认状态** `Card` 实例（`card_plant_type` + `is_operator_card=true`；多技能干员加 `is_multi_skill_operator=true`）；背景/角色隐藏由代码自动处理，**无需覆盖** |
| 5 | `scripts/autoload/global/global_game_state.gd` | `curr_operator` 白名单加入 |
| 6 | `test/operator_debug_tool.gd` | `OPERATOR_GAME_VALUES` 登记校准初始值（JSON 无此干员时回退）；其余（显示名/子弹/动画/攻击模式）自动从注册表读 |
| 7 | 音效（可选） | wav 放 `assets/audio/SFX/operator/` + `SFXCharacterMap` 注册键；覆盖 `get_deploy_sfx()`/`get_death_sfx()`/`get_skill_use_sfx()` 返回专属键（无专属用默认键） |

> 召唤物（如魂灵之影）：继承 `Summon000Base`（无部署音效/默认不可撤退可改），由干员脚本 `_spawn_shadow` 创建并登记；撤退/死亡需从主人的召唤列表移除（见 `summon_002_wisdel_shadow.gd`）。

## 7. 开发约定

### 7.1 命名与文件组织

- 注释、文档、提交信息一律使用**中文**。
- 脚本/场景按域镜像存放：`scenes/<域>/` 与 `scripts/<域>/` 一一对应，角色/子弹编号前缀命名（如 `plant_001_pea_shooter_single.gd`、`zombie_004_pole_vaulter.gd`、`bullet_002_pea_snow.tscn`），编号与注册表枚举一一对应。
- 全局类型用 `class_name`（`CharacterRegistry`、`BulletRegistry`、`ResourceLevelData`、`MainGameManager` 等），全局枚举/常量优先放 `scripts/consts/const_level_data.gd`（`ConstLevelData`）。
- 枚举名以 `E_` 开头（`E_CharacterInitType`、`E_IsEnableFactor`、`E_MainGameProgress`）；信号名以 `signal_` 开头（`signal_character_death`）。
- 用 `#region` / `#endregion` 组织大脚本。
- 节点引用用 `%唯一名`（`@onready var hp_component: HpComponent = %HpComponent`）。
- 类型标注尽量完整（GDScript 强类型风格，`Array[CharacterRegistry.PlantType]` 等）。
- 字体：拉丁/数字使用 MiSans_Latin（`assets/fonts/MiSans_Latin/`），中文由 `assets/fonts/MiSans_{Regular,Bold,Medium}.tres`（FontVariation）回退到 SIMSUN / 方正少儿；新增字体引用请基于这三个变体，不要直接引用 ttf。

### 7.2 访问与耦合规则

- 业务/UI 只能通过 `Global.xxx` 访问全局子系统（见 §6.2 注释），不直接 `get_node` Global 场景子节点。
- 场景切换走 `MainSceneRegistry.MainScenesMap`，事件解耦用 `EventBus`。
- 角色信号连接规则（`docs/开发相关.md`）：角色自身 Timer 的 `timeout` 可在编辑器直接连接；组件自身 Timer 必须连到组件本体；父组件可连子组件信号（攻击组件←攻击检测组件）；速度/禁用影响类组件由角色根节点在信号连接函数中连接；其余自定义信号一律由角色本体在初始化函数中连接。
- **踩坑必记**：开发中踩到并解决的坑（尤其是 headless 验证、场景继承、动画/渲染类隐蔽问题），解决后必须立即记入 `docs/开发相关.md` 的"可能踩的坑"小节（或对应领域文档如 `docs/明日方舟干员系统.md`），写明现象、根因、修复；不要只留在对话里。

### 7.3 新增内容的推荐步骤

- **新增植物**：从 `plant_000_base.tscn`（底部植物用 `plant_000_down_base.tscn`）新建继承场景 → 新建脚本 `extends Plant000Base` 并设置 `plant_type` → 在 `CharacterRegistry` 的 `PlantType` 枚举 + `PlantInfo` 字典登记（含场景、冷却、阳光、种植条件）→ 种植条件资源放 `resources/character_resource/plant_condition/` → 卡片资源加入 `AllCards`。
- **新增僵尸**：从 `zombie_000_base.tscn` 新建继承场景 → 设置 `zombie_type` → 动画轨道上按文档添加方法调用（移动开头 `MoveComponent._walking_start()`、死亡结尾 `Zombie000Base._fade_and_remove()`、攻击时 `AttackComponent.attack_once()`）→ 在 `ZombieInfo` 登记（含行类型）→ 按需加入 `GlobalReadData` 自然刷怪白名单。新僵尸动画请参照 `docs/开发相关.md` 的"新僵尸"小节（影子/身体/掉手掉头/防具血量阶段等节点要求）。
- **新增子弹**：见 §6.5 与 `docs/子弹说明文档.md`。
- **新增干员**：按 **§6.10 添加干员总流程**（素材提取/正背面双素材 → wiki 满级+满潜数值 → 枚举+PlantInfo 登记 → 继承场景/脚本 → Spine 接入 → 攻击/检测组件 → 调试工具校准写 JSON → 卡片+白名单 → 验证），详见 `docs/明日方舟干员系统.md`。
- **新增关卡**：创建 `ResourceLevelData` 资源（.tres），放 `level_game_para/` 即可在自定义关卡中使用。

## 8. 编辑器插件（addons/）

- `R2Ga_PVZ`：PVZ 动画转 Godot 动画格式（可视化）。
- `anim_player_refactor`：重构 AnimationPlayer 动画（删除轨道）；`anim_delete_track` / `anim_free_common_tracks`：配套的删轨道工具。
- 其余：`script-ide`（脚本 UI 增强）、`sprite_painter`、`todo_controller`（TODO 面板）、`DragNDropNodes`、`SignalVisualizer`、`calculate_roration`。
- 注意：`anim_player_refactor` 的 `plugin.gd` 中 `EditorUtil.find_animation_menu_button` 只匹配英文 "Animation"，中文编辑器需自行改成 `node.text == "Animation" or node.text == "动画"`（README 有说明）。
- 启用的插件见 `project.godot` 的 `[editor_plugins]`（含 DragNDropNodes、R2Ga_PVZ、anim_free_common_tracks、anim_player_refactor、todo_controller）。

## 9. 常见坑与注意事项

- 仓库缺少 `assets/`，运行前需自行补齐（见 §1），否则大量 `preload("res://assets/...")` 报错。
- 静态迷雾初始化会删除 `del_fog_postion_area` 之外的所有静态迷雾，修改屏幕尺寸需同步调整该参数（`docs/开发相关.md` "可能踩的坑"）。
- 植物种植必须同时满足格子空闲与地形；紫卡植物有前置植物（`AllPrePlantPurple`）。
- 出怪刷新列表禁止写 `Z021Bungi`（用 `is_bungi` 参数）；列表会按白名单自动过滤并打印 warning。
- `docs/开发相关.md` 中个别描述已过时（如 `MainGameDate` 自动加载已移除），以代码为准。
- `test_time_scale` 超过 8 会引发执行顺序问题。
- **Godot 4.7 Container 最小尺寸钳制**：VBox/HBox 等容器的实际尺寸会被钳制为**不小于其组合最小尺寸**（子节点最小宽高之和），即使锚点/offset 给了更小的目标值——内容过宽/过高会把容器（乃至按钮文本）撑出面板边框。做固定尺寸面板时先确保内容最小尺寸小于容器内腔（缩短文本/减小字号/加高面板），不要指望锚点把内容压回去（见 `docs/开发相关.md` 坑 24）。
- 干员攻击计时器为 **one-shot + 每轮手动武装**（`AttackComponentOperator`），干员场景里 `BulletAttackCdTimer` 必须 `one_shot = true`，否则新旧两套逻辑叠加会双倍触发。
- 统计干员子弹数量时不要用 `bullets.child_entered_tree` 数节点名：子弹死亡时 `TrailComet.detach_and_fade()` 会把拖尾节点重挂到 `Bullets`（同名兄弟还会被 Godot 自动改名），按 `is BulletXXX` 类判断或直接看发射日志（见 `docs/开发相关.md` 坑 26）。

### 9.1 暂忽略 / 待排查清单（后续回来逐项排查）

> 这些是**当前有意简化/暂缓**的点，改到相关代码或新增干员时先回来核一遍。

- **1080p 攻击范围条纹变细**：**已修复（2026-08）**。根因：canvas_item shader fragment 内置 `VERTEX` 是屏幕/视口像素坐标，`canvas_items` 拉伸下随窗口缩放；修复改为 vertex 阶段用 `MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)` 传世界坐标 varying（见 `shaders/operator_range_stripes.gdshader` 与 `docs/开发相关.md` 坑 31）。
- **spine 纹理 `res:///` 三斜杠报错**：spine-godot 扩展 `GodotSpineTextureLoader::fix_path` 对 `res://assets/...`（双斜杠）会拼成 `res:///assets/...`（三斜杠），编辑器扫描/preload 时会 `Can't load texture`；但 `--script` 模式下 atlas 纹理能加载（count=1）。**非致命、未阻塞游戏**（kroos/wisdel 同样存在），但若出现干员形象透明先查这里。根治需改 `bin/` 扩展 C++ 源码（`SpineAtlasResource.cpp` 的 `fix_path`）后重编译。
- **桃金娘天赋"所有先锋回血"只回自身**：目前仅桃金娘是先锋，`operator_003_myrtle._process` 简化为自身回血；新增第二个先锋干员时需改成遍历场上所有先锋干员回血。
- **干员撤退不重置卡片冷却**：与铲子一致（`docs/明日方舟干员系统.md` §7 已知取舍），完整"再部署时间重置"留待后续。
- **干员防御/法术抗性未参与伤害计算**：`character_registry` 只登记了 HP/攻击，防御/法抗暂不用于 PVZ 减伤（`docs/明日方舟干员系统.md` §3.1 注）。
- **执旗手"技能期间阻挡数0"只覆盖桃金娘**：桃金娘用 `_set_blocking()` 禁用受击盒实现；其他未来执旗手需各自实现相同逻辑（`hurt_box_component.disable_component(Character)`）。
- **阻挡数机制未对普通植物生效**：只对 `Operator000Base` 判断（`component_detect.gd` 里 `enemy is Operator000Base`），普通植物仍"来多少僵尸都停下"（原版 PVZ 行为）。
- **`test/myrtle_spine_check.gd` 只验证 skel/动画不验证纹理**：冒烟测试 `is_skeleton_data_loaded()` 不检查 atlas 纹理加载，需补 `atlas.textures.size()` 断言。

## 10. 明日方舟 Spine 素材管线（提取 → 转换 → 导入 → 运行）

> 目标：从明日方舟客户端提取干员 Spine 模型（战斗/基建），导入 Godot 用 `SpineSprite` 播放。
> 本管线已在克洛斯（char_124_kroos）上完整验证，素材在 `assets/image/operator/kroos/`，演示场景 `test/spine_demo.tscn`。

### 10.1 运行时状态（先读，版本匹配是最大坑）

- `bin/` 内为**自编译 spine-godot GDExtension（Spine Runtime 3.8）**：直接加载游戏原始 3.8.99 数据，**无需版本转换**。
  - 构建来源：spine-runtimes 4.2 分支 commit `3653540` + [litwak913/spine38-godot-patches](https://github.com/litwak913/spine38-godot-patches) 补丁，godot-cpp 4.5，scons 构建（参考 [godot-spine38 博客](https://blog.goldenglow.dev/post/godot-spine38/)）。源码/构建产物在 `C:\Users\IndexZero\Desktop\arkspine\build38\`。
- 原官方 **4.3** 版扩展备份在 `bin_backup_4.3/`。4.3 运行时**只接受 4.3.x 数据**，报错形如 `Skeleton version 4.2.11 does not match runtime version 4.3`。
- 版本铁律：**3.8 运行时 ↔ 3.8 原始数据**（本项目现状）；4.2 运行时 ↔ 4.2 转换数据；4.2/4.3 二进制布局不兼容（改版本号会崩溃），转换器也不支持输出 4.3。

### 10.2 提取（游戏资源 → skel/atlas/png）

- 游戏目录：`D:\Program Files\Hypergryph Launcher\games\Arknights\Arknights_Data\StreamingAssets\AB\Windows\`
- 战斗模型在 `chararts/char_<id>.ab`（克洛斯 = `char_124_kroos.ab`）；同一包内含基建模型（`build_char_124_kroos.*`）。
- 步骤：
  1. **推荐用 ArkUnpacker**：`tools/ArkUnpacker-v5.1.0.exe -m ab -i <ab路径> -o <输出目录> --spine --image --text` —— 直接导出 `BattleFront/`（正）/`BattleBack/`（背）/`Building/`（基建）三套三件套，无需 UnityPy。`extract_ab.py` 需 UnityPy 且同名覆盖只留正面，仅在无 ArkUnpacker 时用。
  2. 配对规则（同一角色包内多套资源）：**战斗模型**选 `F_*` 前缀图集 + 较大 skel（动画 `Start/Idle/Attack/Die`）；`B_*` 前缀是低清变体；`build_*` 是基建（动画 `Default/Interact/Move/Relax/Sit/Sleep`）。
  3. **alpha 合成**：战斗模型主纹理是不透明 DXT1（alpha 缺失），透明通道在独立 `'<名>[alpha]'` 纹理 → `python tools/spine_extract/merge_alpha.py <主>.png <alpha>.png`。基建模型（BC7）自带 alpha，跳过此步。
  4. 质量说明：战斗 = 512×512 DXT1（有损）、基建 = 500×500 BC7（高质量）。这是游戏原始质量，**不存在更高清的图集**（`*_1` 大图是 AVG 立绘，非战斗图集，勿混用）。
- 验证：3.8 二进制 skel 头部为 `[长度][hash串][长度]"3.8.99"`；atlas 首行为图集页名。

### 10.3 转换（可选，3.x → 4.x）

- `tools/spine_extract/SpineSkeletonDataConverter.exe <in.skel> <out.skel> -v 4.2.11`（支持 3.5~4.2，`-v` 必须完整 x.y.z；跨 3.x/4.x 自动转换 rotate/curve）。
- **本项目不需要转换**（3.8 运行时直接加载原始数据）。仅当改用 4.2 运行时才需要。
- 配套 `SpineAtlasDowngrade.exe` 用于 4.x→3.x 图集降级（本项目未用）。

### 10.4 导入 Godot

- 素材三件套 `.skel/.atlas/.png` 同名放入 `assets/image/operator/<角色>/`，编辑器扫描后自动导入（生成 `.import`）。
- **改过 png/skel/atlas 后必须强制重导入**：删除对应 `.import` 文件 + `.godot/imported/` 缓存，再跑 `godot --headless --editor --quit`。**游戏模式不会重导入已变更文件**（换纹理后黑框/旧图就是这原因）。
- 扩展注册：`.godot/extension_list.cfg` 内一行 `res://bin/spine_godot_extension.gdextension`（编辑器扫描自动维护）。**别在项目内放第二份 `.gdextension`**（备份目录也要移出项目），否则双注册报 `Attempt to register extension class ... already registered`。
- 图集导入时的 `Failed loading resource: ...png` 报错是导入顺序问题（图集先于 png 导入），非致命，重跑一次编辑器导入即可。

### 10.5 运行（SpineSprite）

- 运行时加载（推荐，不依赖导入状态），完整示例见 `test/spine_demo.gd`：
  ```gdscript
  var skel_res = SpineSkeletonFileResource.new()
  skel_res.load_from_file("res://assets/image/operator/kroos/char_124_kroos.skel")
  var atlas_res = SpineAtlasResource.new()
  atlas_res.load_from_atlas_file("res://assets/image/operator/kroos/char_124_kroos.atlas")
  var data_res = SpineSkeletonDataResource.new()
  data_res.skeleton_file_res = skel_res
  data_res.atlas_res = atlas_res
  var sprite = SpineSprite.new()
  sprite.skeleton_data_res = data_res
  sprite.get_animation_state().set_animation("Idle", true, 0)  # (动画名, 循环, 轨道)
  add_child(sprite)
  ```
- 动画名：战斗 `Idle/Attack/Die/Start/Default`；基建 `Relax`=待机（`Default` 是 **0 秒静态姿势**，不是待机）。
- 验证：`godot --headless --path . --script res://test/spine_check.gd`（加载+播放冒烟）。
- 3.8 移植版 API 差异：**没有** `get_animation_count()`/`get_animation_names()` 绑定；`set_animation(name, loop, track)` 参数顺序如此。

### 10.6 接入干员（结合 §6.9）

- 干员渲染层约定固定动画名 `idle/attack/skill/die`（AnimationPlayer 管线）。接入 Spine 时把 `SpineSprite` 挂到 `OperatorSprite` 容器替换立绘占位，通过 `get_animation_state()` 播放对应动作，并按 §10.5 的 `set_animation` 与 AnimComponentOperator 的状态机联动（如受击/部署播 `Start`、阵亡播 `Die`）。

## 11. Godot AI MCP（AI 助手操作编辑器/运行中游戏）

项目启用了 **godot-ai** 插件（`addons/godot_ai/`，MCP 服务随编辑器启动），AI 助手可通过 MCP 工具直接操作编辑器与运行中的游戏。常用工作流：

- **连接确认**：`session_manage(list)` 查看会话（本机通常只有本项目 `arkpvz@xxxx`）；`editor_state` 查看编辑器就绪状态与游戏运行状态。
- **运行场景**：`project_run(mode="custom", scene="res://scenes/main/MainGame01Front.tscn")` —— 直接跑主游戏场景即 **is_test=true 测试模式**（卡片无冷却、阳光满），是干员/角色功能实测首选；`project_manage(stop)` 停止。
- **运行中脚本执行**：`editor_manage(game_eval)` 在游戏进程里执行 GDScript 并返回结果（可 `await`），用于部署干员、生成僵尸、读取运行态布局与状态（如 `Global.main_game.plant_cell_manager.all_plant_cells`、`zombie_manager.create_norm_zombie(...)`、节点 `get_global_rect()`）。
- **读取日志**：`logs_read(source="game")` 看运行期日志（`push_error` 会被记录）；`logs_read(source="editor")` 看编辑器报错。
- **坑（务必注意）**：
  - `game_eval` 代码一旦抛错，游戏会**停在调试器断点**（后续 eval 报 `EVAL_GAME_NOT_READY`），必须先 `project_manage(stop)` 再 `project_run` 重跑；eval 代码要防御式（判空/`is_instance_valid`），别在 lambda 里访问 `Window` 类属性。
  - 编辑器运行游戏时**改脚本不会热重载**，验证改动必须停掉游戏重跑。
  - 独立跑非主游戏场景（如 `card_slot_norm.tscn`）时 `Global.main_game` 为 null、场景根 Control 无父尺寸，锚点布局退化——测量 UI 要先模拟真实父尺寸/调用入场 tween（如 `move_card_slot_candidate(true)`）。
  - GL Compatibility 下游戏内 `get_viewport().get_texture().get_image()` 拿不到渲染结果（空图）；要验证渲染用编辑器 `editor_screenshot(source="game")`。
  - headless 验证脚本编译：`Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit`（退出时 spine GDExtension 报加载失败/段错误属既有问题，不影响编译结果）。
  - 编辑器自动保存会**回写 .tscn**（MCP 改过的属性、删默认值行等），用文件工具编辑 .tscn 时以磁盘当前内容为准（先 Read 再 Edit）。
