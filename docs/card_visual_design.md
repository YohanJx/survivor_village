# 卡牌与末日界面设计

## 2026-10-12 · 紧凑顶栏与快捷键适配（当前）

顶部改为时间/时段、天气、村庄信息、菜单一行，资源一行。八项资源使用横向平面 chip，保留体力、食物、水、电力、木材、人口、耐久与噪声/污染的原库存、容量与每日净变化，没有缩小字号到不可读的小字；资源条实际高度不超过 40。保存、继续、新局、帮助放入 HudMenu。日夜压力等次要文字保留在日期提示与村庄信息中。

地图上方只保留一条 38 高的工具栏，地图名简化；地图工具和“目标·线索”合并。方向线索和当前目标放在按需展开的 MapDetails 浮窗，不再铺满多行顶端遮挡地图；目标与线索数据仍从原有入口读取。顶栏采用局部 StyleBoxFlat，不改卡牌确认或全局 Theme。HudMenu 管菜单显隐，MapHudLayout 管目标线索显隐，Dashboard 只注入入口和转发。

Esc 从只关闭 overlay 的 _unhandled_key_input 迁移到统一 _input 路由：原生筛选菜单展开时交给原生菜单；其余按详解/弹窗、顶部菜单、地图详情、卡牌浮动面板顺序，一次只关一层。强制日终事件仍由 overlay 拒绝关闭，不能借 Esc 跳过。Esc 不清除选中卡，不改变资源、时段或模拟状态；重复事件不会关下一层。Enter 仅执行可见的选中卡，隐藏面板时被消费但不执行；Space 在非模态情况下统一处理，按钮有焦点时也能暂停/继续，重复按键不能反复切换。

本轮完整实测见 validation_report.md。以下整体重构节的顶栏描述属于本轮之前的历史，地图/卡牌面板的归属设计继续沿用。


## 2026-10-12 · 整体布局重构与浮动卡牌面板（当前）

顶部为紧凑时间/村庄入口和资源两行 HUD，隐藏重复发展汇总和品牌副标题。地图填满主视图；`MapHudLayout` 将地图名称、天气、时段、方向线索、发展目标和工具作为地图内部浮层，按线索显隐收紧高度，不挤压地图。

底部 `CardCategoryBar` 保留五个圆形类别入口，以原生 Kind 过滤。`ActionDock` 已从 VSplitContainer 改为 Control：没有分割线、上下布局或拖动高度。卡牌、确认和筛选都放在圆角、有边框和阴影的浮动面板中，面板整体位于按钮上方；标题、当前按钮高亮与向下指向按钮的三角标记共同表达归属。共同管理者注入导航，面板只读按钮视口位置；开合不改变地图尺寸或游戏状态。

面板只保留一条工具栏：类别名称、数量、关键词筛选、待命、收起。HandPanel 仅持有卡牌列表和过滤展示，通过共同管理者注入工具栏控件；没有重复标题与说明行。未选卡时确认区隐藏，选卡后显示名称、收益、风险、统一费用与确认，不重复大幅插画。右键详解仍展示完整插画和词条。收益展示占固定 96 高度；详细预览/勘探报告使用剩余滚动空间，风险、费用和确认仍固定可见。

分别离屏渲染并查看宽版 1120×420、紧凑版 1000×420、浅版 1000×360，采用紧凑版：宽版占图较多，浅版更容易裁切费用；统一工具栏释放卡牌高度。只有一张卡时宽度适当收紧，空类别使用短提示框；尺寸按实际可用视口与最小内容尺寸钳制。面板布局改变后确保选中卡仍在滚动视口内。每种最终尺寸均实际截图，未以截图缩放代替引擎布局验证。

类别名称以 15 px 显示，第二行 13 px 说明浏览全部、采集/休整、生产/防御、弓箭/灌溉、招募/补给；文字带阴影。按钮和弹出面板接收输入，导航空隙、标题说明及地图 HUD 底板透传输入。勘探选卡时收起大面板，地图右上方提供独立小确认框，费用共用 CardCostStrip。× 与 Esc 均可关闭，地图选目标不会强制重新打开；重新选勘探卡才能显示确认。库存为独立窗口，储备数值与顶部按钮均可进入；实际行动结果用短暂浮层提示。

入口仍只协调，`VillageDashboard` 304 行因新增的依赖注入超过审查阈值 4 行；本轮审查确认未加入布局计算、过滤公式或规则逻辑。位置与归属由 ActionDock 负责，地图信息布局由 MapHudLayout 负责，卡牌复用/筛选由 HandPanel 负责，没有为行数机械拆分协调代码。原生资源与版本化存档字段不变。完整验收见 validation_report.md。

以下插画/材质及曾使用的固定分区段落是历史设计来源；布局以本节为准。

## 2026-10-12 · 小字清晰度修正（当前字体设置）

此前紧凑风险与词条仅 11 px，费用 12 px，1024 宽窗口会进一步缩小；全局 2 px 描边又让正文显得厚重发糊。风险、词条提高至 13 px，费用提高至 14 px；全局 Label、RichTextLabel、Button 描边归零，保留深色阅读背景和现有明亮文字色。

NotoSansSC 的原生导入改为 Full hinting（`hinting=2`）与 Force Autohinter，保留灰阶抗锯齿、自动子像素定位、自动 oversampling 和非 MSDF 渲染。字体仍使用实际 400 字重，字体 UID 不变。运行查询确认高清屏支持和自动字体重采样已经开启，`canvas_items` 缩放不变。不要把 `.import` 的子像素选项索引直接当成 TextServer 枚举；当前导入值 4 实际加载为 AUTO（1），无需修正。

依据：[官方稳定版字体文档](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html)说明小字号灰阶抗锯齿可能较软、Full hinting 可增强像素对齐、自动修正可用于缺少 hinting 指令的字体，MSDF 小字缺少 hinting；[多分辨率文档](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)说明 `canvas_items` 在目标分辨率渲染。API 另对照项目使用的 [Godot 4.5 TextServer](https://docs.godotengine.org/en/4.5/classes/class_textserver.html)。本次不关闭抗锯齿、不切换最近邻过滤、不改游戏规则。

## 2026-10-11 · 独立插画与清晰卡面（当前）

47 张发展卡分别使用内置 imagegen 生成一张独立非透明 PNG，保存在 `assets/cards/individual/`。以大主体、简洁背景、明确轮廓与低饱和点色区分行动：水壶、木桶、井口、挖井工具、调查工具分别对应五种水源行动；电池、柴油机、火花线圈区分储电、生产和超载；斧头、镐、扳手区分木材、石料与拆解。每张图片独立调用生成工具，没有继续按三类共用。原图保留，原生导入限制边长 512，供小卡面与放大查看使用。

`CardDefinition.illustration` 是只读定义中的原生 `Texture2D` 引用， `.tres` 直接绑定图片。库初始化拒绝注册卡缺失插画；动态事件选项和测试临时定义仍可使用原有分类图回退。手牌、选中方案与右键详解共用 `VillageCardFace.art_for()`，不在 UI 维护另一份 ID 图片表，也不在刷新期间加载文件。新增字段为显示配置，不改变版本 9 的存档结构、规则或费用。

卡面使用原生 `StyleBoxFlat` 深色阅读底板和细边框；末日风格来自插画，文字区域保持安静。紧凑手牌以名称、110 高插画、两行收益、单行风险、全部费用和紧凑词条排列，隐藏重复类型副标题。选中状态只改变该实例的边框与底色。关键词仍使用原生 hint 与右键详解，长列表可在完整说明查看；费用继续合并、按实际职业和距离修正、不足单项标色。卡牌高度依据实际内容最小高度，费用不溢出卡框。

右侧选中方案使用安静深色面板，风险、全部费用和确认保持固定；前置与详细预览继续折叠。手牌标题简化为数量，操作提示为点击选择和右键详解，时段额度仍在地图工具区显示。原生上下分隔线、收起展开、右键模态和快捷键不变。

生成工具：内置 `image_gen`；完整逐卡提示与文件映射见 [提示集](art_prompts/individual_cards.json)。后续旧分类图与材质段落是历史来源记录，原文件保留用于未注册临时定义回退与其他界面。


2026-10-11 此前材质方向：以用户再次提供的三张原创末日插画为依据，将 UI 做成灰褐旧木、锈铁、灰尘与磨损材质；不是只更换平面面板颜色。杀戮尖塔用于卡牌阅读层次参考，多资源费用继续按本游戏规则完整呈现。

手牌与放大查看共用原生 card_face.tscn，依次展示居中名称、类型、主体插画、收益、风险、全部费用。手牌插画最小高度92，放大卡面184；手牌保留摘要，放大查看保留完整内容。选中方案横幅插画覆盖整个内容宽度，高度96，取代角落缩略图。手牌和选中方案仍位于下方操作区，确认紧接费用，不因插画回归而把按钮移远。前置与结算预览默认收起。

CardCostStrip 使用 EffectResolver.cost_totals()，同时呈现体力、木材、零件、燃料等所有正费用；重复资源合并，缺口单项标红。显示层不计算职业修正、距离费用或执行条件。卡面样式每实例复制，选中调色不写共享 Theme。

新 assets/ui/worn_iron_panel.png 使用内置 imagegen 生成，原始PNG保留；原生导入 process/size_limit=256 供九宫格样式使用。卡牌保留锈铁边缘，HUD与辅助按钮使用 StyleBoxTexture.region_rect 取安静内材，避免小控件重复铆钉抢占视觉重点。UI文字使用旧纸白，风险锈红；昼夜背景使用灰褐色。默认后台截图流程不变。

## 插画来源与范围

通过内置 imagegen 生成三个原创非透明 PNG，原样复制至 assets/cards/。画面表现现代废墟、回收物资与修补营地，使用平面绘画形状和克制纹理。当前勘探、采集与建造分别共用一张分类插画，尚未制作47张独立插画。工具未提供具体模型标识。

### survey.png

Use case: game card art. One original wide landscape illustration for a modern post-apocalyptic survivor village strategy game, aspect ratio 3:2. Subject: a battered field compass and creased paper map in the foreground on a concrete barrier; beyond it an abandoned rural road, skeletal telephone poles and ruined low houses swallowed by sparse dead weeds; distant survivor in a patched raincoat. Art direction: restrained low-detail 2D indie survival game art, flat blocky painted shapes with sparse hard-edged texture, graphic silhouette clarity, limited palette of charcoal #171c1b, weathered olive #48534a, ash grey #9b9e8d, dusty bone #c9c5b3, subtle rust #9a6752. Desaturated, overcast diffused light, dry ruined atmosphere, scarcity, quiet danger. Small readable focal objects, large simplified masses, no detailed photorealism. The illustration must blend into a muted dark olive and charcoal utility interface and simple top-down village graphics. Edge-to-edge composition. No fantasy, no medieval buildings, no golden sunset, no saturated vegetation, no shiny loot, no ornate border, no lettering, no UI, no logo.

### gather.png

Use case: game card art. One original wide landscape illustration for a modern post-apocalyptic survivor village strategy game, aspect ratio 3:2. Subject: a scuffed canvas scavenger bag, dented tin cans, a water flask and a handful of dry wild herbs beside a broken rural fence; ruined farm sheds and leafless woodland behind; scarce salvage rather than abundant lush fruit. Art direction: restrained low-detail 2D indie survival game art, flat blocky painted shapes with sparse hard-edged texture, graphic silhouette clarity, limited palette of charcoal #171c1b, weathered olive #48534a, ash grey #9b9e8d, dusty bone #c9c5b3, subtle rust #9a6752. Desaturated, overcast diffused light, dry ruined atmosphere, scarcity, quiet danger. Small readable focal objects, large simplified masses, no detailed photorealism. The illustration must blend into a muted dark olive and charcoal utility interface and simple top-down village graphics. Edge-to-edge composition. No fantasy, no medieval buildings, no golden sunset, no saturated vegetation, no shiny loot, no ornate border, no lettering, no UI, no logo.

### build.png

Use case: game card art. One original wide landscape illustration for a modern post-apocalyptic survivor village strategy game, aspect ratio 3:2. Subject: a survivor shelter being reinforced with scavenged corrugated sheet metal and timber; worn hammer, bolts and splintered boards in foreground; patched flat-roof sheds and a small distant watch post, unmistakably modern post-apocalyptic rural settlement. Art direction: restrained low-detail 2D indie survival game art, flat blocky painted shapes with sparse hard-edged texture, graphic silhouette clarity, limited palette of charcoal #171c1b, weathered olive #48534a, ash grey #9b9e8d, dusty bone #c9c5b3, subtle rust #9a6752. Desaturated, overcast diffused light, dry ruined atmosphere, scarcity, quiet danger. Small readable focal objects, large simplified masses, no detailed photorealism. The illustration must blend into a muted dark olive and charcoal utility interface and simple top-down village graphics. Edge-to-edge composition. No fantasy, no medieval buildings, no golden sunset, no saturated vegetation, no shiny loot, no ornate border, no lettering, no UI, no logo.

## 静默截图与验证

先运行 python3 tools/check_conventions.py，再运行 Godot 后台导入与规则/界面回归。实际像素使用 python3 tools/capture_ui.py：macOS 隐藏后台启动独立临时项目，通过 SubViewport 与 register_additional_output 渲染游戏自身纹理，保存 test-results/survival_*.png。不截取桌面、不移动光标、不操作玩家存档。启动器连续记录系统前台应用，核查截图进程从未成为前台（允许用户自行切换应用）；读取失败时不启动，其他平台不自动回退为可见窗口。

--headless 使用无渲染后端，单独运行无法生成有效游戏画面。后台截图验证引擎输入、真实像素、三种视口与确认执行；系统原生菜单和桌面悬停交互仍保留D11，不能用离屏成功代替原生验证。

后台截图的 macOS 守卫位于 `tools/background_capture.m`，由系统 clang 编译，只注入复制到临时目录的 Godot 截图进程，限制原生窗口排序与应用激活。临时应用本地签名，原 Godot 安装不变；日志必须包含守卫加载标记与未进入前台的进程记录。需要 macOS 命令行开发工具；缺少工具时失败，不回退可见窗口。

## UI底材生成记录

通过内置 imagegen 生成，无透明背景。提示要求：portrait 2:3 reusable nine-slice panel, thin battered iron perimeter with four corner rivets, rusty brown edges and scratched paint; quiet dark brown-grey canvas/board center; restrained hand-painted modern apocalypse art, muted umber and khaki; no fantasy ornaments, gold, text, icons, logos or scene objects. 原始生成路径保留，游戏引用 assets/ui/worn_iron_panel.png。


## 固定分区与可拖动横线修订

按用户澄清，取消浮动工作台方案。地图与卡牌固定上下排列，使用原生VSplitContainer分隔条调整两区高度，双击横线复位。卡牌不会覆盖地图，不使用标题栏自由移动或右下角手柄。小尺寸时隐藏选中方案插画与类型副标题，风险、费用与确认保留在滚动说明之外；手牌支持横纵滚动。确认按钮的边框与阴影保持。


地图底边的“收起卡牌 / 展开卡牌”控制整个下方操作区，收起后地图自动填满剩余高度，按钮始终留在地图工具栏。展开恢复本次收起前的分隔位置；不写游戏存档。收起期间 Enter 不执行已选卡牌。

## 文字可读性修订

统一 Theme 为 Label、RichTextLabel 和 Button 增加 2 像素深色描边；正文使用浅暖灰，辅助说明提亮，收益与风险保持不同色彩。全局按钮、资源栏、卡框与说明窗口压低金属纹理亮度，主背景插画透明强度由 0.22 降为 0.14。卡牌选中状态仍有较亮的框体，但不再恢复原纹理亮度；禁用按钮使用可读的灰色提示。事件选项使用原生 StyleBoxFlat 深色阅读底板，外围保留旧金属框。插画资源与地图渲染不变。

## 卡框内词条

手牌关键词改为卡面内部的底部标签区，位于统一费用下方，和插画、收益、风险共用完整金属卡框。保留原生 KeywordDefinition 格式化与右键查看，不再在卡框外悬挂一行文字。压缩卡牌区时仍可纵向滚动；向上拖动分隔线可查看完整卡面。
