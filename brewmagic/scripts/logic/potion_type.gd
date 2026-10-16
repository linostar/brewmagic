class_name PotionType
extends Resource
## One potion from data/potions.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
var name := ""
## Vector4i(ember, frost, bloom, gloom) that a Perfect brew hits exactly.
var target := Vector4i.ZERO
var color := Color.WHITE
## "round", "tall", "flask" or "teardrop".
var bottle := ""
var unlock_day := 1
## Station order: "stir", "pour", "mortar", "bellows".
var steps := PackedStringArray()
var price := 1
var description := ""
