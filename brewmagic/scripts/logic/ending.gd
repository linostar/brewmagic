class_name Ending
extends Resource
## One story ending from data/endings.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
var title := ""
## The text of each page, in order.
var pages := PackedStringArray()
## Per page: the archetype ids standing in its picture, left to right.
var casts: Array[PackedStringArray] = []
