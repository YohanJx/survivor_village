# D01–D07 整改验收记录

日期：2026-10-08。基线：Godot `4.5.stable.mono.official.876b29033`，macOS / Apple M1，Compatibility 渲染。下方保留历史整改记录，最新人口职业、卡牌确认与词条功能分别说明改动范围和实际验证。

## README 玩家介绍整理（2026-10-10）

README 改为游戏简介、特色、下载启动、玩法、生存建议、操作、保存与当前版本说明。原有开发规范、项目结构、扩展卡牌、存档实现和测试命令迁至 [开发指南](development_guide.md)，调整相对链接；根目录只保留简短开发入口。按用户要求在 AGENTS.md 与完整规范同步约定文档职责。

验证：`python3 tools/check_conventions.py`，74 个脚本、0 项问题；检查本次修改文档的本地链接、代码路径与 Markdown 围栏，核查玩法和启动文字与现有说明一致，差异无空白错误。本次仅修改文档，未运行引擎或玩法/图形测试，未扩大已有平台验收结论。

## Windows 启动入口（2026-10-10）

新增根目录 `run_windows.bat`，从参数、`GODOT_EXE`、项目根目录、`tools/godot/` 和 PATH 查找 Godot，先执行资源导入，再运行主场景；未找到时打开官方 Windows 下载页面，提示下载并解压 Godot 4.5 后重试。失败时保留控制台信息。README 同步说明双击、拖入 exe 和显式路径用法；Git 忽略本地引擎、已有导入缓存和测试输出。

- 基础规范：`python3 tools/check_conventions.py`，74 个脚本、0 项问题。
- 等效导入：Godot 4.5 `--headless --editor --path . --import`，完成，无错误或警告；日志为 `test-results/windows_launcher_import.log`。首次沙箱内尝试受系统设置访问与 .NET 本地通信限制；放开该命令所需权限后重新运行并核查日志。
- 等效主场景启动：Godot 4.5 `--headless --path . --quit-after 5`，完成，无错误或警告；日志为 `test-results/windows_launcher_startup.log`。没有执行玩家决策。
- 人工检查路径引号、工作目录切换、查找优先级、缺失引擎和失败分支；当前环境没有 Windows 命令解释器，未实际执行 BAT、浏览器跳转或 Windows 图形交互。未改玩法、资源、场景与存档格式，未重跑全量规则/图形回归；Windows 实机验收仍待完成。


## 情绪与村庄发展首轮验收（2026-10-10）

实现范围：40 张发展卡（新增 15）、独立 8 张每日事件、0–5 烦躁与三种当日策略、人口队伍、稳定身份与晨间分工、职业夜战、有限耗材、5 种新增特殊敌人、三张地图及资源分化、无电弓箭与照明分工、版本 5 存档。当前规则和提案差异见 [发展系统](progression_system.md)。医疗收容债务、独立资源点危险等级和地图专属 Boss 等后续内容未标为已实现。

| 门禁 | 本轮实际命令/操作 | 结果与证据 |
| --- | --- | --- |
| G0 架构与范围 | 阅读规范、相关模型/场景；新增 Resource 和职责模块，UI 只发送请求 | 延续 CardDefinition / VillageState / EffectResolver / BattleSimulation，无 Autoload、无同义卡牌体系 |
| G1 词法 | `python3 tools/check_conventions.py` | 74 个脚本，0 项；[日志](../test-results/progression_conventions.log) |
| G1 格式 | `gdformat --check -l 100 scripts tests` | 74 个文件无需修改；[日志](../test-results/progression_format.log) |
| G2 解析与资源 | Godot 4.5 `--headless --path . --editor --import`；最终脚本另外由规则与真实主场景入口编译加载 | 无脚本/资源错误；[导入日志](../test-results/progression_import_console.log) |
| G3 行为 | `--headless --path . --script tests/run_tests.gd` | 652 检查、0 失败；[日志](../test-results/progression_rules_console.log) |
| G4 实际交互 | `--path . --script tests/run_ui_tests.gd` | 161 检查、0 失败；macOS / Apple M1 / Compatibility；[日志](../test-results/progression_ui_console.log) |
| G5 交付 | README、实现说明、提案状态、取舍文档与本记录 | 明确当前数值、迁移、实现差异与后续限制 |

行为覆盖：重复/换工/跨行动、付款前情绪、失败与重复预览、号子上限/溢出、轮换和熟练产出、宣泄转化；每日事件一次提交、不占行动、阻止绕过、费用不足退路、独立随机与冷却、地图过滤；大小队伍费用/收益一致、资源点枯竭/基础兜底、稳定身份与一次调职；三张地图真实夜战、后期特殊尸潮、实际箭/药/木/零件预算、治疗维修、护甲安全下限与穿甲、远程酸液、有限召援、潜伏发现、死亡火焰及延后胜利、夜间重演与真实伤亡；版本 4 七项库存迁移、新版往返、重复身份/缺少黄昏名册/外来战报拒绝，以及次日增长不受历史黄昏名册限制。保留已有故障资源、天气、职业、事务、电力和旧恢复债务到期回归。

图形通过真实按钮选择事件、确认分工与装备、选地图、查看烦躁预览和不可支付事件退路；保留确认/费用/风险位置、词条提示、地图镜头、多窗口、暂停/倍速、读档与奖励检查。全部测试关闭玩家自动存档，手动存档也使用 `test-results/`。

已查看 [每日事件](../test-results/ui_progression_event.png)、[不可支付退路](../test-results/ui_progression_event_choice.png)、[分工](../test-results/ui_progression_jobs.png)、[情绪预览](../test-results/ui_progression_mood_preview.png)、[地图选择](../test-results/ui_progression_map_choice.png)、[山地](../test-results/ui_progression_map_1.png)、[农村](../test-results/ui_progression_map_2.png)、[废墟](../test-results/ui_progression_map_3.png)、[帮助](../test-results/ui_help.png)和[实际词条提示](../test-results/ui_keyword_tooltip.png)。新界面仍使用原生场景与 Theme。

首次并行编辑器/测试时 macOS 遮挡窗口导致截图等待和悬停焦点不稳定；实际图形测试改为在检查悬停前获取窗口焦点并将目标卡牌滚入视野、截图时调用真实 `RenderingServer.force_draw()`，继续保留全部断言，最终单独图形入口通过。规则日志保留一次预期的临时写入失败注入；图形日志仅有 macOS IMK 提示。未关闭警告、删检查或覆盖玩家存档。

规模审查：VillageState 仍是较大的阶段/事务/快照所有者；新劳动与经济求值放在 LaborRules / ProgressionEconomy，身份协调与完整校验放在 PopulationRules / ProgressionValidation。BattleSimulation 保留固定步长、导航与结束协调，装备射击、目标选择、治疗/维修和预算移到 CombatSupport，召援/腐蚀/火焰移到 SpecialEnemies；不在 UI 或信号回调结算。VillageMap 保留已有长绘制函数和渲染职责，新障碍与岗位样式只展示缓存状态。较长的 restore/dawn 与集成测试保留完整事务/生命周期顺序，不为行数机械拆分。新增公共接口在私有辅助之前，类型和嵌套副本明确。没有进行性能基准，未宣称提速。

当前仍是占位美术与首轮平衡；未进行长期多局平衡、其他平台或导出验收。本节为最新范围，以下记录是历史验收。


## 卡牌取舍与固定风险区补充验收

新增五张一次性取舍卡，强化可疑补给箱的两夜生命代价；新局初始加入透支劳作与脱水口粮，所有新卡按前置进入随机奖励。具体数值和设计边界见 [卡牌取舍设计](card_tradeoffs.md)。复用现有原子事务与修正器结算，没有新增效果类型或存档字段；版本仍为 4。负面资源效果不可支付时整张拒绝，两夜恢复惩罚进入黄昏快照，读档与到期保留既有语义。

详情预览覆盖全部相关派生属性和生产/维护变化，包含尸群规模、机动性、围墙耐久和黎明恢复。代价与风险移出详情滚动区，固定在费用与确认附近，未选卡时隐藏；静态布局仍由原生场景管理。

| 门禁 | 实际命令或操作 | 结果与证据 |
| --- | --- | --- |
| G1 基础规范 | `python3 tools/check_conventions.py` | 58 个脚本，0 问题；[日志](../test-results/tradeoff_conventions.log) |
| G1 格式 | `gdformat --check -l 100 scripts tests`（既有临时环境） | 58 个文件无需修改；[日志](../test-results/tradeoff_format.log) |
| G2 解析/资源 | Godot 4.5 `--headless --path . --editor --quit`，最终场景另由图形入口加载 | 无脚本/资源错误；[导入日志](../test-results/tradeoff_import_console.log) |
| G3 行为 | `--headless --path . --script tests/run_tests.gd --log-file /private/tmp/village_tradeoff_rules.log` | 455 项，0 失败；[规则日志](../test-results/tradeoff_rules_console.log) |
| G4 实际交互 | `--path . --script tests/run_ui_tests.gd --log-file /private/tmp/village_tradeoff_ui.log` | 138 项，0 失败；macOS OpenGL Compatibility / Apple M1；[图形日志](../test-results/tradeoff_ui_console.log) |

行为回归新增六种卡牌的预览/执行一致性、共享定义不变、一次性消耗、负面水消耗的不足/刚好支付、设施前置、真实尸群增加、两次黎明扣减恢复、夜间恢复隔离、持续效果叠加，以及固定种子奖励可达性。图形检查通过真实鼠标选择两张应急卡并确认换粮，验证风险和期限文本、负面预览、滚动时风险位置不变、小窗口固定风险区与既有交互。所有自动和手动存档使用测试路径，未覆盖玩家进度。

已查看本轮 [脱水口粮](../test-results/ui_tradeoff_emergency_rations.png)、[透支劳作](../test-results/ui_tradeoff_forced_march.png) 和 [喧闹搜刮](../test-results/ui_tradeoff_lure.png) 实际截图，核查固定风险文字和确认按钮可见。规则日志中一次临时存档写入失败是既有预期故障注入；图形日志仅有 macOS 输入法 IMK 提示。首次沙箱内启动受日志目录/编辑器通信权限限制，正式验收在获准的沙箱外运行，最终日志如上。

规模审查：新增回归中的较长卡牌与两夜结算函数保留完整场景准备、执行及连续断言，以核查同一事务和生命周期；生产代码没有新增大型业务函数。第一次跨夜测试受到次日天气影响，修正测试隔离后通过；图形测试在结束新卡检查后恢复手牌滚动位置，避免干扰既有悬停回归。未进行长期多局平衡、其他平台或发布导出验证；本轮扩展了取舍，不代表完整肉鸽系统已完成。

## 信息区分色补充验收

恢复用于区分信息的低饱和颜色：HUD 资源数值和色条、卡牌图标与顶部标识、详情/奖励分类，以及收益绿色、风险柔和红色。正文、卡牌名称和费用保持中性，词条继承所在文字颜色并保留下划线和悬停解释。未改动四时段、天气、玩法规则或存档。此记录更新下方历史“全部中性文字”的配色方案。

本轮实际基础检查：57 个脚本、0 问题；格式检查：57 个文件无需修改。实际 macOS 图形入口：123 检查、0 失败；已查看 HUD、选中详情和奖励截图，确认恢复区分色且句内词条不混色。图形流程同时验证确认按钮、词条悬停、地图操作、天气与多窗口，测试隔离玩家存档。本轮只修改展示，未重复执行规则测试。

证据：[本轮图形日志](../test-results/semantic_color_ui_console.log)、[HUD](../test-results/ui_day.png)、[详情](../test-results/ui_card_detail.png)、[奖励](../test-results/ui_rewards.png)。未验证其他平台和发布导出。

## 四时段与天气补充验收

增加 WeatherDefinition / WeatherRules 原生资源与完整库校验；VillageState 拥有当日天气，EffectResolver 统一应用额外水收入、恢复与属性修正。天气使用独立种子/日期随机序列，第一天晴朗、其后按权重生成，同一天不随时段或刷新变化。黄昏快照保留当晚天气结果，黎明结算后生成次日天气。存档版本升级为 4，支持 2、3 版内存迁移；原有夜间快照继续使用，3 版职业与当日行动进度保留。

地图和整体背景随清晨、午后、黄昏、夜晚变化；MapAtmosphere 独立绘制光照、雨幕、雾层与闪电，鼠标穿透。地图标题旁展示天气及悬停说明，村庄窗口和黎明记事显示影响。文本仍使用统一中性色。规则及配置详见 [天气系统](weather_system.md)。

本轮实际命令与结果：

| 验证 | 结果与证据 |
| --- | --- |
| `python3 tools/check_conventions.py` | 57 个脚本，0 问题 |
| `gdformat --check -l 100 scripts tests` | 57 个文件无需修改 |
| Godot 4.5 `--headless --path . --editor --quit` | 导入完成，无脚本、资源错误或警告；[导入日志](../test-results/weather_import_console.log) |
| `--headless --path . --script tests/run_tests.gd` | 361 检查、0 失败；[规则日志](../test-results/weather_rules_console.log) |
| `--path . --script tests/run_ui_tests.gd` | macOS 实际图形窗口，123 检查、0 失败；[图形日志](../test-results/weather_ui_console.log) |

覆盖独立随机序列可复现与不消耗奖励 RNG、五类天气、加法后天气乘法、水井与雨水叠加、预览隔离、昼夜只结算一次、雷雨磁盘往返、夜间快照、版本 3 职业额度及已用行动保留、非法天气原子拒绝、重复配置与 NaN 强度拒绝。既有职业、事务、阶段、存档、战斗、字体、确认按钮、地图操作和多窗口检查继续通过。规则日志中标记的保存失败是既有故障注入；图形日志的 macOS 输入法 mach port 消息未影响检查。所有测试隔离玩家存档。

实际查看四时段、降雨、雷雨闪电及雾天渲染，确认地图内容和文字仍可辨认：

- [清晨](../test-results/ui_time_morning.png)、[午后](../test-results/ui_time_afternoon.png)、[黄昏](../test-results/ui_time_dusk.png)、[夜晚](../test-results/ui_time_night.png)
- [降雨](../test-results/ui_weather_2.png)、[雷雨闪电](../test-results/ui_weather_lightning.png)、[雾天](../test-results/ui_weather_4.png)

规模审查：较长的 VillageState.restore() 仍只协调校验后的快照恢复；天气仅增加当日定义引用，校验与抽取留在资源模型。VillageMap 原有长绘图保留地图绘制职责，动态天气绘制独立为 MapAtmosphere；没有在绘制中派生属性。天气测试按抽取、效果、存档与结算、配置故障分类；较长的存档/黎明函数保留连续事务顺序。未测量性能百分比，未验证其他平台、发布导出或长期天气平衡。当前雷雨不包含音效、随机雷击损伤或停电事件。

## 界面配色补充验收

统一 HUD、手牌、详情、奖励和弹窗的文字层级：正文灰白、说明文字浅灰，选中边框与按钮焦点使用一种低饱和强调色。取消分类、资源、正负效果和词条的独立色彩；收益与风险保留 ＋ / － 和分组标题，词条保留下划线与原生悬停解释。配色由静态场景、Theme 和自绘手牌共用的 `UiElements` 常量提供，未改动卡牌规则或存档格式。

本轮实际运行基础规范检查：52 个脚本、0 问题；格式检查：52 个文件无需修改。实际 macOS 图形入口：93 检查、0 失败，无脚本或资源错误。已查看奖励、选中详情及真实词条悬停截图，确认文字统一、确认按钮可见、词条说明正常。此轮仅修改展示，因此未重复执行玩法规则测试；此前规则验收单独列在下方。

证据：[本轮图形日志](../test-results/palette_ui_console.log)、[奖励窗口](../test-results/ui_rewards.png)、[选中详情](../test-results/ui_card_detail.png)、[词条悬停](../test-results/ui_keyword_tooltip.png)。截图由本轮图形运行重新生成，测试继续隔离玩家存档。未做其他平台和发布导出验证。

## 卡牌确认、职业与词条补充验收

卡牌费用、职业倍率和“确认执行”位于详情滚动区之外；村庄现况、职业分布、生产消耗、设施与记事移到独立 `VillageInfoPanel` 窗口。词条使用 `KeywordDefinition` / `KeywordLibrary` 原生资源和 `RichTextLabel` hint 标签，覆盖手牌、详情与奖励。参照 [Godot 4.5 富文本文档](https://docs.godotengine.org/en/4.5/tutorials/ui/bbcode_in_richtextlabel.html)。确认快捷键在入口消费按下、松开与重复事件，避免有焦点的手牌在确认后重新选中。

默认每 5 人提供 1 次时段行动，最低 1、最高 4，黎明更新。职业分为采集者、建造者、工程师、医护和守卫，初始各 1 人；1 位专业者使用基础体力，每多 1 位减耗 10%，最低倍率 0.6，无该职业倍率 1.5。体力费用先汇总、再修正、最后向上取整；显示、校验、预览和执行共用费用入口。新人按人数最少的专业补充、战损按人数最多的职业扣除，同人数固定顺序；当前为经营名册，战斗仍由所有存活者自动防守，不声称已经实现单个战斗小人的职业身份或主动调职。

存档版本为 3，包含职业、每日额度和已用行动；完整校验后才恢复。版本 2 在内存补齐新字段，保留当天每时段一次的额度，下一天按人口更新；读取不修改原文件，版本 1 保持拒绝。职业与额度快照独立复制，当前职业不会写回共享卡牌定义。

实测 `python3 tools/check_conventions.py`：52 个脚本、0 项问题。`tests/run_tests.gd`：328 检查、0 失败，包含缺职业、多职业、倍率下限、体力汇总取整、拒绝不扣费、多行动推进、黎明更新、职业名册、快照预览、时段中途读档和版本迁移。`tests/run_ui_tests.gd`：93 检查、0 失败；真实鼠标悬停生成解释弹窗、点击词条选卡、鼠标点击固定确认按钮、滚动与小窗口确认区、独立村庄窗口、Enter/echo、字体缓存、地图、夜战和奖励均通过。所有测试隔离玩家存档；规则日志中明确标记的临时写入失败仍是预期故障注入。

证据：[规则日志](../test-results/workforce_rules_console.log)、[图形日志](../test-results/workforce_ui_console.log)、[固定确认与费用](../test-results/ui_card_detail.png)、[实际词条弹窗](../test-results/ui_keyword_tooltip.png)、[村庄现况](../test-results/ui_village_information.png)。图形入口生成十六张截图，已核查费用与确认按钮可见、词条提示与独立窗口。较长的 `VillageInfoPanel.update_view()` 仅连续格式化状态与派生属性，不含第二套业务结算；交互测试保留真实输入顺序。未做其他操作系统、发布导出和长期数值平衡验收。

## 地图镜头补充验收

地图默认使用全图适配倍率的 2.5 倍近景，可用左键/中键拖动、鼠标位置滚轮缩放、触控板平移/缩放事件。双击与“回到村庄”恢复近景，“查看全图”适配完整战场，− / + 提供按钮入口。倍率限制在全图适配的 1–8 倍，镜头中心限制在世界范围内；新地图恢复村庄视角，同一地图的界面刷新不重置镜头。

独立 `MapViewCamera` 只管理展示坐标变换，不持有游戏状态；`VillageMap._gui_input()` 消费局部输入，绘制通过 `Transform2D` 统一变换，保留自动战斗的世界坐标。输入依据 [Godot 4.5 鼠标局部坐标文档](https://docs.godotengine.org/en/4.5/classes/class_inputeventmouse.html) 与 [缩放手势文档](https://docs.godotengine.org/en/4.5/classes/class_inputeventmagnifygesture.html)。较长的镜头交互测试按连续真实输入流程保留，未在入口或绘图脚本中增加业务规则。

实测：45 个脚本规范检查无问题，Godot 导入无脚本/资源错误，83 项图形检查全部通过。新增测试通过真实 Viewport 路由鼠标与缩放手势，检查左键/中键拖动、鼠标位置缩放、地图外松手、工具栏、双击复位、全图范围、弹窗遮挡及缩放/平移边界。触控板缩放通过合成引擎事件验证，未声称覆盖所有实体触控设备。原窗口、字体、卡牌、存档、夜战和奖励回归继续通过；本次未改规则及玩家存档，未重跑规则层测试。

证据：[图形日志](../test-results/camera_ui_console.log)、[近景](../test-results/ui_map_village.png)、[拖动后](../test-results/ui_map_dragged.png)、[全图](../test-results/ui_map_overview.png)。截图已查看，图形入口现在生成十四张截图。

## 窗口布局补充验收

固定比例拉伸导致宽屏左右出现引擎黑边。改为 `canvas_items + expand`，Dashboard、背景、外边距与弹窗均设置 Full Rect 锚点和双向增长，内部区域继续由 Container 排版；启动默认最大化。基准由 1440×960 调整到 1280×854，在相同窗口高度下控件约放大 12.5%。降低地图与详情的最小高度，让顶部、手牌和底部提示完整留在窗口内。方案参照 [Godot 4.5 多分辨率文档](https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html)。地图继续保持世界等比显示。

实测 `python3 tools/check_conventions.py`：43 个脚本、0 项问题。图形入口 `tests/run_ui_tests.gd`：64 项检查、0 失败；原交互和字体缓存检查保留，新增 1320×880、1440×900、1600×900、1920×820、1024×768 的背景覆盖、弹窗覆盖、顶部/底部和右侧边界检查。另保留 1100×760 的手牌检查。已查看实际渲染的宽屏界面和帮助弹窗，重新启动正常游戏，无脚本或资源错误。本次未改玩法，未重跑规则测试；测试存档与玩家进度隔离。

证据：[图形日志](../test-results/layout_ui_console.log)、[16:10 窗口](../test-results/ui_layout_1440x900.png)、[超宽窗口](../test-results/ui_layout_1920x820.png)。图形入口现在生成十一张截图。macOS 输入法日志仍有 IMK 提示，检查及输入流程正常完成。

## 字体修复补充验收

用户反馈文字不清楚后，检查到 `FontVariation.variation_opentype` 中的 `&"wght"` 没有生效。字体支持轴范围为 100–900，默认 100；原主题的实际缓存轴坐标为空。改用 OpenType 整数标签 `2003265652` 后，字体缓存实际读取为 400，已修复极细文字。可变轴的整数标签用法参照 [Godot 4.5 FontVariation 文档](https://docs.godotengine.org/en/4.5/classes/class_fontvariation.html#class-fontvariation-property-variation-opentype)。

同时将关键辅助文字从 11–12 提高到 13–14，手牌标题调整为 19；分类颜色改为直接设置字体颜色，避免与原颜色相乘后变暗。未修改玩法规则、窗口缩放模式或字体导入抗锯齿设置。

重新执行 Godot 导入与 `tests/run_ui_tests.gd`：38 项图形检查全部通过，包括直接读取 TextServer 字体缓存的字重断言。两种窗口尺寸和详情、帮助、奖励截图重新生成并查看；[最新图形日志](../test-results/font_ui_console.log)、[字体诊断](../test-results/font_probe_console.log)、[修复前](../test-results/font_before.png)、[修复后](../test-results/font_after.png)。原 303 项规则成绩属于下方整改轮次，本次仅修改显示及 UI 检查，没有重新跑无关规则测试。

## 责任与兼容性

- `VillageState` 继续拥有当局状态、阶段和操作事务，校验器只读取输入；`EffectResolver` 仍是唯一效果和派生规则入口。
- `BattleSimulation` 继续拥有战斗记录，30 Hz 固定步长不变；入口只控制推进次数和每帧积压上限。
- 固定 UI 使用 `scenes/ui/`，展示组件只查询状态、展示记录或发用户请求；入口完成依赖注入和操作调用。
- 卡牌/建筑 ID、枚举数值和既有资源路径保持原值；存档权威版本统一为 2。未提供旧版迁移，拒绝旧版并保留文件。
- 手动与自动测试全部使用 `res://test-results/` 或禁用持久化；图形检查把 `state.save_path` 注入独立路径，没有通过按钮覆盖玩家存档。

## 实际命令与结果

在项目根目录执行，以下日志保存的是本轮最终实际输出。

| 门禁 | 命令/操作 | 结果与证据 |
| --- | --- | --- |
| G0 范围与依赖 | 读取规范、清单、资源模型、状态、效果、主场景和测试 | 状态所有者、失败无副作用、共享定义只读以及存档策略已确认 |
| G1 类型 | `python3 tools/check_conventions.py` | 43 个脚本，0 问题；[日志](../test-results/conventions.log) |
| G1 格式 | `gdformat --check -l 100 scripts tests`，gdtoolkit 4.5.0 | 43 个文件无需修改；[日志](../test-results/format.log)。工具安装在临时 venv，游戏没有新增 Python 依赖 |
| G2 导入 | `/Applications/Godot4.5.app/Contents/MacOS/Godot --headless --path . --editor --quit --log-file /private/tmp/village_import.log` | 导入完成，无 `ERROR`、`SCRIPT ERROR` 或 `WARNING`；[日志](../test-results/import_console.log) |
| G3 规则 | `/Applications/Godot4.5.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd --log-file /private/tmp/village_tests.log` | 303 检查，0 失败；[日志](../test-results/rules_console.log) |
| G4 图形 | `/Applications/Godot4.5.app/Contents/MacOS/Godot --path . --script tests/run_ui_tests.gd --log-file /private/tmp/village_gui_tests.log` | 实际 macOS 窗口渲染，36 检查，0 失败；[日志](../test-results/ui_console.log) |
| G5 交付 | 更新 README、开发约定、技术债状态和本记录 | 接口与验证状态一致；本地链接存在，日志和截图保存在测试目录 |

行为日志中的一次 `Cannot save file ...preserved.tmp.tres` 是故障注入预期：测试把临时文件路径变为目录，检查保存返回失败且旧文件字节不变，随后移除阻塞。日志中用 `EXPECTED SAVE FAILURE BEGIN/END` 标出。不是未处理的正常运行错误。

图形日志有 macOS 输入法系统的 `IMKCFRunLoopWakeUpReliable` 消息；未出现 Godot 脚本/资源错误，实际输入和后续检查完成。

## 行为覆盖

- 配置：缺失库、重复/空卡牌、空费用、建筑缺项/重复、非法资源枚举、缺建筑效果、非法修正器、Infinity、错误占地、不可达技术与联动除数。
- 事务：费用汇总失败和足额成功、失败无副作用、多效果累计等级、出牌前条件语义、共享定义与运行时修正器隔离、信号重入拒绝。
- 昼夜：三次决策、重复入夜/战报/奖励/黎明、供电优先级、一次扣电、黄昏快照、缺粮损伤和效果到期。
- 存档：深层快照、原生往返、同路径覆盖后重读、版本一致、旧版拒绝且保留文件、残缺 REWARD、空历史、非法修正器、NaN/Infinity、战报和墙坐标、失败不修改当前局。
- 战斗：实际栅栏阻挡/破坏与寻路更新，第 1 夜和第 7 夜自动战斗，Boss 出现并被击败。
- 界面：真实场景启动、卡牌按钮信号和引擎键盘事件、Enter/Space/Esc、按键 echo、禁用、手牌节点复用、手动保存/继续、发展页、运行中帮助暂停、1/2/4 倍速、奖励加入手牌、取消新村庄以及两个窗口尺寸。

固定种子 `12345` 的战斗结果：第一夜 29.2 秒、13/13 击退、5 人存活、耐久 240；第七夜 52.0 秒、42/42 击退、8 人存活、耐久 240，Boss 已击败。这是场景回归结果，不是性能测量。

## 视觉证据

图形入口实例化真实主场景，分别保存六张渲染截图，并已查看布局、中文和可见状态：

- [白天 HUD](../test-results/ui_day.png)
- [选中卡牌详情](../test-results/ui_card_detail.png)
- [玩法帮助](../test-results/ui_help.png)
- [自动夜战](../test-results/ui_night.png)
- [奖励选择](../test-results/ui_rewards.png)
- [1100×760 窗口](../test-results/ui_small_window.png)

测试目录被 Git 忽略；运行图形入口可重新生成截图。验证用按钮信号与引擎输入事件，不声称已经覆盖每一种鼠标/设备输入组合。

## 规模审查

本轮完成入口职责拆分，不按行数把连续流程机械切开。以下超过 300 行的模块已经审查：

- `game_state.gd`：当局状态、阶段提交和快照编排；嵌套资源/存档校验移到 `validation/`，固定 UI 已移出。保持单一状态所有者。
- `battle_simulation.gd`：同一固定步长模拟中的寻路、攻击和结束处理，共享一组类型化记录；本轮只整理格式与排列，未新增另一套 AI 或模拟状态。
- `village_map.gd`：单一绘制职责，格式化展开了图形参数；长绘图流程保留连续顺序，派生属性仍由状态变化刷新缓存。
- 测试长函数：按完整故障类别或连续用户流程组织，实际等待帧、输入、阶段断言需要保持顺序；不引入复述实现的测试框架。

## 范围限制

本轮未测量性能前后百分比，未做其他操作系统、发布导出或长期数值平衡验收。这些限制不影响 D01–D07 的上述关闭条件。后续改动应重新执行相关门禁，不能继续引用本轮成绩作为新版本证据。
