# 卡牌与末日界面设计

2026-10-11 最新视觉方向：以用户再次提供的三张原创末日插画为依据，将 UI 做成灰褐旧木、锈铁、灰尘与磨损材质；不是只更换平面面板颜色。杀戮尖塔用于卡牌阅读层次参考，多资源费用继续按本游戏规则完整呈现。

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
