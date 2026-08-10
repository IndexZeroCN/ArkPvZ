# AGENTS.md

本文档面向 AI 编码助手，介绍本项目（GodotPVZ-Dream_me）的整体架构、开发约定与操作方式。阅读者事先不了解本项目。项目内注释、提交信息、文档均使用中文，请保持这一惯例。

> 必读资料：本项目有两份核心开发文档，内容比本文件更细，动手前应先阅读：
> - `docs/开发相关.md` —— 目录说明、碰撞系统、种植系统、创建新角色/僵尸的完整步骤、组件职责、信号连接规则
> - `docs/子弹说明文档.md` —— 子弹继承体系、`init_bullet` 参数、移动组件、新增子弹步骤

---

## 1. 项目概述

使用 **Godot 4.6.2**（纯 GDScript，无 C#）对原版《植物大战僵尸》(PVZ) 的高保真复刻，除了僵王和部分小游戏外已基本实现全部原版内容。支持冒险/迷你游戏/解密/生存/自定义关卡、花园、图鉴、商店、多用户存档、罐子模式、"我是僵尸"模式等。

- 许可：**自定义非商用许可**（禁止任何商业用途），详见 `LICENSE`。
- 版权注意：原版资源（图片、音频等）因版权问题**不包含在本仓库中**，代码仍通过 `res://assets/...` 引用它们。因此**克隆仓库后直接运行会报大量缺失资源错误**，需要先从 QQ 群/大版本更新视频简介获取完整 `assets/` 目录（见 `.gitignore` 中 `assets` 条目）。
- 交流：QQ 群 1046565016。

## 2. 技术栈与环境

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.6.2（`project.godot` 中 `config/features=PackedStringArray("4.6", "GL Compatibility")`） |
| 语言 | GDScript（`.gd`），`class_name` 全局类型大量使用 |
| 渲染 | `gl_compatibility`（桌面与移动端一致） |
| 视口 | 1066×600，stretch mode `canvas_items` |
| 物理层 | 13 个自定义 2D 物理层（见 `project.godot` 的 `[layer_names]`） |
| 依赖 | 无第三方包管理器依赖，仅依赖引擎 + `addons/` 内置插件 |
| 导出 | Windows Desktop（`export_presets.cfg` preset.0）、Android（preset.1） |

入口场景：`res://scenes/main/01StartMenu.tscn`（开始菜单）。

## 3. 运行与构建

```bash
# 打开项目（需已安装 Godot 4.6.x）
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
- **攻击范围/方向**：干员为**有限格子范围**攻击（`DetectComponentOperator`，范围形状 `ATTACK_RANGE_SHAPE`），部署时按鼠标相对格子位置选择 4 向方向并显示范围预览（`hm_character`）；攻击朝目标发射跨行直线子弹。
- **迷你血条/技能条**：头顶 15×2px 蓝色血条 + 紧挨其下的技能条，半透明黑背景，与植物僵尸的大血条样式不同。
- **动画约定**：固定动画名 `idle/attack/skill/die`，`AnimComponentOperator`（基于 AnimationPlayer）播放，轨道作用于 `Body/BodyCorrect/OperatorSprite` 容器；素材为 Spine 3.8.99，当前用立绘占位，Spine 模型接入/提取/运行全流程见 **§10 明日方舟 Spine 素材管线**。**坑**：干员场景的 `AnimationTree` 仅为满足攻击组件基类的 `$"../AnimationTree"` 引用，必须显式 `active=false`（默认 active 会重置 OperatorSprite 的 modulate 导致形象透明）；动画轨道 `update` 用 0（continuous）否则不插值。
- 选卡界面干员页：`CardSlotCandidate` 的 `GridContainerOperator`，白名单 `Global.global_game_state.curr_operator`；植物/模仿者页会过滤掉干员类型。

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
- **新增干员**：见 `docs/明日方舟干员系统.md` §5（枚举+PlantInfo 登记 → 从 `operator_000_base.tscn` 继承场景/脚本 → `idle/attack/skill/die` 动画 → `get_attack_paras()`/`_on_skill_use()` → AllCards 卡片 → `curr_operator` 白名单）。
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
  1. `python tools/spine_extract/extract_ab.py <ab路径> <输出目录>` —— 脚本内置方舟自定义压缩修复（伪 LZHAM = 字节序交换的 LZ4，官方 UnityPy 不支持）。
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
