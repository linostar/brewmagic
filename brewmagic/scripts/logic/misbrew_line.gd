class_name MisbrewLine
extends Resource
## One misbrew outcome from data/misbrews.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
## Index into Content.ESSENCES: the overshooting essence that selects this line.
var essence := 0
## "singed", "frosted", "sprouting" or "gloomy" (fixed per essence, Content.MISBREW_EFFECTS).
var effect := ""
var text := ""
