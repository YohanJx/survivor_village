# 营地与背景视觉设计

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

