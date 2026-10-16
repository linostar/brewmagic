class_name Upgrade
extends Resource
## One station upgrade from data/upgrades.json (fields as in data/SCHEMA.md). Built by Content.
## Level 0 is the bare station (tolerance x1); buying level n (1-based) costs costs[n - 1]
## and sets the station's tolerance multiplier to tolerances[n - 1].

var id := ""
## The station step id it improves: "stir", "pour", "mortar" or "bellows".
var station := ""
var name := ""
var description := ""
## First day whose evening-before market sells it.
var unlock_day := 1
## Per level, strictly increasing, each > 1.
var tolerances: Array[float] = []
## Per level, in coins.
var costs: Array[int] = []


func max_level() -> int:
	return tolerances.size()
