class_name Ingredient
extends Resource
## One shelf ingredient from data/ingredients.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
var name := ""
## Vector4i(ember, frost, bloom, gloom), each 0..3.
var essence := Vector4i.ZERO
var unlock_day := 1
var base_price := 1
## True when the brew needs the Mortar station.
var grind := false
var description := ""
