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

### macOS 一键启动

根目录 `run_macos.command` 使用系统 Bash，提交时保留可执行权限，支持 Finder 双击。查找顺序为显式参数、`GODOT_EXE`、项目内 `Godot*.app` / `godot`、`tools/godot/`、系统及用户的 Applications、PATH 中的 `godot`。app 使用 `Contents/MacOS/Godot`；路径均加引号，支持中文和空格。

启动时先导入资源，再通过 `nohup` 独立打开主场景，输出保存到系统临时目录的 `ember_village_launch_日期时间_PID.log`；一秒内失败显示日志，交互终端中等待回车。成功后脚本退出，Apple Terminal 中按 TTY 精确关闭启动标签，不退出整个 Terminal；其他终端仅结束脚本。关闭动作延迟一秒，等待启动脚本退出。macOS 如询问控制 Terminal 的权限，允许后才能自动关标签。缺少引擎时打开官方 macOS 下载页，提示下载 4.5 标准版后重试。不自动下载引擎或修改系统安全设置。Git 忽略项目内引擎。

指定 app 或可执行文件时，在项目根目录运行；后续参数传给游戏进程，可用于短暂启动验证：

```sh
./run_macos.command /Applications/Godot4.5.app --quit-after 5
```

下载 ZIP 后若系统未保留执行权限，可运行 `chmod +x run_macos.command`。也可以直接用本机引擎运行：

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
| `data/cards/*.tres` | 47 张卡牌的名称、分类、费用、正负说明、前置、效果和标签 |
| `data/buildings/*.tres` | 建筑等级上限、占地、产出、修正器和联动配置 |
| `scripts/resources/` | 类型化资源定义、运行时快照及设施联动规则 |
| `scripts/card_catalog.gd` | 全库校验后发布的卡牌与建筑索引 |
| `scripts/validation/` | 嵌套配置、技术可达性、地图占地与存档完整性校验 |
| `scripts/game_state.gd` | 白天 / 夜晚 / 日终事件 / 失败状态机、事务校验、昼夜结算与存档 |
| `scripts/effect_resolver.gd` | 唯一的效果与联动结算入口、派生属性和持续时间 |
| `scripts/battle_simulation.gd` | 固定步长自动战斗、寻路、攻击、Boss、围墙破坏 |
| `scripts/world_layout.gd` | 局部战场网格、生成地形障碍、建筑占地和围墙位置 |
| `scripts/progression/terrain_grid.gd` | 当局噪声地图、区域坐标、发现与方向报告 |
| `scripts/ui/terrain_map_renderer.gd` | 生成地形、迷雾与可选前沿的展示 |
| `scripts/village_map.gd`、`scripts/ui/apocalypse_map_art.gd` | 地图输入与镜头协调、缓存图集的纯展示 |
| `scripts/main.gd` | 注入状态和模拟器、协调用户请求与固定步长播放 |
| `scenes/ui/`、`scripts/ui/` | HUD、手牌、详情、弹窗与事件选项的独立场景和展示组件 |
| `data/ui/village_theme.tres` | 原生主题、中文字体字重与控件样式 |
| `tests/run_tests.gd`、`tests/validation_regression.gd` | 规则、损坏配置/存档、事务、联动、寻路和第 1 / 7 夜回归 |
| `tests/run_ui_tests.gd` | 真实主场景按钮、引擎按键、暂停、日终事件、读档和窗口尺寸检查 |

### 添加卡牌

在 Godot Inspector 中创建 `CardDefinition` 资源，保存到 `data/cards/`，并在 `data/card_library.tres` 的 `cards` 中注册。按前置自动发放的基础行动同时加入 `starting_cards`；第一天只发勘探，后续按地形与职业开放。可以参考现有 `data/cards/training.tres`。

`costs` 使用 `ResourceCost`，`prerequisites` 使用 `BuildingRequirement`，`keywords` 引用原生 `KeywordDefinition`；地形类指定真实发现或已探索地貌，人物类指定职业与最低人数，同卡全部条件同时成立，`required_cards` 指定先完成的卡牌 ID；库初始化验证依赖图。全部发展卡遵守营地与勘探的共同前置，清单见 [卡牌依赖表](card_prerequisites.md)。`effects` 组合 `CardEffect.Type` 的 `RESOURCE`、`BUILD`、`MODIFIER`、`HEAL`、`REPAIR_WALLS` 和 `POPULATION`，不需要为每张卡单独写脚本。`building` 指向建筑定义，其 `max_level` 限制升级；`reusable` 让行动保留在手牌中；`CardEffect.required_building` 指定条件加成。

新增建筑在 `data/buildings/` 创建 `BuildingDefinition` 并注册到资源库，其 `footprint` 由 `WorldLayout` 读取。独有设施联动通过 `BuildingSynergy` 子类配置，统一由 `EffectResolver.derive()` 调用。完整扩展流程见项目规范。

派生属性统一按 **基础值与加法 → 所有乘法 → 安全下限** 处理，因此临时增益不会因卡牌加入顺序变化而得到不同结果。黄昏冻结战斗属性和设备供电，电力仅扣一次；黎明使用这份快照结算生产和设施消耗，存活人口重新计算口粮。白天资源不足的卡牌整体拒绝，不会部分生效。

## 日终事件

夜战成功进入 `GameTypes.Phase.DAY_END`，数值仍为 2，保持旧阶段索引。黎明不再抽取或要求选择事件；日终遭遇沿用 `DailyEvent` 与 `CardDefinition`，在 `ProgressionRules.day_end_events` 注册，定义位于 `data/events/day_end/`。不再随机发奖励卡。

`DayEndEvents.for_day()` 使用独立种子/日期序列，避开最近两次日终事件，不消耗打井等玩法随机数。`VillageState.day_end_event_id` 保存尚未处理的稳定 ID；`current_day_end_event()` 与 `DayEndEvents.option_error()` 无副作用。UI 仅发选择索引或跳过信号；`choose_day_end_event()` 汇总验证费用与净资源变化，失败不扣费、不推进日期、不发状态信号。`skip_day_end_event()` 仅接受定义中 `skippable` 的特殊事件。

成功先结束上一夜临时效果，再通过 `EffectResolver.apply()` 同时执行收益与代价；之后结算黄昏生产、存活及新增人口口粮、容量与次日行动额度。新事件临时修正不在这个黎明扣期限，从下一夜起计时；原黄昏快照不改写。每种事件两项方案均需有实际正面和负面效果；普通事件必须提供补给耗尽仍可执行的方案，特殊事件可用跳过作为退路。至少为每张地图注册三种事件，避免两次冷却后抽取为空。

## 存档与词条实现

每次决策与战后自动保存；顶部可手动保存和继续。启动时展示新村庄，点击“继续”恢复原有存档。未开始新决策前不会覆盖旧存档。

存档版本为 8，保存待处理的日终事件 ID、最近两次日终事件、种子、已探索路线、待勘探目标和卡牌完成记录；地图在内存中重新生成，先验证连续路线及发现一致性再提交。版本 6 没有坐标，按已有发现迁移成连续区域；2–5 版继续既有库存、岗位、工具和建筑迁移，详见 [生存逻辑顺序](survival_progression.md)。版本 7 及以前的战后奖励存档验证后转换成当日日终事件，旧奖励候选不加入手牌；已有手牌保留。旧版未选择的黎明事件按原计划继续，已选择的当天影响保留到下一黎明。旧事件资源仅用于存档兼容。读档不改写旧文件；1 版仍拒绝。夜间继续从原黄昏预算重演，不复扣电力；写入使用临时文件后替换，恢复失败不改变原局。

分工界面由原生 `workforce_row.tscn` 与 `VillageInfoPanel` 展示草案；增减通过 `WorkforceRules.adjusted_allocation()` 在通用村民与专业间调配，确认后才提交，不能自由输入任意人数。人口职业配置在 [workforce_rules.tres](../data/workforce_rules.tres)，卡牌通过 `profession` 指定职业，通过 `labor` 指定劳动类别。新人补齐岗位，实际战损按身份删除。现代地图的稳定身份、装备与夜间作用见 [发展系统](progression_system.md)。

营地展示从 `WorldLayout.active_structures()` 缓存可见设施，`ApocalypseMapArt` 按原生身份绘制建筑与人物，`TerrainMapRenderer` 绘制纹理地貌、未知迷雾与连接道路；`MapAtmosphere` 保留原生天气和时段光照。图集只在初始化裁切，战斗和存档结构不变。全局背景复用卡牌插画并通过原生着色器压低亮度。图集布局、共用设施类别与生成记录见 [营地视觉设计](map_visual_design.md)。

手牌右键通过 `VillageCardButton.inspect_requested` → `VillageHandPanel` → `VillageGameOverlay.show_card(uid)` 打开原生 `card_inspection_panel.tscn`。中央详解只读，描述、收益、风险、联合前置、当前费用与不可用原因都读取现有规则查询；不改变左键选中卡，也不执行行动。CARD 模态沿用背景遮罩、战斗暂停和输入阻断；关闭按钮、Esc、暗色背景返回游戏，换局或被查看的手牌消失时自动关闭，避免 UID 复用展示旧卡。

词条说明使用 [keywords.tres](../data/ui/keywords.tres) 中的原生 `KeywordDefinition` 资源，通过 Godot `RichTextLabel` 的 hint 标签显示。词条配置位于 `data/keywords/`，含稳定 ID、主题/地形/人物枚举分类与类型化选择器；卡牌只引用注册词条。主题用于分类解释，地形与人物还由 `KeywordRules` 参与准入，文本匹配仅负责提示，效果执行继续由 `CardEffect` 和 `EffectResolver` 统一处理。详见 [关键词与卡牌](card_keywords.md)。

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

## 后台验证

默认使用 `--headless`，避免占用用户前台。日终界面与相关交互可通过 `godot --headless --path . --script tests/run_day_end_ui_tests.gd` 验证，测试使用真实场景和引擎输入，不移动系统光标或请求焦点。完整界面回归可运行 `godot --headless --path . --script tests/run_ui_tests.gd`；后台路径自动跳过系统焦点和光标操作，保留引擎输入、菜单筛选与提示节点断言，不生成截图。这些入口覆盖布局、状态及输入路由；实际像素默认使用 `python3 tools/capture_ui.py` 静默离屏渲染；系统原生下拉菜单与桌面悬停仍需单独授权验收。

### 卡牌获取通知与详情展示

`VillageState.add_card()` 在规则提交阶段登记新增 UID，`_publish_changes()` 在阶段与状态信号之后统一发送 `cards_acquired`，发布期间继续阻止重入。初始手牌和存档恢复清除待通知记录，存档格式不变。新卡实际准入继续由 `SurvivalRules.grant_available()` 统一处理，第一天探索不会提前发放发展卡。

入口将获取信号转给独立 `CardAcquisitionNotice` 场景。通知显示实际卡名、支持滚动和只读查看，连续获取合并；12 秒后渐隐，悬停时保留，换局/读档取消旧动画。普通底部状态提示不会覆盖新卡列表。

手牌与选中方案集中于地图下方的 ActionTray。名称、收益、风险、全部资源费用和确认按钮组成紧凑操作区；说明、关键词、前置、报告与预览在确认下方展开。CardCostStrip 共用 EffectResolver.cost_totals()，同时显示所有正费用、合并同类资源并对库存缺口标红；展示层不重新计算修正。手牌与放大查看复用 card_face.tscn，采用磨损锈铁框、灰褐底材和克制的数字高亮；手牌直接显示大幅插画，选中方案显示通栏横幅，插画为现代废墟与回收物资。获取通知、只读查看、夜战暂停和关闭路径保留。设计及插画生成记录见 [卡牌视觉设计](card_visual_design.md)。

卡牌专项验证：`godot --headless --path . --script tests/run_card_presentation_ui_tests.gd`。实际像素默认运行 `python3 tools/capture_ui.py`：复制独立临时项目、后台导入，以 macOS 仅后台应用封装启动 Godot，在 SubViewport 渲染游戏纹理并保存到 test-results；连续记录前台进程，确保截图进程从未进入前台，不移动光标、不读取桌面画面、不操作玩家存档。当前静默启动器仅支持 macOS，其他平台不自动弹出窗口。包含正常费用、资源缺口、卡面风险、获取通知、村庄信息、三种视口和输入确认检查。普通 --headless 使用无渲染后端，不能单独替代像素截图。

后台截图的 macOS 守卫位于 `tools/background_capture.m`，由系统 clang 编译，只注入复制到临时目录的 Godot 截图进程，限制原生窗口排序与应用激活。临时应用本地签名，原 Godot 安装不变；日志必须包含守卫加载标记与未进入前台的进程记录。需要 macOS 命令行开发工具；缺少工具时失败，不回退可见窗口。
