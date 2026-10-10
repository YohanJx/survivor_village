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
	REWARD = 2,
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
	COUNT = 13,
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
	"避难所", "住屋", "木栅栏", "弓箭", "菜圃", "集水井", "柴油机", "探照灯", "净水器", "修造工坊", "医疗站", "尖刺陷阱", "灌溉系统"
]
const STOCK_LIMITS: PackedInt32Array = [
	100, 999, 999, 999, 999, 100, 100, 999, 999, 999, 999, 999, 999
]
