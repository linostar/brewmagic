class_name RequestLine
extends Resource
## One customer request from data/requests.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
## PotionType id this hint asks for.
var potion := ""
## Archetype id whose voice says it.
var archetype := ""
## HintWord ids found in text.
var hints := PackedStringArray()
var text := ""
