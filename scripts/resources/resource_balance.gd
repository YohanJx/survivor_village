class_name ResourceBalance
extends RefCounted
## 单项库存与当日固定收支的独立查询记录；不包含白天出牌费用或夜战耗材。

var key: GameTypes.Stock = GameTypes.Stock.FOOD
var current: int = 0
var income: int = 0
var upkeep: int = 0
var capacity: int = -1
var net: int:
	get:
		return income - upkeep
