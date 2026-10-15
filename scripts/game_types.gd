class_name GameTypes
extends RefCounted

enum Profession {
	GENERAL = 0,
	GATHERER = 1,
	BUILDER = 2,
	ENGINEER = 3,
	MEDIC = 4,
	GUARD = 5,
	COUNT = 6,
}

enum Phase {
	DAY = 0,
	NIGHT = 1,
	DAY_END = 2,
	GAME_OVER = 3,
}
enum Stock {
	STAMINA = 0,
	FOOD = 1,
	WATER = 2,
	POWER = 3,
	MATERIALS = 4,
	NOISE = 5,
	POLLUTION = 6,
	WOOD = 7,
	STONE = 8,
	PARTS = 9,
	FUEL = 10,
	ARROWS = 11,
	MEDICINE = 12,
	COUNT = 13,
}
enum Stat {
	ATTACK = 0,
	RANGE = 1,
	COOLDOWN = 2,
	SPEED = 3,
	HEALTH = 4,
	WAVE_SIZE = 5,
	BLACKOUT = 6,
	WALL_HEALTH = 7,
	TRAP_DAMAGE = 8,
	STAMINA_RECOVERY = 9,
	COUNT = 10,
}
enum Building {
	CORE = 0,
	HUT = 1,
	WALL = 2,
	BOWS = 3,
	FARM = 4,
	WELL = 5,
	GENERATOR = 6,
	LIGHTS = 7,
	FILTER = 8,
	WORKSHOP = 9,
	CLINIC = 10,
	TRAPS = 11,
	GREENHOUSE = 12,
	FOOD_STORE = 13,
	WATER_TANK = 14,
	BATTERY = 15,
	RIVER_WINDMILL = 16,
	WELL_WINDPUMP = 17,
	RAIN_COLLECTOR = 18,
	SOLAR_STILL = 19,
	FORAGING_CAMP = 20,
	FISHERY = 21,
	SAWMILL = 22,
	QUARRY = 23,
	SALVAGE_YARD = 24,
	BIOFUEL_WORKSHOP = 25,
	FUEL_REFINERY = 26,
	FLETCHER = 27,
	HERB_GARDEN = 28,
	BARTER_POST = 29,
	WIND_GENERATOR = 30,
	SPEAR_RACK = 31,
	GUARD_TOWER = 32,
	COUNT = 33,
}
enum Enemy {
	WALKER = 0,
	RUNNER = 1,
	BRUTE = 2,
	BOSS = 3,
	ARMORED = 4,
	SPITTER = 5,
	SCREAMER = 6,
	LURKER = 7,
	BURNER = 8,
	COUNT = 9,
}
enum Icon {
	LEAF = 0,
	WATER = 1,
	CAMP = 2,
	WOOD = 3,
	HOME = 4,
	WALL = 5,
	BOW = 6,
	POWER = 7,
	SUN = 8,
	CROSS = 9,
	TRAP = 10,
	MOON = 11,
	PEOPLE = 12,
	BOX = 13,
}
enum Palette {
	GREEN = 0,
	BLUE = 1,
	GOLD = 2,
	RED = 3,
}

enum Labor {
	NONE = 0,
	FORAGE = 1,
	WATER = 2,
	SALVAGE = 3,
	BUILD = 4,
	TECH = 5,
	TRAIN = 6,
	COUNT = 7,
}
enum Region {
	LEGACY = 0,
	MOUNTAIN = 1,
	RURAL = 2,
	RUINS = 3,
	COUNT = 4,
}
enum Strategy {
	NONE = 0,
	ROTATION = 1,
	CHANT = 2,
	PRACTICE = 3,
	TORCH = 4,
	PIERCING = 5,
	CANAL = 6,
	COUNT = 7,
}
enum Discovery {
	RIVER = 0,
	FORAGE = 1,
	WOODLAND = 2,
	STONE = 3,
	RUINS = 4,
	FUEL = 5,
	FARMLAND = 6,
	COUNT = 7,
}

enum Unit {
	VILLAGER = 0,
	SCOUT = 1,
	REPAIRER = 2,
	ENGINEER = 3,
	MEDIC = 4,
	SPEAR = 5,
	ARCHER = 6,
	COUNT = 7,
}
const DISCOVERY_NAMES: PackedStringArray = ["河流", "可采集食物", "林地", "石料露头", "可拆解废墟", "油料点", "耕地"]
const LABOR_NAMES: PackedStringArray = ["非劳动", "采集", "取水", "拆解", "建造", "技术", "训练"]
const REGION_NAMES: PackedStringArray = ["旧村庄", "山地聚落", "河谷农村", "城镇废墟"]
const UNIT_NAMES: PackedStringArray = ["村民", "侦察员", "维修者", "机修员", "救护员", "长矛卫", "弓手"]
const ENEMY_NAMES: PackedStringArray = [
	"蹒跚者", "疾行者", "蛮力者", "巨尸", "披甲者", "酸液者", "尖啸者", "潜伏者", "爆燃者"
]
const PROFESSION_NAMES: PackedStringArray = ["村民", "采集者", "建造者", "工程师", "医护", "守卫"]
const STOCK_NAMES: PackedStringArray = [
	"体力", "食物", "水", "电力", "旧材料", "噪音", "污染", "木材", "石料", "零件", "燃料", "箭矢", "药品"
]
const STAT_NAMES: PackedStringArray = [
	"攻击", "射程", "攻击间隔", "速度", "生命", "尸群规模", "隐蔽", "围墙耐久", "陷阱伤害", "体力恢复"
]
const BUILDING_NAMES: PackedStringArray = [
	"避难所",
	"住屋",
	"木栅栏",
	"弓箭",
	"菜圃",
	"集水井",
	"柴油机",
	"探照灯",
	"净水器",
	"修造工坊",
	"医疗站",
	"尖刺陷阱",
	"灌溉系统",
	"粮仓",
	"储水罐",
	"蓄电池",
	"河岸引水风车",
	"井上风力提水机",
	"集雨棚",
	"太阳能集水器",
	"采集营地",
	"河岸渔场",
	"轮伐林场",
	"采石场",
	"废料回收站",
	"生物燃料作坊",
	"油料精炼站",
	"箭矢工房",
	"药草园",
	"物资交换站",
	"风力发电机",
	"长矛架",
	"守望塔"
]
const STOCK_LIMITS: PackedInt32Array = [
	100, 999, 999, 999, 999, 100, 100, 999, 999, 999, 999, 999, 999
]
