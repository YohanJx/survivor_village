# 开发指南

开发规范、项目结构、测试与存档实现集中在此；玩家介绍和运行指引见 [README](../README.md)。

## 开发规范

后续开发统一遵循 [项目代码与架构规范](project_conventions.md)，涵盖命名、脚本顺序、显式类型、资源与运行时状态、信号通信、昼夜结算、自动战斗、存档及验证。根目录 [AGENTS.md](../AGENTS.md) 保存开发执行约定，适用于整个项目。评审使用 [检查表](code_review_checklist.md)，现状与迁移顺序见 [技术债清单](technical_debt.md)。基础检查命令为 `python3 tools/check_conventions.py`；它不替代引擎解析和行为测试。

## 启动与环境

用 **Godot 4.5（当前验证基线）**导入本目录的 `project.godot`，按 **F5**。不需要插件、C#、外部服务或额外美术资源。

### Windows 一键启动

下载并解压完整项目，双击根目录的 `run_windows.bat`。脚本先导入资源，再直接打开游戏；导入或运行失败时保留窗口显示错误。

脚本按以下顺序寻找 Godot：命令行指定路径、环境变量 `GODOT_EXE`、项目根目录、`tools/godot/`、系统 PATH。自动识别 `godot.exe` 或官方 `Godot*.exe` 文件名，无需改名。建议只放一个 Godot 版本，使用当前验证基线 **4.5 标准版**。

未找到 Godot 时，会自动打开 [Godot 官方 Windows 下载页面](https://godotengine.org/download/windows/)。可从官网历史版本下载 [4.5 标准版](https://godotengine.org/download/archive/4.5-stable/)，解压后将 exe 放到脚本旁边或 `tools/godot/`，再次双击启动。无需安装 C# / .NET，也无需下载导出模板。

如果 Godot 已经解压在其他位置，可以把 exe 拖到 `run_windows.bat` 上，或在命令提示符中运行：

```bat
run_windows.bat "D:\Applications\Godot\Godot_v4.5-stable_win64.exe"
```

脚本支持带空格和中文的项目路径。其他 Godot 版本及 Windows 实机运行尚未验收；当前启动流程仅在 macOS 上验证了等效的 Godot 导入与主场景启动。

在这台 Mac 上也可以运行：

```sh
/Applications/Godot4.5.app/Contents/MacOS/Godot --path .
```

## 工程结构

| 文件 | 职责 |
| --- | --- |
| `data/card_library.tres` | 卡牌、建筑、职业、天气、发展规则和初始手牌的原生资源入口 |
| `data/weather_rules.tres`、`data/weather/` | 天气权重、正负影响、四时段色板与天气表现 |
| `scripts/ui/map_atmosphere.gd` | 地图光照、雨幕、闪电与雾层，仅负责展示 |
| `data/progression_rules.tres`、`data/maps/`、`data/events/`、`data/units/`、`data/enemies/` | 地图、每日事件与职业/敌人原生配置 |
| `scripts/progression/`、`scripts/combat/` | 劳动/人口发展规则、夜战辅助与有限区域 |
| `data/cards/*.tres` | 40 张卡牌的名称、分类、费用、正负说明、前置、效果和标签 |
| `data/buildings/*.tres` | 建筑等级上限、占地、产出、修正器和联动配置 |
| `scripts/resources/` | 类型化资源定义、运行时快照及设施联动规则 |
| `scripts/card_catalog.gd` | 全库校验后发布的卡牌与建筑索引 |
| `scripts/validation/` | 嵌套配置、技术可达性、地图占地与存档完整性校验 |
| `scripts/game_state.gd` | 白天 / 夜晚 / 奖励 / 失败状态机、事务校验、昼夜结算、随机奖励与存档 |
| `scripts/effect_resolver.gd` | 唯一的效果与联动结算入口、派生属性和持续时间 |
| `scripts/battle_simulation.gd` | 固定步长自动战斗、寻路、攻击、Boss、围墙破坏 |
| `scripts/world_layout.gd` | 地图网格、静态障碍、建筑占地和围墙位置 |
| `scripts/village_map.gd` | 俯视地图与单位的程序绘制 |
| `scripts/main.gd` | 注入状态和模拟器、协调用户请求与固定步长播放 |
| `scenes/ui/`、`scripts/ui/` | HUD、手牌、详情、弹窗与奖励选项的独立场景和展示组件 |
| `data/ui/village_theme.tres` | 原生主题、中文字体字重与控件样式 |
| `tests/run_tests.gd`、`tests/validation_regression.gd` | 规则、损坏配置/存档、事务、联动、寻路和第 1 / 7 夜回归 |
| `tests/run_ui_tests.gd` | 真实主场景按钮、引擎按键、暂停、奖励、读档和窗口尺寸检查 |

### 添加卡牌

在 Godot Inspector 中创建 `CardDefinition` 资源，保存到 `data/cards/`，并在 `data/card_library.tres` 的 `cards` 中注册。需要作为初始手牌的卡牌同时加入 `starting_cards`。可以参考现有 `data/cards/training.tres`。

`costs` 使用 `ResourceCost`，`prerequisites` 使用 `BuildingRequirement`；`effects` 组合 `CardEffect.Type` 的 `RESOURCE`、`BUILD`、`MODIFIER`、`HEAL`、`REPAIR_WALLS` 和 `POPULATION`，不需要为每张卡单独写脚本。`building` 指向建筑定义，其 `max_level` 限制升级；`reusable` 让行动保留在手牌中；`CardEffect.required_building` 指定条件加成。

新增建筑在 `data/buildings/` 创建 `BuildingDefinition` 并注册到资源库，其 `footprint` 由 `WorldLayout` 读取。独有设施联动通过 `BuildingSynergy` 子类配置，统一由 `EffectResolver.derive()` 调用。完整扩展流程见项目规范。

派生属性统一按 **基础值与加法 → 所有乘法 → 安全下限** 处理，因此临时增益不会因卡牌加入顺序变化而得到不同结果。黄昏冻结战斗属性和设备供电，电力仅扣一次；黎明使用这份快照结算生产和设施消耗，存活人口重新计算口粮。白天资源不足的卡牌整体拒绝，不会部分生效。

## 存档与词条实现

每次决策与战后自动保存；顶部可手动保存和继续。启动时展示新村庄，点击“继续”恢复原有存档。未开始新决策前不会覆盖旧存档。

存档版本为 5，保存种子、天气、每日事件与选择、烦躁、策略次数、稳定身份、职业装备、队伍、地图余量、手牌、行动、建筑、黄昏耗材预算和战报。夜间继续从同一黄昏重演，不复扣电力。2/3/4 版旧档在内存补齐为旧材料兼容地图，保留旧材料、建筑位置、旧黄昏和已经生效的惩罚；读取不改写旧文件，后续正常保存用版本 5。1 版仍拒绝。写入使用临时文件后替换，恢复先校验完整对象图，失败不改变原局。

人口职业配置在 [workforce_rules.tres](../data/workforce_rules.tres)，卡牌通过 `profession` 指定职业，通过 `labor` 指定劳动类别。新人补齐岗位，实际战损按身份删除。现代地图的稳定身份、装备与夜间作用见 [发展系统](progression_system.md)。

词条说明使用 [keywords.tres](../data/ui/keywords.tres) 中的原生 `KeywordDefinition` 资源，通过 Godot `RichTextLabel` 的 hint 标签显示。词条解释已有卡牌规则，效果执行继续由 `CardEffect` 和 `EffectResolver` 统一处理。

默认存档为 Godot `user://village_save.tres`，使用 `VillageSaveData` 原生资源；macOS 通常位于 `~/Library/Application Support/Godot/app_userdata/余烬村庄 · Emberhaven/`。

## 验证

```sh
/Applications/Godot4.5.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd
```

测试独立于玩家的自动存档；测试文件写到被 Git 忽略的 `test-results/`。

窗口默认最大化，界面采用 `canvas_items + expand` 与全矩形锚点，随窗口比例铺满；基准尺寸为 1280×854，同等窗口高度下文字、按钮和卡牌比原版大约 12.5%。各区域由 Container 分配空间，手牌横向滚动、详情纵向滚动。

本轮发展系统的实际命令、规则/图形结果、截图与规模审查见 [验收记录](validation_report.md)。测试隔离玩家存档；规则包括失败无副作用、旧档迁移、黄昏身份、实际耗材和特殊敌人，图形入口包括地图选择、每日事件、分工、烦躁与原有交互。

真实主场景检查可以运行：

```sh
/Applications/Godot4.5.app/Contents/MacOS/Godot --path . --script tests/run_ui_tests.gd
```

该入口把手动存档也注入独立测试路径，图形模式保存阶段、多窗口、镜头、词条，以及新增事件、分工、烦躁与三地图截图；加 `--headless` 可以只验证场景逻辑。故障检查会故意阻塞一次临时存档，并确认旧文件未变，日志用 `EXPECTED SAVE FAILURE` 标记。
