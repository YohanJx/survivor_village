# 营地与背景视觉设计

## 2026-10-15 · 新设施地图美术补齐

此前只补齐新卡插画，17 种新增设施的地图仍绑定简易线框 SVG，造成引水风车、渔场、轮伐林场与旧建筑风格明显断裂。本轮使用内置 image_gen 分别生成 17 张独立透明 RGBA 地图建筑图，替换 BuildingDefinition.map_texture 的原生引用。卡牌插画、原有图集与玩法占地均保持。

新图沿用旧建筑的高视角三分之四正面、灰褐旧木、锈铁皮、低饱和布棚与漫射光。风车、井泵、集雨、太阳集水、采集、渔场、林场、采石、回收、燃料、箭矢、药草、交换、发电和防守设施都有独立图形。源文件保存至 assets/map/facilities/<id>.png，导入长边限制 512。逐图提示词与来源见 [生成清单](map_facility_art_manifest.json)。

ApocalypseMapArt 对独立地图贴图按真实宽高比缩放，限制在占地宽度 0.95 倍、高度 1.5 倍的绘制范围，底部对齐占地底边；避免原先统一压成方形，也限制塔楼横向遮挡。原生图集设施继续原绘制方式，碰撞、寻路、选址、生产、威胁和存档字段不变。贴图由 Resource 持有，绘制不加载文件或读取像素。

像素检查确认所有 17 张图都有透明区域及接近不透明的建筑主体，未使用背景抠色替代真实透明。逐张查看两页合成预览，并增加同一实际营地全部设施的昼夜离屏截图，最终结果见 [验收记录](validation_report.md)。SVG 占位稿保留但不再被设施资源引用。


2026-10-12：白天和夜间人物使用固定营地岗位。夜间隐蔽时不绘制篝火及火光，射程、隐藏、生产和威胁仍由规则快照决定，地图不做结算。

## 2026-10-12 · 地图文字独立渲染

地形标题不再用 `roundi(14 / camera_scale)` 生成几像素字形后拉伸。`TerrainMapRenderer.draw_label()` 仅将世界锚点投影到控件坐标，临时恢复单位绘制变换，以正常字号绘制文字与深色底板，再恢复地图变换。地形标题、距离、设施名、特殊敌人名、伤害与治疗数字、指南针和地区名共用此入口，文字位置随镜头移动，字形不随地图纹理拉伸。地形标题近景 16 px、距离 13 px；全图小格仅保留发现与前沿标题（13 px），隐藏重复未知文字与距离，避免重叠，不泄露未知资源。

依据：[Godot 4.5 CanvasItem 绘制变换文档](https://docs.godotengine.org/en/4.5/classes/class_canvasitem.html#class-canvasitem-method-draw-set-transform)明确指出 `FontFile.oversampling` 不考虑自定义绘制 scale，普通动态字体因此可能模糊。本项目保留适合小字的普通字体，在单位变换下渲染；原有相机输入、世界坐标和选格逻辑不变。最大放大与全图使用隐藏视口截图验证。

## 风格与边界

营地沿用卡牌的现代末日绘画风格：灰褐土壤、枯草、回收木板、锈蚀铁皮和破损衣物。全局背景复用 survey.png，通过 ruin_backdrop.gdshader 降低饱和度、亮度与边缘对比，保留原有时段底色。地图背景使用等比例裁切，避免横向拉伸。未知地貌仍被迷雾覆盖；展示不参与费用、发现、存档或战斗结算。

ApocalypseMapArt 预载图集并缓存原生 AtlasTexture；VillageMap 负责镜头、输入和绘制协调，TerrainMapRenderer 负责真实发现、纹理地貌、迷雾与连接道路，MapAtmosphere 保留时段光照、雨雾和闪电。默认近景缩放为3.4，查看全图与鼠标锚点缩放仍使用原有相机坐标转换。

## 图集

| 文件 | 原始尺寸与布局 | 内容 |
| --- | --- | --- |
| assets/map/camp_atlas.png | 1280×1280，4×4，透明 | 避难所、住屋、工坊、诊所、井、发电机、田地、温室、储物棚、灯杆、横纵围墙、两种树、碎石、火堆 |
| assets/map/people_atlas.png | 1768×896，4×2，透明 | 村民、守卫、弓手、工程师、普通僵尸、奔跑者、巨型敌人、首领 |
| assets/map/ground_atlas.png | 1536×1024，3×2 | 土壤、林地、岩地、水面、废墟、工业碎屑 |

建筑、人物与障碍保持 WorldLayout 和 CombatActor 的世界位置，不用绘画轮廓替代碰撞。储水罐、蓄电池与粮仓暂共用储物棚图，以原生设施名称区分；未宣称独立设施美术。特殊敌人共用基础人物图并保留身份文字、大小与生命条。人物为静态插画，位移与轻微摇摆沿用已有展示时钟，并非完整方向动画。

营地地面采用安静的土壤裁片逐格铺设，已知其他地貌叠加六层低透明度边缘过渡，不再使用亮绿几何清理块。探索模式继续显示清晰格线、目标与可选前沿。图集裁切只在初始化时建立；绘制不加载资源、不生成游戏随机数、不重新查询设施集合。

## 验证方式

使用 tools/capture_ui.py 的临时项目与 macOS 原生窗口/焦点守卫，保存游戏自身 SubViewport 纹理；不截桌面、不打开前台窗口。截图包含默认营地、已建设施、雷雨与夜战、三种界面尺寸；同时保留真实离屏鼠标确认、全部费用及插画可见性检查。透明图集额外检查 alpha。原生菜单与桌面悬停仍属于D11。

## 生成记录

三个图集由内置 imagegen 生成，保留原始 PNG，透明图集没有用代码重绘像素。以下为生成提示：

### camp_atlas.png

Use case: stylized-concept. Asset type: transparent sprite atlas for a TOP-DOWN post-apocalyptic survivor village game. A square sheet with EXACTLY 4 columns and 4 rows of equal square cells, each item centered in its own cell with generous transparent padding, no overlap across cells. Orthographic bird's eye camera looking mostly down, slight view of south-facing walls, identical camera and scale. Restrained detailed hand-painted realistic 2D game art like weathered wooden settlements and rusty corrugated metal under overcast light. Desaturated ash grey, dirt brown, weathered khaki, muted rusty iron; no toy shapes or vibrant green. Reading left to right: ROW 1: reinforced survivor shelter with patchwork roof; small ragged wooden house; improvised metal workshop; makeshift clinic with faded white cross. ROW 2: old stone well; portable diesel generator; rectangular dead-soil vegetable plot with sparse rows; makeshift greenhouse with cloudy patched plastic. ROW 3: salvage storage shed; rusted floodlight pole; short horizontal scrap timber barricade; short vertical scrap timber barricade. ROW 4: tall bare dead tree with ragged branches; sparse dying tree with a few dull leaves; small rubble and broken concrete heap; stone-ring campfire with small restrained ember flame. Transparent background in every cell. Only the sixteen isolated assets, no ground plane beneath buildings, no cast shadow extending outside cells, no letters, titles, grid lines, scene background, UI, logo. Consistent 4 by 4 sprite atlas.

### ground_atlas.png

Use case: stylized-concept. Asset type: a terrain texture atlas for a top-down modern post-apocalyptic game. Landscape image EXACTLY 3 columns by 2 rows of equally-sized square tiles, no gaps and no borders, each tile a continuous ground surface seen straight from above. Tile arrangement left to right: TOP row: dry dirt with sparse dead grass; forest ground of dead leaves and twigs; cracked stony grey ground. BOTTOM row: murky shallow grey water with subtle ripples; broken concrete and dusty scattered brick rubble; oil-stained gritty gravel with tiny rusty metal debris. Restrained hand-painted realism, subdued weathered brown, ash-grey, dull khaki, dirty charcoal palette. Texture is fine and sparse so gameplay buildings and figures remain clear. No large objects, no buildings, no vehicles, no characters, no huge rocks, no pools of saturated blue, no green lush grass, no UI, no words, no lines separating tiles, no perspective. Six top-down seamless-style ground texture surfaces in one regular 3 by 2 atlas.

### people_atlas.png

Use case: stylized-concept. Asset type: transparent top-down character sprite atlas for a bleak modern post-apocalyptic village strategy game. EXACTLY 4 columns and 2 rows of equal square cells on landscape canvas, each figure centered with generous transparent padding. Identical orthographic bird's eye camera looking down at head, shoulders, torso and shoes; figures stand facing lower-right; distinct readable human silhouettes at small game size. Painterly realistic muted ash-grey, dirt-brown, weathered olive and bone, restrained worn clothing, no cartoon block people. ROW 1 left to right: unarmed survivor in patched jacket with backpack; armed guard with an improvised short weapon; archer with wooden bow; scavenger engineer with worn bag. ROW 2 left to right: shambling emaciated zombie in torn clothes; lean fast zombie; bulky hulking zombie; large threatening zombie leader with torn rust-red coat. No ground beneath figures, no scene, no captions, no labels, no grids, no UI, no logo. Real transparent background. All eight figures fully contained in their separate cells.

